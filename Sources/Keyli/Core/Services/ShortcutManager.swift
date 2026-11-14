import AppKit
import Carbon

public enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case toggleKeyboard
    case togglePin
    case togglePositionLock
    case togglePhysicalHighlight
    case nextInputSource
    case showEmojiAndSymbols
    case toggleKeySounds
    case nextSoundPack
    case nextTheme
    case openSettings
    case openThemeStudio
    case checkForUpdates

    public var id: String { rawValue }

    public enum Group: String, CaseIterable {
        case window = "Keyboard Window"
        case typing = "Typing"
        case sounds = "Key Sounds"
        case app = "Keyli"

        public var symbol: String {
            switch self {
            case .window: return "macwindow"
            case .typing: return "character.cursor.ibeam"
            case .sounds: return "speaker.wave.2"
            case .app: return "square.grid.2x2"
            }
        }
    }

    public var group: Group {
        switch self {
        case .toggleKeyboard, .togglePin, .togglePositionLock, .togglePhysicalHighlight: return .window
        case .nextInputSource, .showEmojiAndSymbols: return .typing
        case .toggleKeySounds, .nextSoundPack: return .sounds
        case .nextTheme, .openSettings, .openThemeStudio, .checkForUpdates: return .app
        }
    }

    public var title: String {
        switch self {
        case .toggleKeyboard: return "Show or Hide Keyboard"
        case .togglePin: return "Keep Keyboard on Top"
        case .togglePositionLock: return "Lock Keyboard Position"
        case .togglePhysicalHighlight: return "Highlight Physical Keys"
        case .nextInputSource: return "Next Input Source"
        case .showEmojiAndSymbols: return "Emoji & Symbols"
        case .toggleKeySounds: return "Turn Key Sounds On or Off"
        case .nextSoundPack: return "Next Sound Pack"
        case .nextTheme: return "Next Theme"
        case .openSettings: return "Open Settings"
        case .openThemeStudio: return "Open Theme Studio"
        case .checkForUpdates: return "Check for Updates"
        }
    }

    public var detail: String {
        switch self {
        case .toggleKeyboard: return "Bring the floating keyboard up from anywhere."
        case .togglePin: return "Switch between floating above windows and normal."
        case .togglePositionLock: return "Stop or allow moving and resizing the keyboard."
        case .togglePhysicalHighlight: return "Light up keys as you type on your Mac's keyboard."
        case .nextInputSource: return "Cycle through your keyboard input sources."
        case .showEmojiAndSymbols: return "Open the system character viewer."
        case .toggleKeySounds: return "Mute or unmute keycap sounds."
        case .nextSoundPack: return "Cycle through bundled and imported packs."
        case .nextTheme: return "Cycle through keyboard themes."
        case .openSettings: return "Jump straight to Keyli settings."
        case .openThemeStudio: return "Design and edit your own themes."
        case .checkForUpdates: return "Look for a newer Keyli release."
        }
    }

    public var symbol: String {
        switch self {
        case .toggleKeyboard: return "keyboard"
        case .togglePin: return "macwindow.on.rectangle"
        case .togglePositionLock: return "lock"
        case .togglePhysicalHighlight: return "light.max"
        case .nextInputSource: return "globe"
        case .showEmojiAndSymbols: return "face.smiling"
        case .toggleKeySounds: return "speaker.wave.2"
        case .nextSoundPack: return "music.note.list"
        case .nextTheme: return "paintpalette"
        case .openSettings: return "gearshape"
        case .openThemeStudio: return "paintbrush"
        case .checkForUpdates: return "arrow.down.circle"
        }
    }

    var hotKeyId: UInt32 {
        UInt32((ShortcutAction.allCases.firstIndex(of: self) ?? 0) + 1)
    }
}

public struct ShortcutBinding: Codable, Equatable {
    public var isEnabled: Bool
    public var keys: [String]

    public init(isEnabled: Bool, keys: [String]) {
        self.isEnabled = isEnabled
        self.keys = keys
    }
}

