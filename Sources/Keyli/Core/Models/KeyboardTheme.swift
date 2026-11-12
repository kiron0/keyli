import Foundation
import SwiftUI

public enum KeycapStyle: String, Codable, CaseIterable {
    case raised = "raised"
    case flat = "flat"
    case glass = "glass"
    case chicklet = "chicklet"

    public var displayName: String {
        switch self {
        case .raised: return "Raised Mechanical"
        case .flat: return "Flat Minimal"
        case .glass: return "Frosted Glass"
        case .chicklet: return "Apple Chiclet"
        }
    }
}

public struct KeyboardTheme: Identifiable, Codable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var isBuiltIn: Bool
    public var backgroundColorHex: String
    public var backgroundOpacity: Double
    public var backgroundBlur: Bool
    public var keycapBaseColorHex: String
    public var keycapActiveColorHex: String
    public var keycapTextColorHex: String
    public var accentColorHex: String
    public var modifierKeyColorHex: String
    public var cornerRadius: Double
    public var keySpacing: Double
    public var borderWidth: Double
    public var borderColorHex: String
    public var borderOpacity: Double
    public var keyElevation: Double
    public var keycapStyle: KeycapStyle
    public var fontDesign: String

    public init(
        id: String,
        name: String,
        isBuiltIn: Bool = false,
        backgroundColorHex: String,
        backgroundOpacity: Double = 0.92,
        backgroundBlur: Bool = true,
        keycapBaseColorHex: String,
        keycapActiveColorHex: String,
        keycapTextColorHex: String,
        accentColorHex: String,
        modifierKeyColorHex: String,
        cornerRadius: Double = 5.0,
        keySpacing: Double = 4.0,
        borderWidth: Double = 1.0,
        borderColorHex: String = "#334155",
        borderOpacity: Double = 0.4,
        keyElevation: Double = 1.5,
        keycapStyle: KeycapStyle = .chicklet,
        fontDesign: String = "default",
        schemaVersion: Int = KeyboardTheme.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.backgroundColorHex = backgroundColorHex
        self.backgroundOpacity = backgroundOpacity
        self.backgroundBlur = backgroundBlur
        self.keycapBaseColorHex = keycapBaseColorHex
        self.keycapActiveColorHex = keycapActiveColorHex
        self.keycapTextColorHex = keycapTextColorHex
        self.accentColorHex = accentColorHex
        self.modifierKeyColorHex = modifierKeyColorHex
        self.cornerRadius = cornerRadius
        self.keySpacing = keySpacing
        self.borderWidth = borderWidth
        self.borderColorHex = borderColorHex
        self.borderOpacity = borderOpacity
        self.keyElevation = keyElevation
        self.keycapStyle = keycapStyle
        self.fontDesign = fontDesign
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = KeyboardTheme.appleNative
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        backgroundColorHex = try container.decode(String.self, forKey: .backgroundColorHex)
        keycapBaseColorHex = try container.decode(String.self, forKey: .keycapBaseColorHex)
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? fallback.backgroundOpacity
        backgroundBlur = try container.decodeIfPresent(Bool.self, forKey: .backgroundBlur) ?? fallback.backgroundBlur
        keycapActiveColorHex = try container.decodeIfPresent(String.self, forKey: .keycapActiveColorHex) ?? fallback.keycapActiveColorHex
        keycapTextColorHex = try container.decodeIfPresent(String.self, forKey: .keycapTextColorHex) ?? fallback.keycapTextColorHex
        accentColorHex = try container.decodeIfPresent(String.self, forKey: .accentColorHex) ?? fallback.accentColorHex
        modifierKeyColorHex = try container.decodeIfPresent(String.self, forKey: .modifierKeyColorHex) ?? keycapBaseColorHex
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? fallback.cornerRadius
        keySpacing = try container.decodeIfPresent(Double.self, forKey: .keySpacing) ?? fallback.keySpacing
        borderWidth = try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? fallback.borderWidth
        borderColorHex = try container.decodeIfPresent(String.self, forKey: .borderColorHex) ?? fallback.borderColorHex
        borderOpacity = try container.decodeIfPresent(Double.self, forKey: .borderOpacity) ?? fallback.borderOpacity
        keyElevation = try container.decodeIfPresent(Double.self, forKey: .keyElevation) ?? fallback.keyElevation
        keycapStyle = (try? container.decodeIfPresent(KeycapStyle.self, forKey: .keycapStyle)) ?? fallback.keycapStyle
        fontDesign = try container.decodeIfPresent(String.self, forKey: .fontDesign) ?? fallback.fontDesign
    }

    public static func rgbComponents(hex: String) -> (red: Double, green: Double, blue: Double)? {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        guard clean.count == 6 || clean.count == 8, let value = UInt64(clean.prefix(6), radix: 16) else {
            return nil
        }
        return (
            Double((value & 0xFF0000) >> 16) / 255.0,
            Double((value & 0x00FF00) >> 8) / 255.0,
            Double(value & 0x0000FF) / 255.0
        )
    }

    public static func relativeLuminance(hex: String) -> Double {
        guard let rgb = rgbComponents(hex: hex) else { return 0 }
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    public var isDarkBackground: Bool {
        KeyboardTheme.relativeLuminance(hex: backgroundColorHex) < 0.4
    }

    public var activeTextColorHex: String {
        KeyboardTheme.relativeLuminance(hex: keycapActiveColorHex) > 0.45 ? "#000000" : "#FFFFFF"
    }
}

