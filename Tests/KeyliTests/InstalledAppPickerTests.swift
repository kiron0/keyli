import Testing
import Foundation
@testable import Keyli

@Suite("Installed App Picker")
struct InstalledAppPickerTests {
    @Test func filtersExistingAppsSearchAndBackgroundApps() {
        let apps = [
            InstalledApp(bundleIdentifier: "com.example.Editor", name: "Text Editor", url: URL(fileURLWithPath: "/Applications/Editor.app"), isBackground: false),
            InstalledApp(bundleIdentifier: "com.example.helper", name: "Helper", url: URL(fileURLWithPath: "/Applications/Helper.app"), isBackground: true)
        ]
        #expect(InstalledAppCatalog.matching(apps, excluding: [], query: " EDITOR ", showBackground: false).map(\.name) == ["Text Editor"])
        #expect(InstalledAppCatalog.matching(apps, excluding: ["COM.EXAMPLE.EDITOR"], query: "", showBackground: false).isEmpty)
        #expect(InstalledAppCatalog.matching(apps, excluding: [], query: "com.example.helper", showBackground: true).map(\.name) == ["Helper"])
        #expect(InstalledAppCatalog.matching(apps, excluding: [], query: "unknown", showBackground: true).isEmpty)
    }

    @Test func scansNestedFoldersWithoutDuplicateAppsOrEmbeddedHelpers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        func app(_ path: String, id: String, name: String, background: Bool = false) throws -> URL {
            let url = root.appendingPathComponent(path)
            let contents = url.appendingPathComponent("Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": name,
                                        "CFBundlePackageType": "APPL", "LSUIElement": background]
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
            return url
        }
        let editor = try app("Tools/Editor.app", id: "com.example.editor", name: "Editor")
        _ = try app("Duplicate.app", id: "com.example.editor", name: "Editor")
        _ = try app("Tools/Editor.app/Contents/Helper.app", id: "com.example.embedded", name: "Embedded")
        _ = try app("Agent.app", id: "com.example.agent", name: "Agent", background: true)
        let running = try #require(InstalledAppCatalog.application(at: editor))
        let scanned = InstalledAppCatalog.scan(roots: [root], running: [running])
        #expect(scanned.map(\.bundleIdentifier) == ["com.example.agent", "com.example.editor"])
        #expect(scanned.first?.isBackground == true)
    }
}
