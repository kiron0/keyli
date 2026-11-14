import Foundation
import Combine
import CryptoKit

public struct CatalogPack: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var author: String?
    public var description: String?
    public var type: String?
    public var license: String?
    public var downloads: Int?
    public var ratingAvg: Double?
    public var ratingCount: Int?
    public var zipSize: Int?
    public var checksum: String?
    public var soundProfiles: [String]?

    public var safeId: String { SoundPackManifest.sanitizedId(id) }
}

public enum CatalogSort: String, CaseIterable, Identifiable, Codable {
    case rating
    case downloads
    case newest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rating: return "Top Rated"
        case .downloads: return "Most Downloaded"
        case .newest: return "Newest"
        }
    }
}

public enum CatalogError: Error, LocalizedError, Equatable {
    case badResponse(Int)
    case checksumMismatch
    case rateLimited(Int)

    public var errorDescription: String? {
        switch self {
        case .badResponse(let status): return "The pack catalog answered with error \(status)."
        case .checksumMismatch: return "The downloaded pack didn't match its checksum, so it wasn't installed."
        case .rateLimited(let seconds): return "The pack catalog asked Keyli to slow down. Trying again in \(seconds) s."
        }
    }
}

public struct RequestPacer {
    public var spacing: TimeInterval
    public private(set) var nextAllowed: Date = .distantPast
    public private(set) var blockedUntil: Date?

    public init(spacing: TimeInterval) {
        self.spacing = spacing
    }

    public mutating func reserve(now: Date = Date()) -> TimeInterval {
        var start = max(now, nextAllowed)
        if let blockedUntil, blockedUntil > start {
            start = blockedUntil
        }
        nextAllowed = start.addingTimeInterval(spacing)
        return start.timeIntervalSince(now)
    }

    public mutating func block(for seconds: TimeInterval, now: Date = Date()) {
        blockedUntil = now.addingTimeInterval(seconds)
    }

    public static func retryAfter(_ header: String?, now: Date = Date()) -> Int {
        guard let header = header?.trimmingCharacters(in: .whitespaces), !header.isEmpty else { return 30 }
        if let seconds = Int(header) {
            return min(300, max(1, seconds))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: header) {
            return min(300, max(1, Int(date.timeIntervalSince(now).rounded(.up))))
        }
        return 30
    }
}

public final class SoundPackCatalog: ObservableObject {
    public static let shared = SoundPackCatalog()
    public static let baseURL = URL(string: "https://mechvibes.com/api/sound-packs")!
    public static let pageSize = 30
    public static let cacheLifetime: TimeInterval = 15 * 60
    public static let maxConcurrentInstalls = 2

    @Published public private(set) var packs: [CatalogPack] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var hasMore = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var installing: Set<String> = []
    @Published public var sort: CatalogSort = .rating {
        didSet { if sort != oldValue { reload() } }
    }
    @Published public var query: String = ""

    private struct CachedPage: Codable {
        var packs: [CatalogPack]
        var cursor: String?
        var storedAt: Date
    }

    private var nextCursor: String?
    private var generation = 0
    private var loadedQuery = ""
    private var listTask: URLSessionDataTask?
    private var pacer = RequestPacer(spacing: 0.75)
    private var pageCache: [String: CachedPage] = [:]
    private var installQueue: [CatalogPack] = []
    private var activeInstalls = 0
    private var cancellables: Set<AnyCancellable> = []
    private let session: URLSession
    private let diskCacheURL: URL?