// Built-in presets
extension KeyboardTheme {
    public static let appleNative = KeyboardTheme(
        id: "apple_native",
        name: "macOS Native",
        isBuiltIn: true,
        backgroundColorHex: "#1C1C1E",
        backgroundOpacity: 0.62,
        backgroundBlur: true,
        keycapBaseColorHex: "#323236",
        keycapActiveColorHex: "#FFFFFF",
        keycapTextColorHex: "#FFFFFF",
        accentColorHex: "#0A84FF",
        modifierKeyColorHex: "#2C2C2E",
        cornerRadius: 5.0,
        keySpacing: 4.0,
        borderWidth: 0.5,
        borderColorHex: "#505054",
        borderOpacity: 0.45,
        keyElevation: 1.0,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let appleNativeLight = KeyboardTheme(
        id: "apple_native",
        name: "macOS Native",
        isBuiltIn: true,
        backgroundColorHex: "#ECECEE",
        backgroundOpacity: 0.62,
        backgroundBlur: true,
        keycapBaseColorHex: "#FFFFFF",
        keycapActiveColorHex: "#3A3A3C",
        keycapTextColorHex: "#1D1D1F",
        accentColorHex: "#007AFF",
        modifierKeyColorHex: "#F2F2F4",
        cornerRadius: 5.0,
        keySpacing: 4.0,
        borderWidth: 0.5,
        borderColorHex: "#B9B9BE",
        borderOpacity: 0.6,
        keyElevation: 1.0,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let darkMechanical = KeyboardTheme(
        id: "dark_mechanical",
        name: "Dark Mechanical",
        isBuiltIn: true,
        backgroundColorHex: "#121418",
        backgroundOpacity: 0.95,
        backgroundBlur: true,
        keycapBaseColorHex: "#20242C",
        keycapActiveColorHex: "#FFFFFF",
        keycapTextColorHex: "#E2E8F0",
        accentColorHex: "#00D2FF",
        modifierKeyColorHex: "#1A1D24",
        cornerRadius: 6.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#334155",
        borderOpacity: 0.4,
        keyElevation: 2.5,
        keycapStyle: .raised,
        fontDesign: "monospaced"
    )

    public static let minimalistLight = KeyboardTheme(
        id: "minimalist_light",
        name: "Minimalist Light",
        isBuiltIn: true,
        backgroundColorHex: "#F8FAFC",
        backgroundOpacity: 0.96,
        backgroundBlur: true,
        keycapBaseColorHex: "#FFFFFF",
        keycapActiveColorHex: "#1E293B",
        keycapTextColorHex: "#1E293B",
        accentColorHex: "#007AFF",
        modifierKeyColorHex: "#F1F5F9",
        cornerRadius: 6.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#CBD5E1",
        borderOpacity: 0.6,
        keyElevation: 1.5,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let midnightNeon = KeyboardTheme(
        id: "midnight_neon",
        name: "Midnight Neon",
        isBuiltIn: true,
        backgroundColorHex: "#09090E",
        backgroundOpacity: 0.94,
        backgroundBlur: true,
        keycapBaseColorHex: "#141424",
        keycapActiveColorHex: "#FFFFFF",
        keycapTextColorHex: "#C084FC",
        accentColorHex: "#F43F5E",
        modifierKeyColorHex: "#10101C",
        cornerRadius: 7.0,
        keySpacing: 4.5,
        borderWidth: 1.2,
        borderColorHex: "#A855F7",
        borderOpacity: 0.5,
        keyElevation: 3.0,
        keycapStyle: .raised,
        fontDesign: "monospaced"
    )

    public static let cyberpunk = KeyboardTheme(
        id: "cyberpunk",
        name: "Cyberpunk 2077",
        isBuiltIn: true,
        backgroundColorHex: "#050505",
        backgroundOpacity: 0.96,
        backgroundBlur: true,
        keycapBaseColorHex: "#181B1E",
        keycapActiveColorHex: "#FACC15",
        keycapTextColorHex: "#A3E635",
        accentColorHex: "#FACC15",
        modifierKeyColorHex: "#121416",
        cornerRadius: 4.0,
        keySpacing: 5.0,
        borderWidth: 1.5,
        borderColorHex: "#FACC15",
        borderOpacity: 0.55,
        keyElevation: 2.0,
        keycapStyle: .flat,
        fontDesign: "monospaced"
    )

    public static let classicRetro = KeyboardTheme(
        id: "classic_retro",
        name: "Classic Retro",
        isBuiltIn: true,
        backgroundColorHex: "#C8C4B7",
        backgroundOpacity: 0.98,
        backgroundBlur: false,
        keycapBaseColorHex: "#E6E2D3",
        keycapActiveColorHex: "#FFFFFF",
        keycapTextColorHex: "#292524",
        accentColorHex: "#EA580C",
        modifierKeyColorHex: "#DDD8C8",
        cornerRadius: 5.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#A8A29E",
        borderOpacity: 0.7,
        keyElevation: 3.0,
        keycapStyle: .raised,
        fontDesign: "serif"
    )

    public static let frostGlass = KeyboardTheme(
        id: "frost_glass",
        name: "Frost Glass",
        isBuiltIn: true,
        backgroundColorHex: "#FFFFFF",
        backgroundOpacity: 0.20,
        backgroundBlur: true,
        keycapBaseColorHex: "#FFFFFF",
        keycapActiveColorHex: "#38BDF8",
        keycapTextColorHex: "#FFFFFF",
        accentColorHex: "#38BDF8",
        modifierKeyColorHex: "#FFFFFF",
        cornerRadius: 8.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#FFFFFF",
        borderOpacity: 0.35,
        keyElevation: 1.0,
        keycapStyle: .glass,
        fontDesign: "rounded"
    )

    public static let builtInThemes: [KeyboardTheme] = [
        .appleNative,
        .darkMechanical,
        .minimalistLight,
        .midnightNeon,
        .cyberpunk,
        .classicRetro,
        .frostGlass
    ]
}
