import Foundation
import Combine
import AVFoundation

public final class SoundPackLibrary: ObservableObject {
    public static let shared = SoundPackLibrary()
    public static let defaultPackId = "keyli-slate-thock"

    @Published public private(set) var packs: [SoundPackInfo] = []
    public enum ImportStatus: Equatable {
        case success(String)
        case failure(String)
    }

    @Published public var status: ImportStatus?

    private let fileManager = FileManager.default
    private let bundledRoot: URL?
    private let userRoot: URL

    public init(bundledRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("SoundPacks", isDirectory: true),
                userRoot: URL? = nil) {
        self.bundledRoot = bundledRoot
        if let userRoot {
            self.userRoot = userRoot
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.userRoot = support.appendingPathComponent("Keyli/SoundPacks", isDirectory: true)
        }
        reload()
    }

    public func reload() {
        var found: [SoundPackInfo] = []
        if let bundledRoot {
            found += scan(bundledRoot, isBundled: true)
        }
        var seen: Set<String> = []
        found = found.filter { seen.insert($0.id).inserted }
        let bundledIds = Set(found.map(\.id))
        found += scan(userRoot, isBundled: false).filter { !bundledIds.contains($0.id) }
        let bundled = found.filter(\.isBundled).sorted { $0.name < $1.name }
        let imported = found.filter { !$0.isBundled }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        packs = bundled + imported
    }

    public func pack(id: String) -> SoundPackInfo? {
        packs.first { $0.id == id } ?? packs.first { $0.id == Self.defaultPackId } ?? packs.first
    }

    public static let maxArchiveBytes = 200 * 1024 * 1024