    public init(session: URLSession? = nil, diskCacheURL: URL? = SoundPackCatalog.defaultDiskCacheURL) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpMaximumConnectionsPerHost = 2
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 120
            configuration.waitsForConnectivity = false
            configuration.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 0)
            configuration.httpAdditionalHeaders = ["User-Agent": "Keyli", "Accept": "application/json"]
            self.session = URLSession(configuration: configuration)
        }
        self.diskCacheURL = diskCacheURL
        loadDiskCache()
        $query
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(450), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self, value.trimmingCharacters(in: .whitespacesAndNewlines) != self.loadedQuery else { return }
                self.reload()
            }
            .store(in: &cancellables)
    }

    public static var defaultDiskCacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("io.coreify.keyli/catalog.json")
    }

    public static func listURL(sort: CatalogSort, query: String, cursor: String?) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "type", value: "keyboard"),
            URLQueryItem(name: "limit", value: String(pageSize))
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "q", value: trimmed))
        }
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = items
        return components.url!
    }

    public static func downloadURL(for pack: CatalogPack) -> URL {
        baseURL.appendingPathComponent(pack.id).appendingPathComponent("download")
    }

    public static func parsePage(_ data: Data) throws -> (packs: [CatalogPack], cursor: String?) {
        struct Page: Decodable {
            var packs: [CatalogPack]
            var nextCursor: String?
        }
        let page = try JSONDecoder().decode(Page.self, from: data)
        return (page.packs.filter { ($0.type ?? "keyboard") == "keyboard" }, page.nextCursor)
    }

    public static func verify(_ data: Data, checksum: String?) -> Bool {
        guard let checksum, !checksum.isEmpty else { return true }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == checksum.lowercased()
    }

    private func cacheKey(cursor: String?) -> String {
        "\(sort.rawValue)|\(query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(cursor ?? "")"
    }

    public func loadIfNeeded() {
        if packs.isEmpty && !isLoading {
            reload()
        }
    }

    public func reload() {
        generation += 1
        listTask?.cancel()
        listTask = nil
        loadedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        nextCursor = nil

        let key = cacheKey(cursor: nil)
        if let cached = pageCache[key] {
            packs = cached.packs
            nextCursor = cached.cursor
            hasMore = cached.cursor != nil
            isLoading = false
            if Date().timeIntervalSince(cached.storedAt) < Self.cacheLifetime {
                return
            }
        } else {
            packs = []
            hasMore = false
        }
        fetch(cursor: nil, generation: generation, replacing: true)
    }

    public func loadMore() {
        guard hasMore, !isLoading, let nextCursor else { return }
        if let cached = pageCache[cacheKey(cursor: nextCursor)],
           Date().timeIntervalSince(cached.storedAt) < Self.cacheLifetime {
            append(cached.packs, cursor: cached.cursor)
            return
        }
        fetch(cursor: nextCursor, generation: generation, replacing: false)
    }

    private func append(_ newPacks: [CatalogPack], cursor: String?) {
        let known = Set(packs.map(\.id))
        packs += newPacks.filter { !known.contains($0.id) }
        nextCursor = cursor
        hasMore = cursor != nil
    }

    private func fetch(cursor: String?, generation: Int, replacing: Bool, isRetry: Bool = false) {
        isLoading = true
        let key = cacheKey(cursor: cursor)
        let url = Self.listURL(sort: sort, query: query, cursor: cursor)
        let delay = pacer.reserve()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, generation == self.generation else { return }
            let task = self.session.dataTask(with: url) { [weak self] data, response, error in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let retryAfter = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After")
                let parsed = (status == 200 ? data : nil).flatMap { try? Self.parsePage($0) }
                DispatchQueue.main.async {
                    guard let self, generation == self.generation else { return }
                    self.listTask = nil
                    if let error = error as? URLError, error.code == .cancelled { return }
                    if status == 429 {
                        let seconds = RequestPacer.retryAfter(retryAfter)
                        self.pacer.block(for: TimeInterval(seconds))
                        self.errorMessage = CatalogError.rateLimited(seconds).localizedDescription
                        if !isRetry {
                            self.fetch(cursor: cursor, generation: generation, replacing: replacing, isRetry: true)
                        } else {
                            self.isLoading = false
                        }
                        return
                    }
                    self.isLoading = false
                    if let error {
                        if self.packs.isEmpty || !replacing {
                            self.errorMessage = error.localizedDescription
                        }
                        return
                    }
                    guard status == 200 else {
                        self.errorMessage = CatalogError.badResponse(status).localizedDescription
                        return
                    }
                    guard let parsed else {
                        self.errorMessage = "The pack catalog sent data Keyli couldn't read."
                        return
                    }
                    self.errorMessage = nil
                    self.pageCache[key] = CachedPage(packs: parsed.packs, cursor: parsed.cursor, storedAt: Date())
                    if replacing {
                        self.packs = parsed.packs
                        self.nextCursor = parsed.cursor
                        self.hasMore = parsed.cursor != nil
                        if cursor == nil && self.loadedQuery.isEmpty {
                            self.saveDiskCache()
                        }
                    } else {
                        self.append(parsed.packs, cursor: parsed.cursor)
                    }
                }
            }
            self.listTask = task
            task.resume()
        }
    }

    private func loadDiskCache() {
        guard let diskCacheURL,
              let data = try? Data(contentsOf: diskCacheURL),
              let stored = try? JSONDecoder().decode([String: CachedPage].self, from: data) else { return }
        pageCache = stored
    }

    private func saveDiskCache() {
        guard let diskCacheURL else { return }
        let firstPages = pageCache.filter { key, _ in key.hasSuffix("||") }
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(firstPages) else { return }
            try? FileManager.default.createDirectory(at: diskCacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: diskCacheURL, options: .atomic)
        }
    }

    public func install(_ pack: CatalogPack, select: Bool = true) {
        guard !installing.contains(pack.id) else { return }
        installing.insert(pack.id)
        errorMessage = nil
        installQueue.append(pack)
        if select {
            pendingSelection = pack.id
        }
        startQueuedInstalls()
    }

    private var pendingSelection: String?

    private func startQueuedInstalls() {
        while activeInstalls < Self.maxConcurrentInstalls, !installQueue.isEmpty {
            let pack = installQueue.removeFirst()
            activeInstalls += 1
            let delay = pacer.reserve()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.download(pack)
            }
        }
    }

    private func download(_ pack: CatalogPack) {
        session.dataTask(with: Self.downloadURL(for: pack)) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let retryAfter = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After")
            var failure: Error?
            var downloaded: URL?
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("keyli-download-\(UUID().uuidString)", isDirectory: true)
            if let error {
                failure = error
            } else if status == 429 {
                failure = CatalogError.rateLimited(RequestPacer.retryAfter(retryAfter))
            } else if status != 200 || data == nil {
                failure = CatalogError.badResponse(status)
            } else if let data, !Self.verify(data, checksum: pack.checksum) {
                failure = CatalogError.checksumMismatch
            } else if let data {
                let zip = folder.appendingPathComponent("\(pack.safeId).zip")
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try data.write(to: zip)
                    downloaded = zip
                } catch {
                    failure = error
                }
            }
            DispatchQueue.main.async {
                defer { try? FileManager.default.removeItem(at: folder) }
                guard let self else { return }
                self.activeInstalls -= 1
                self.installing.remove(pack.id)
                defer { self.startQueuedInstalls() }
                do {
                    if case .rateLimited(let seconds)? = failure as? CatalogError {
                        self.pacer.block(for: TimeInterval(seconds))
                    }
                    if let failure { throw failure }
                    guard let downloaded else { return }
                    let info = try SoundPackLibrary.shared.importPack(from: downloaded)
                    if self.pendingSelection == pack.id {
                        self.pendingSelection = nil
                        ConfigStore.shared.config.keySoundPackId = info.id
                        if !ConfigStore.shared.config.playKeyClickSound {
                            ConfigStore.shared.config.playKeyClickSound = true
                        }
                        KeySoundEngine.shared.preview(pack: info)
                    }
                } catch {
                    self.errorMessage = "Couldn't install “\(pack.name)”: " + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }.resume()
    }
}
