import Testing
import Foundation
@testable import Keyli

private final class CatalogLoadingProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var count = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        Self.lock.unlock()

        let url = request.url!
        let isNextPage = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .contains(where: { $0.name == "cursor" }) == true
        let json = isNextPage
            ? #"{"packs":[{"id":"second","name":"Second"}],"nextCursor":null}"#
            : #"{"packs":[{"id":"first","name":"First"}],"nextCursor":"next"}"#
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Sound Pack Catalog Loading")
struct SoundPackCatalogLoadingTests {
    @Test @MainActor func disablingStopsInitialLoadsPaginationAndQueuedRequests() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CatalogLoadingProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let catalog = SoundPackCatalog(session: session, diskCacheURL: nil)
        let initialCount = CatalogLoadingProtocol.requestCount

        catalog.loadIfNeeded()
        catalog.reload()
        #expect(!catalog.isLoading)
        try await Task.sleep(for: .milliseconds(50))
        #expect(CatalogLoadingProtocol.requestCount == initialCount)

        catalog.setFetchingEnabled(true)
        for _ in 0..<200 where catalog.isLoading {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(catalog.packs.map(\.id) == ["first"])
        #expect(CatalogLoadingProtocol.requestCount == initialCount + 1)

        catalog.loadMore()
        #expect(catalog.isLoading)
        catalog.setFetchingEnabled(false)
        #expect(!catalog.isLoading)
        catalog.loadMore()
        catalog.reload()
        catalog.query = "pending search"
        catalog.sort = .newest
        try await Task.sleep(for: .seconds(1))
        #expect(CatalogLoadingProtocol.requestCount == initialCount + 1)
        #expect(catalog.packs.map(\.id) == ["first"])

        catalog.query = ""
        catalog.sort = .rating
        catalog.setFetchingEnabled(true)
        catalog.loadMore()
        for _ in 0..<200 where catalog.isLoading {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(CatalogLoadingProtocol.requestCount == initialCount + 2)
        #expect(catalog.packs.map(\.id) == ["first", "second"])
        #expect(!catalog.hasMore)
    }
}
