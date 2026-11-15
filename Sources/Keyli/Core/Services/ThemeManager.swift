import Foundation
import Combine

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @Published public private(set) var availableThemes: [KeyboardTheme] = []
    @Published public private(set) var currentTheme: KeyboardTheme

    public var isSystemDark: () -> Bool = {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    private let fileManager = FileManager.default
    private let themesDirectoryOverride: URL?
    private let configStore: ConfigStore
    private let state: KeyboardState
    private var pendingWrites: [String: KeyboardTheme] = [:]
    private var pendingWriteItem: DispatchWorkItem?
    private var appearanceObserver: NSObjectProtocol?

    private lazy var resolvedThemesDirectory: URL = {
        if let override = themesDirectoryOverride {
            return override
        }
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("Keyli/Themes", isDirectory: true)
    }()

    private var customThemesDirectory: URL {
        let dir = resolvedThemesDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public init(
        themesDirectory: URL? = nil,
        configStore: ConfigStore = .shared,
        state: KeyboardState = .shared
    ) {
        self.themesDirectoryOverride = themesDirectory
        self.configStore = configStore
        self.state = state
        self.currentTheme = .defaultTheme
        loadAllThemes()
        applySavedTheme()

        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.refreshResolvedTheme()
            }
        }
    }

    deinit {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    public func loadAllThemes() {
        var custom: [KeyboardTheme] = []

        if let files = try? fileManager.contentsOfDirectory(at: customThemesDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension.lowercased() == "json" {
                if let data = try? Data(contentsOf: file),
                   var theme = try? JSONDecoder().decode(KeyboardTheme.self, from: data) {
                    theme.isBuiltIn = false
                    if theme.id.isEmpty {
                        theme.id = file.deletingPathExtension().lastPathComponent
                    }
                    custom.append(theme)
                }
            }
        }

        custom.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.availableThemes = KeyboardTheme.builtInThemes + custom
    }

    public var customThemes: [KeyboardTheme] {
        availableThemes.filter { !$0.isBuiltIn }
    }

    public func resolved(_ theme: KeyboardTheme) -> KeyboardTheme {
        if theme.id == KeyboardTheme.appleNative.id && theme.isBuiltIn && !isSystemDark() {
            return .appleNativeLight
        }
        return theme
    }

    public func refreshResolvedTheme() {
        let resolvedTheme = resolved(currentTheme)
        if state.currentTheme != resolvedTheme {
            state.currentTheme = resolvedTheme
        }
    }

    public func applySavedTheme() {
        let savedId = configStore.config.themeId
        if let found = availableThemes.first(where: { $0.id == savedId }) {
            selectTheme(found)
        } else {
            selectTheme(.defaultTheme)
        }
    }

    public func selectTheme(_ theme: KeyboardTheme) {
        self.currentTheme = theme
        state.currentTheme = resolved(theme)
        if configStore.config.themeId != theme.id {
            configStore.config.themeId = theme.id
        }
        NotificationCenter.default.post(name: KeyliConstants.NotificationName.themeDidChange, object: theme)
    }

    public func selectTheme(byId id: String) {
        if let found = availableThemes.first(where: { $0.id == id }) {
            selectTheme(found)
        }
    }

    public func saveCustomTheme(_ theme: KeyboardTheme) {
        var copy = theme
        copy.isBuiltIn = false
        copy.schemaVersion = KeyboardTheme.currentSchemaVersion
        if copy.id.isEmpty {
            copy.id = ThemeManager.makeCustomId()
        }

        pendingWrites[copy.id] = nil
        flushPendingWrites()
        write(copy)
        loadAllThemes()
        selectTheme(copy)
    }

    @discardableResult
    public func duplicateTheme(_ theme: KeyboardTheme) -> KeyboardTheme {
        var copy = resolved(theme)
        copy.id = ThemeManager.makeCustomId()
        copy.name = uniqueName(basedOn: theme.name)
        saveCustomTheme(copy)
        return currentTheme
    }

    public func updateCustomTheme(_ theme: KeyboardTheme) {
        guard let index = availableThemes.firstIndex(where: { $0.id == theme.id }),
              !availableThemes[index].isBuiltIn else { return }

        var updated = theme
        updated.isBuiltIn = false
        guard availableThemes[index] != updated else { return }

        availableThemes[index] = updated
        if currentTheme.id == updated.id {
            currentTheme = updated
            state.currentTheme = updated
        }

        pendingWrites[updated.id] = updated
        pendingWriteItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.flushPendingWrites()
        }
        pendingWriteItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    public func flushPendingWrites() {
        pendingWriteItem?.cancel()
        pendingWriteItem = nil
        let themes = pendingWrites.values
        pendingWrites.removeAll()
        for theme in themes {
            write(theme)
        }
    }

    public func deleteCustomTheme(_ theme: KeyboardTheme) {
        guard !theme.isBuiltIn else { return }
        pendingWrites[theme.id] = nil
        flushPendingWrites()
        let fileURL = fileURL(forThemeId: theme.id)
        try? fileManager.removeItem(at: fileURL)
        loadAllThemes()
        if currentTheme.id == theme.id {
            selectTheme(.defaultTheme)
        }
    }

    public func exportThemeJSON(_ theme: KeyboardTheme) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(resolved(theme)),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    @discardableResult
    public func exportTheme(_ theme: KeyboardTheme, to url: URL) -> Bool {
        guard let json = exportThemeJSON(theme), let data = json.data(using: .utf8) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func importTheme(fromJSON json: String) -> KeyboardTheme? {
        guard let data = json.data(using: .utf8),
              var theme = try? JSONDecoder().decode(KeyboardTheme.self, from: data) else {
            return nil
        }
        theme.id = ThemeManager.makeCustomId()
        theme.isBuiltIn = false
        if availableThemes.contains(where: { $0.name == theme.name }) {
            theme.name = uniqueName(basedOn: theme.name)
        }
        saveCustomTheme(theme)
        return theme
    }

    public func importTheme(from url: URL) -> KeyboardTheme? {
        guard let data = try? Data(contentsOf: url),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return importTheme(fromJSON: json)
    }

    private static func makeCustomId() -> String {
        "custom_\(UUID().uuidString.prefix(8).lowercased())"
    }

    private func uniqueName(basedOn name: String) -> String {
        let existing = Set(availableThemes.map { $0.name })
        let base = "\(name) Copy"
        if !existing.contains(base) {
            return base
        }
        var index = 2
        while existing.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func fileURL(forThemeId id: String) -> URL {
        let safeId = id.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        return customThemesDirectory.appendingPathComponent("\(safeId).json")
    }

    private func write(_ theme: KeyboardTheme) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(theme) {
            try? data.write(to: fileURL(forThemeId: theme.id), options: .atomic)
        }
    }
}
