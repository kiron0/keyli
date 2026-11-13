import Foundation

public struct KeyliConfig: Codable, Equatable {
    public var version: Int = 1
    public var themeId: String = "ember_graphite"
    public var layoutGeometry: String = "ansi" // "ansi", "iso", "jis", "compact"
    public var isFloatingVisible: Bool = true
    public var isFloatingPinned: Bool = true
    public var floatingOpacity: Double = 1.0
    public var isPhysicalMonitoringEnabled: Bool = false
    public var playKeyClickSound: Bool = true
    public var liquidGlassEnabled: Bool = true
    public var launchAtLogin: Bool = false
    public var showMenuBarIcon: Bool = true
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
        floatingOpacity = try container.decodeIfPresent(Double.self, forKey: .floatingOpacity) ?? fallback.floatingOpacity
        isPhysicalMonitoringEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPhysicalMonitoringEnabled) ?? fallback.isPhysicalMonitoringEnabled
        playKeyClickSound = try container.decodeIfPresent(Bool.self, forKey: .playKeyClickSound) ?? fallback.playKeyClickSound
        liquidGlassEnabled = try container.decodeIfPresent(Bool.self, forKey: .liquidGlassEnabled) ?? fallback.liquidGlassEnabled
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? fallback.showMenuBarIcon
        modifierStickyMode = try container.decodeIfPresent(Bool.self, forKey: .modifierStickyMode) ?? fallback.modifierStickyMode
        keyRepeatEnabled = try container.decodeIfPresent(Bool.self, forKey: .keyRepeatEnabled) ?? fallback.keyRepeatEnabled
        syntheticTypingDelayMs = try container.decodeIfPresent(Int.self, forKey: .syntheticTypingDelayMs) ?? fallback.syntheticTypingDelayMs
        floatingWindowX = try container.decodeIfPresent(Double.self, forKey: .floatingWindowX)
        floatingWindowY = try container.decodeIfPresent(Double.self, forKey: .floatingWindowY)
        floatingWindowWidth = try container.decodeIfPresent(Double.self, forKey: .floatingWindowWidth)
        floatingWindowHeight = try container.decodeIfPresent(Double.self, forKey: .floatingWindowHeight)
    }
}