    public static func loadManifest(in folder: URL, sourceName: String? = nil) throws -> SoundPackManifest {
        let source = sourceName ?? folder.lastPathComponent
        let configURL = folder.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw SoundPackError.missingConfig(source)
        }
        guard let data = try? Data(contentsOf: configURL) else {
            throw SoundPackError.invalidConfig(source)
        }
        return try SoundPackManifest.parse(data, fallbackId: folder.lastPathComponent, sourceName: source)
    }

    @discardableResult
    public func importPack(from url: URL) throws -> SoundPackInfo {
        let sourceName = url.lastPathComponent
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw SoundPackError.notAPackSource(sourceName)
        }
        if isDirectory.boolValue {
            guard Self.packFolder(in: url, depth: 1) == url else {
                throw SoundPackError.missingConfig(sourceName)
            }
            return try importFolder(url, sourceName: sourceName)
        }
        if url.lastPathComponent.lowercased() == "config.json" {
            let folder = url.deletingLastPathComponent()
            return try importFolder(folder, sourceName: folder.lastPathComponent)
        }
        guard url.pathExtension.lowercased() == "zip" else {
            throw SoundPackError.notAPackSource(sourceName)
        }
        return try importArchive(url, sourceName: sourceName)
    }

    private func importArchive(_ url: URL, sourceName: String) throws -> SoundPackInfo {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maxArchiveBytes else {
            throw SoundPackError.archiveTooLarge(sourceName)
        }
        let signature = (try? FileHandle(forReadingFrom: url)).flatMap { handle -> Data? in
            defer { try? handle.close() }
            return try? handle.read(upToCount: 4)
        } ?? Data()
        if signature == Data([0x50, 0x4B, 0x05, 0x06]) {
            throw SoundPackError.emptyArchive(sourceName)
        }
        guard signature == Data([0x50, 0x4B, 0x03, 0x04]) else {
            throw SoundPackError.unreadableArchive(sourceName)
        }
        let staging = fileManager.temporaryDirectory.appendingPathComponent("keyli-pack-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        let output = ProcessRunner.runSync(
            executable: "/usr/bin/unzip",
            arguments: ["-qq", "-o", url.path, "-d", staging.path],
            timeout: 60
        )
        guard let output, output.status == 0, !output.timedOut else {
            throw SoundPackError.unreadableArchive(sourceName)
        }
        let contents = (try? fileManager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        guard contents.contains(where: { $0.lastPathComponent != "__MACOSX" }) else {
            throw SoundPackError.emptyArchive(sourceName)
        }
        guard let root = Self.packFolder(in: staging) else {
            throw SoundPackError.missingConfig(sourceName)
        }
        if root == staging {
            let named = staging.appendingPathComponent(SoundPackManifest.sanitizedId(url.deletingPathExtension().lastPathComponent), isDirectory: true)
            try fileManager.createDirectory(at: named, withIntermediateDirectories: true)
            for item in contents {
                try fileManager.moveItem(at: item, to: named.appendingPathComponent(item.lastPathComponent))
            }
            return try importFolder(named, sourceName: sourceName)
        }
        return try importFolder(root, sourceName: sourceName)
    }

    static func packFolder(in root: URL, depth: Int = 2) -> URL? {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: root.appendingPathComponent("config.json").path) {
            return root
        }
        guard depth > 0,
              let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && entry.lastPathComponent != "__MACOSX" {
            if let found = packFolder(in: entry, depth: depth - 1) {
                return found
            }
        }
        return nil
    }

    static func validateAudio(_ manifest: SoundPackManifest, in folder: URL, sourceName: String) throws {
        let base = folder.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        for file in manifest.audioFiles.sorted() {
            let audioURL = folder.appendingPathComponent(file).standardizedFileURL.resolvingSymlinksInPath()
            guard audioURL.path.hasPrefix(base) else {
                throw SoundPackError.unsafePath(pack: manifest.name, file: file)
            }
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                throw SoundPackError.missingAudio(pack: manifest.name, file: file)
            }
            guard let audio = try? AVAudioFile(forReading: audioURL), audio.length > 0 else {
                throw SoundPackError.unplayableAudio(pack: manifest.name, file: file)
            }
        }
    }

    private func importFolder(_ folder: URL, sourceName: String) throws -> SoundPackInfo {
        let manifest = try Self.loadManifest(in: folder, sourceName: sourceName)
        try Self.validateAudio(manifest, in: folder, sourceName: sourceName)

        var id = manifest.id
        let current = onMain { packs }
        if current.contains(where: { $0.id == id && $0.isBundled }) {
            id += "-imported"
        }
        let existing = current.first { $0.id == id && !$0.isBundled }
        try fileManager.createDirectory(at: userRoot, withIntermediateDirectories: true)

        let baseName = SoundPackManifest.folderName(for: manifest.name)
        var destination = userRoot.appendingPathComponent(baseName, isDirectory: true)
        var suffix = 2
        while fileManager.fileExists(atPath: destination.path) && destination.standardizedFileURL != existing?.folder.standardizedFileURL {
            destination = userRoot.appendingPathComponent("\(baseName)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        if let existing {
            try? fileManager.removeItem(at: existing.folder)
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: folder, to: destination)

        let configURL = destination.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: configURL),
           var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           root["id"] as? String != id {
            root["id"] = id
            if let updated = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
                try updated.write(to: configURL)
            }
        }

        let refreshed = onMain { () -> [SoundPackInfo] in
            reload()
            return packs
        }
        return refreshed.first { $0.id == id } ?? SoundPackInfo(id: id, name: manifest.name, author: manifest.author, folder: destination, isBundled: false)
    }

    private func onMain<T>(_ body: () throws -> T) rethrows -> T {
        if Thread.isMainThread {
            return try body()
        }
        return try DispatchQueue.main.sync(execute: body)
    }

    public func removePack(id: String) throws {
        guard let info = packs.first(where: { $0.id == id }), !info.isBundled else { return }
        try fileManager.removeItem(at: info.folder)
        reload()
    }

    private func scan(_ root: URL, isBundled: Bool) -> [SoundPackInfo] {
        guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        return entries.compactMap { folder in
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let manifest = try? Self.loadManifest(in: folder) else { return nil }
            return SoundPackInfo(id: manifest.id, name: manifest.name, author: manifest.author, folder: folder, isBundled: isBundled)
        }
    }
}
