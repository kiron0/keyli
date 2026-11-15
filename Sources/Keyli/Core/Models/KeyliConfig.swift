import Foundation

public struct Snippet: Codable, Equatable, Identifiable {
    public enum Kind: String, Codable {
        case text
        case shortcut
    }

    public var id: String
    public var title: String
    public var kind: Kind
    public var text: String
    public var keys: [String]

    public init(id: String = UUID().uuidString, title: String, kind: Kind, text: String = "", keys: [String] = []) {
        self.id = id
        self.title = title
        self.kind = kind
        self.text = text
        self.keys = keys
    }
}

public struct KeyliConfig: Codable, Equatable {
    public var version: Int = 1
    public var themeId: String = "ember_graphite"
    public var layoutGeometry: String = "ansi"
    public var isFloatingVisible: Bool = true
    public var isFloatingPinned: Bool = true
    public var isFloatingPositionLocked: Bool = false
    public var floatingOpacity: Double = 1.0
    public var isPhysicalMonitoringEnabled: Bool = false
    public var playKeyClickSound: Bool = true
    public var keySoundPackId: String = "keyli-slate-thock"
    public var keySoundVolume: Double = 0.6
    public var keySoundsForPhysicalTyping: Bool = false
    public var keySoundVariation: Bool = true
    public var keySoundSeparatePhysicalVolume: Bool = false
    public var keySoundPhysicalVolume: Double = 0.6
    public var keySoundMuteDuringCalls: Bool = true
    public var keySoundMutedApps: [String] = []
    public var keystrokeOverlayEnabled: Bool = false
    public var keystrokeOverlayMode: String = "shortcuts"
    public var keystrokeOverlayPosition: String = "bottom"
    public var dwellEnabled: Bool = false
    public var dwellDuration: Double = 1.0
    public var wordSuggestionsEnabled: Bool = false
    public var snippetBarEnabled: Bool = false
    public var snippets: [Snippet] = []
    public var autoShowKeyboard: Bool = false
    public var autoHideKeyboard: Bool = true
    public var autoShowExcludedApps: [String] = []
    public var favoriteSoundPacks: [String] = []
    public var liquidGlassEnabled: Bool = true
    public var launchAtLogin: Bool = false
    public var showMenuBarIcon: Bool = true
    public var autoUpdate: Bool = true
    public var autoInstallUpdates: Bool = false
    public var modifierStickyMode: Bool = true
    public var keyRepeatEnabled: Bool = true
    public var syntheticTypingDelayMs: Int = 5
    public var floatingWindowX: Double? = nil
    public var floatingWindowY: Double? = nil
    public var floatingWindowWidth: Double? = nil
    public var floatingWindowHeight: Double? = nil

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = KeyliConfig()
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? fallback.version
        themeId = try container.decodeIfPresent(String.self, forKey: .themeId) ?? fallback.themeId
        layoutGeometry = try container.decodeIfPresent(String.self, forKey: .layoutGeometry) ?? fallback.layoutGeometry
        isFloatingVisible = try container.decodeIfPresent(Bool.self, forKey: .isFloatingVisible) ?? fallback.isFloatingVisible
        isFloatingPinned = try container.decodeIfPresent(Bool.self, forKey: .isFloatingPinned) ?? fallback.isFloatingPinned
        isFloatingPositionLocked = try container.decodeIfPresent(Bool.self, forKey: .isFloatingPositionLocked) ?? fallback.isFloatingPositionLocked
        floatingOpacity = try container.decodeIfPresent(Double.self, forKey: .floatingOpacity) ?? fallback.floatingOpacity
        isPhysicalMonitoringEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPhysicalMonitoringEnabled) ?? fallback.isPhysicalMonitoringEnabled
        playKeyClickSound = try container.decodeIfPresent(Bool.self, forKey: .playKeyClickSound) ?? fallback.playKeyClickSound
        keySoundPackId = try container.decodeIfPresent(String.self, forKey: .keySoundPackId) ?? fallback.keySoundPackId
        keySoundVolume = try container.decodeIfPresent(Double.self, forKey: .keySoundVolume) ?? fallback.keySoundVolume
        keySoundsForPhysicalTyping = try container.decodeIfPresent(Bool.self, forKey: .keySoundsForPhysicalTyping) ?? fallback.keySoundsForPhysicalTyping
        keySoundVariation = try container.decodeIfPresent(Bool.self, forKey: .keySoundVariation) ?? fallback.keySoundVariation
        keySoundSeparatePhysicalVolume = try container.decodeIfPresent(Bool.self, forKey: .keySoundSeparatePhysicalVolume) ?? fallback.keySoundSeparatePhysicalVolume
        keySoundPhysicalVolume = try container.decodeIfPresent(Double.self, forKey: .keySoundPhysicalVolume) ?? fallback.keySoundPhysicalVolume
        keySoundMuteDuringCalls = try container.decodeIfPresent(Bool.self, forKey: .keySoundMuteDuringCalls) ?? fallback.keySoundMuteDuringCalls
        keySoundMutedApps = try container.decodeIfPresent([String].self, forKey: .keySoundMutedApps) ?? fallback.keySoundMutedApps
        keystrokeOverlayEnabled = try container.decodeIfPresent(Bool.self, forKey: .keystrokeOverlayEnabled) ?? fallback.keystrokeOverlayEnabled
        keystrokeOverlayMode = try container.decodeIfPresent(String.self, forKey: .keystrokeOverlayMode) ?? fallback.keystrokeOverlayMode
        keystrokeOverlayPosition = try container.decodeIfPresent(String.self, forKey: .keystrokeOverlayPosition) ?? fallback.keystrokeOverlayPosition
        dwellEnabled = try container.decodeIfPresent(Bool.self, forKey: .dwellEnabled) ?? fallback.dwellEnabled
        dwellDuration = try container.decodeIfPresent(Double.self, forKey: .dwellDuration) ?? fallback.dwellDuration
        wordSuggestionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .wordSuggestionsEnabled) ?? fallback.wordSuggestionsEnabled
        snippetBarEnabled = try container.decodeIfPresent(Bool.self, forKey: .snippetBarEnabled) ?? fallback.snippetBarEnabled
        snippets = try container.decodeIfPresent([Snippet].self, forKey: .snippets) ?? fallback.snippets
        autoShowKeyboard = try container.decodeIfPresent(Bool.self, forKey: .autoShowKeyboard) ?? fallback.autoShowKeyboard
        autoHideKeyboard = try container.decodeIfPresent(Bool.self, forKey: .autoHideKeyboard) ?? fallback.autoHideKeyboard
        autoShowExcludedApps = try container.decodeIfPresent([String].self, forKey: .autoShowExcludedApps) ?? fallback.autoShowExcludedApps
        favoriteSoundPacks = try container.decodeIfPresent([String].self, forKey: .favoriteSoundPacks) ?? fallback.favoriteSoundPacks
        liquidGlassEnabled = try container.decodeIfPresent(Bool.self, forKey: .liquidGlassEnabled) ?? fallback.liquidGlassEnabled
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? fallback.showMenuBarIcon
        autoUpdate = try container.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? fallback.autoUpdate
        autoInstallUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoInstallUpdates) ?? fallback.autoInstallUpdates
        modifierStickyMode = try container.decodeIfPresent(Bool.self, forKey: .modifierStickyMode) ?? fallback.modifierStickyMode
        keyRepeatEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyRepeatEnabled) ?? fallback.keyRepeatEnabled
        syntheticTypingDelayMs = try container.decodeIfPresent(Int.self, forKey: .syntheticTypingDelayMs) ?? fallback.syntheticTypingDelayMs
        floatingWindowX = try container.decodeIfPresent(Double.self, forKey: .floatingWindowX)
        floatingWindowY = try container.decodeIfPresent(Double.self, forKey: .floatingWindowY)
        floatingWindowWidth = try container.decodeIfPresent(Double.self, forKey: .floatingWindowWidth)
        floatingWindowHeight = try container.decodeIfPresent(Double.self, forKey: .floatingWindowHeight)
    }
}