public final class ShortcutManager: ObservableObject {
    public static let shared = ShortcutManager()

    public static let defaultBindings: [ShortcutAction: ShortcutBinding] = [
        .toggleKeyboard: ShortcutBinding(isEnabled: true, keys: ["^", "⌥", "K"]),
        .toggleKeySounds: ShortcutBinding(isEnabled: false, keys: ["^", "⌥", "S"]),
        .nextSoundPack: ShortcutBinding(isEnabled: false, keys: ["^", "⌥", "⇧", "S"])
    ]

    @Published public private(set) var bindings: [ShortcutAction: ShortcutBinding]
    @Published public private(set) var shortcutError: String?
    @Published public private(set) var registrationError: String?

    private let defaults: UserDefaults
    private let storageKey = "io.coreify.keyli.shortcuts.v1"
    private let registers: Bool
    private var registeredHotKeys: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private static let signature: OSType = 0x4B594C49

    public init(defaults: UserDefaults = .standard, registers: Bool = true) {
        self.defaults = defaults
        self.registers = registers
        var loaded = Self.defaultBindings
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([String: ShortcutBinding].self, from: data) {
            for (raw, binding) in stored {
                if let action = ShortcutAction(rawValue: raw) {
                    loaded[action] = binding
                }
            }
        }
        self.bindings = loaded
    }

    public func start() {
        installHandlerIfNeeded()
        restartMonitoring()
    }

    public func binding(for action: ShortcutAction) -> ShortcutBinding {
        bindings[action] ?? ShortcutBinding(isEnabled: false, keys: [])
    }

    public func setEnabled(_ enabled: Bool, for action: ShortcutAction) {
        var binding = binding(for: action)
        guard binding.isEnabled != enabled else { return }
        if enabled, conflicts(keys: binding.keys, excluding: action) {
            shortcutError = "“\(action.title)” uses the same keys as another shortcut."
            return
        }
        binding.isEnabled = enabled
        update(binding, for: action)
    }

    @discardableResult
    public func setKeys(_ keys: [String], for action: ShortcutAction) -> Bool {
        if !keys.isEmpty {
            if let problem = Self.validate(keys) {
                shortcutError = problem
                return false
            }
            if conflicts(keys: keys, excluding: action) {
                shortcutError = "This shortcut is already assigned to another action."
                return false
            }
        }
        var binding = binding(for: action)
        binding.keys = keys
        if !keys.isEmpty { binding.isEnabled = true }
        update(binding, for: action)
        return true
    }

    public func resetToDefaults() {
        bindings = Self.defaultBindings
        shortcutError = nil
        persist()
        restartMonitoring()
    }

    public func conflicts(keys: [String], excluding action: ShortcutAction) -> Bool {
        guard !keys.isEmpty else { return false }
        return ShortcutAction.allCases.contains { other in
            other != action && binding(for: other).isEnabled && binding(for: other).keys == keys
        }
    }

    public static func validate(_ keys: [String]) -> String? {
        guard let parsed = keysToCarbon(keys: keys) else {
            return "That key can't be used for a shortcut."
        }
        let isFunctionKey = functionKeyCodes.contains(UInt16(parsed.keyCode))
        if parsed.modifiers & UInt32(cmdKey | optionKey | controlKey) == 0 && !isFunctionKey {
            return "Add ⌘, ⌥ or ^ so normal typing doesn't trigger it."
        }
        return nil
    }

    private func update(_ binding: ShortcutBinding, for action: ShortcutAction) {
        shortcutError = nil
        bindings[action] = binding
        persist()
        restartMonitoring()
    }

