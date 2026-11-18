import Foundation
import Combine

public struct KeyliBackup: Codable, Equatable {
    public static let currentFormat = 1

    public var format: Int
    public var appVersion: String
    public var createdAt: Date
    public var config: KeyliConfig
    public var shortcuts: [String: ShortcutBinding]
    public var customThemes: [KeyboardTheme]
    public var personalWords: [String]

    public init(
        format: Int = KeyliBackup.currentFormat,
        appVersion: String,
        createdAt: Date,
        config: KeyliConfig,
        shortcuts: [String: ShortcutBinding],
        customThemes: [KeyboardTheme],
        personalWords: [String]
    ) {
        self.format = format
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.config = config
        self.shortcuts = shortcuts
        self.customThemes = customThemes
        self.personalWords = personalWords
    }
}

public enum SettingsBackupError: LocalizedError, Equatable {
    case unreadable
    case newerFormat

    public var errorDescription: String? {
        switch self {
        case .unreadable:
            return "That file isn't a Keyli settings backup."
        case .newerFormat:
            return "This backup was made by a newer version of Keyli. Update Keyli, then try again."
        }
    }
}

public final class SettingsBackup: ObservableObject {
    public static let shared = SettingsBackup()
    public static let syncFileName = "Keyli Settings.json"

    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var syncError: String?

    private var cancellables = Set<AnyCancellable>()
    private var lastPayload: Data?
    private var pollTimer: Timer?
    private let defaults = UserDefaults.standard
    private let lastSyncKey = "io.coreify.keyli.backup.lastSync"

    private init() {}

    public static func portable(_ config: KeyliConfig) -> KeyliConfig {
        var copy = config
        copy.floatingWindowX = nil
        copy.floatingWindowY = nil
        copy.floatingWindowWidth = nil
        copy.floatingWindowHeight = nil
        copy.launchAtLogin = false
        copy.settingsSyncFolder = nil
        return copy
    }

    public static func merged(_ incoming: KeyliConfig, keepingLocal local: KeyliConfig) -> KeyliConfig {
        var copy = incoming
        copy.floatingWindowX = local.floatingWindowX
        copy.floatingWindowY = local.floatingWindowY
        copy.floatingWindowWidth = local.floatingWindowWidth
        copy.floatingWindowHeight = local.floatingWindowHeight
        copy.launchAtLogin = local.launchAtLogin
        copy.settingsSyncFolder = local.settingsSyncFolder
        copy.isFloatingVisible = local.isFloatingVisible
        return copy
    }

    public static func encode(_ backup: KeyliBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    public static func decode(_ data: Data) throws -> KeyliBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(KeyliBackup.self, from: data) else {
            throw SettingsBackupError.unreadable
        }
        if backup.format > KeyliBackup.currentFormat {
            throw SettingsBackupError.newerFormat
        }
        return backup
    }

    public static func payload(_ backup: KeyliBackup) -> Data? {
        var copy = backup
        copy.createdAt = Date(timeIntervalSince1970: 0)
        copy.appVersion = ""
        copy.customThemes.sort { $0.id < $1.id }
        copy.personalWords.sort()
        return try? encode(copy)
    }

    public func makeBackup(date: Date = Date()) -> KeyliBackup {
        ThemeManager.shared.flushPendingWrites()
        return KeyliBackup(
            appVersion: KeyliConstants.appVersion,
            createdAt: date,
            config: Self.portable(ConfigStore.shared.config),
            shortcuts: ShortcutManager.shared.storedBindings,
            customThemes: ThemeManager.shared.customThemes,
            personalWords: PersonalLexicon.shared.data.customWords
        )
    }

    public func export(to url: URL) throws {
        try Self.encode(makeBackup()).write(to: url, options: .atomic)
    }

    public func restore(from url: URL) throws {
        guard let data = try? Data(contentsOf: url) else {
            throw SettingsBackupError.unreadable
        }
        apply(try Self.decode(data))
    }

    public func apply(_ backup: KeyliBackup) {
        ThemeManager.shared.restoreCustomThemes(backup.customThemes)
        ShortcutManager.shared.restore(backup.shortcuts)
        PersonalLexicon.shared.mergeCustomWords(backup.personalWords)
        let merged = Self.merged(backup.config, keepingLocal: ConfigStore.shared.config)
        if merged != ConfigStore.shared.config {
            ConfigStore.shared.config = merged
        }
        ThemeManager.shared.applySavedTheme()
        lastPayload = Self.payload(makeBackup())
    }

    public var syncFolderURL: URL? {
        guard let path = ConfigStore.shared.config.settingsSyncFolder, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    public var syncFileURL: URL? {
        syncFolderURL?.appendingPathComponent(Self.syncFileName)
    }

    public func applySyncFolder() {
        cancellables.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
        syncError = nil
        guard syncFileURL != nil else {
            lastPayload = nil
            return
        }
        lastSyncDate = defaults.object(forKey: lastSyncKey) as? Date
        pullIfNewer()

        Publishers.Merge4(
            ConfigStore.shared.$config.map { _ in () },
            ShortcutManager.shared.$bindings.map { _ in () },
            ThemeManager.shared.$availableThemes.map { _ in () },
            PersonalLexicon.shared.$data.map { $0.customWords }.removeDuplicates().map { _ in () }
        )
        .dropFirst()
        .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
        .sink { [weak self] in
            self?.push()
        }
        .store(in: &cancellables)

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.pullIfNewer()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    public func syncNow() {
        pullIfNewer()
        push()
    }

    private func markSynced() {
        let now = Date()
        lastSyncDate = now
        defaults.set(now, forKey: lastSyncKey)
    }

    func push() {
        guard let url = syncFileURL else { return }
        let backup = makeBackup()
        guard let payload = Self.payload(backup), payload != lastPayload else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encode(backup).write(to: url, options: .atomic)
            lastPayload = payload
            syncError = nil
            markSynced()
        } catch {
            syncError = "Keyli couldn't save to the sync folder. Check that it still exists."
        }
    }

    func pullIfNewer() {
        guard let url = syncFileURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            push()
            return
        }
        do {
            guard let data = try? Data(contentsOf: url) else { throw SettingsBackupError.unreadable }
            let remote = try Self.decode(data)
            let remotePayload = Self.payload(remote)
            if remotePayload == lastPayload { return }
            let localPayload = Self.payload(makeBackup())
            if remotePayload == localPayload {
                lastPayload = localPayload
                markSynced()
                return
            }
            if let last = lastSyncDate, remote.createdAt <= last {
                push()
                return
            }
            apply(remote)
            syncError = nil
            markSynced()
        } catch {
            syncError = (error as? LocalizedError)?.errorDescription ?? "Keyli couldn't read the sync file."
        }
    }
}