    private func persist() {
        let stored = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func installHandlerIfNeeded() {
        guard registers, eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    let id = hotKeyID.id
                    DispatchQueue.main.async {
                        ShortcutManager.shared.handleHotKey(id: id)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    private func restartMonitoring() {
        guard registers, eventHandlerRef != nil else { return }
        for ref in registeredHotKeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotKeys.removeAll()

        var failures: [String] = []
        for action in ShortcutAction.allCases {
            let binding = binding(for: action)
            guard binding.isEnabled, let parsed = Self.keysToCarbon(keys: binding.keys) else { continue }
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.hotKeyId)
            let status = RegisterEventHotKey(parsed.keyCode, parsed.modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if status == noErr, let ref {
                registeredHotKeys.append(ref)
            } else {
                failures.append(action.title)
            }
        }
        registrationError = failures.isEmpty
            ? nil
            : "macOS or another app already uses the keys for: " + failures.joined(separator: ", ")
    }

    func handleHotKey(id: UInt32) {
        guard let action = ShortcutAction.allCases.first(where: { $0.hotKeyId == id }),
              binding(for: action).isEnabled else { return }
        perform(action)
    }

    public func perform(_ action: ShortcutAction) {
        let store = ConfigStore.shared
        switch action {
        case .toggleKeyboard:
            PanelManager.shared.toggleFloatingKeyboard()
        case .togglePin:
            store.config.isFloatingPinned.toggle()
        case .togglePositionLock:
            store.config.isFloatingPositionLocked.toggle()
        case .togglePhysicalHighlight:
            store.config.isPhysicalMonitoringEnabled.toggle()
        case .nextInputSource:
            _ = InputSourceService.shared.selectNext()
        case .showEmojiAndSymbols:
            InputSourceService.shared.showEmojiAndSymbols()
        case .toggleKeySounds:
            store.config.playKeyClickSound.toggle()
        case .nextSoundPack:
            let packs = SoundPackLibrary.shared.packs
            guard !packs.isEmpty else { return }
            let current = SoundPackLibrary.shared.pack(id: store.config.keySoundPackId)?.id
            let index = packs.firstIndex { $0.id == current } ?? -1
            store.config.keySoundPackId = packs[(index + 1) % packs.count].id
            if !store.config.playKeyClickSound {
                store.config.playKeyClickSound = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                KeySoundEngine.shared.preview()
            }
        case .nextTheme:
            let themes = ThemeManager.shared.availableThemes
            guard !themes.isEmpty else { return }
            let index = themes.firstIndex { $0.id == ThemeManager.shared.currentTheme.id } ?? -1
            ThemeManager.shared.selectTheme(themes[(index + 1) % themes.count])
        case .openSettings:
            NotificationCenter.default.post(name: KeyliConstants.NotificationName.openSettings, object: nil)
        case .openThemeStudio:
            NotificationCenter.default.post(name: KeyliConstants.NotificationName.openThemeStudio, object: nil)
        case .checkForUpdates:
            Task { @MainActor in
                await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
            }
        }
    }

    static let functionKeyCodes: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]

    private static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`",
        51: "⌫", 117: "⌦", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]

    private static let keyCodesByName: [String: UInt32] = {
        var map: [String: UInt32] = [:]
        for (code, name) in keyNames {
            map[name.uppercased()] = UInt32(code)
        }
        return map
    }()

    public static func keyName(for keyCode: UInt16) -> String? {
        keyNames[keyCode]
    }

    public static func keysToCarbon(keys: [String]) -> (keyCode: UInt32, modifiers: UInt32)? {
        var modifiers: UInt32 = 0
        var keyName: String?
        for key in keys {
            switch key {
            case "^": modifiers |= UInt32(controlKey)
            case "⌥": modifiers |= UInt32(optionKey)
            case "⇧": modifiers |= UInt32(shiftKey)
            case "⌘": modifiers |= UInt32(cmdKey)
            default: keyName = key
            }
        }
        guard let keyName, let code = keyCodesByName[keyName.uppercased()] else { return nil }
        return (code, modifiers)
    }

    public static func keys(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> [String] {
        guard let name = keyName(for: keyCode) else { return [] }
        var keys: [String] = []
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { keys.append("^") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.command) { keys.append("⌘") }
        keys.append(name)
        return keys
    }
}
