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

    public static let graphite = KeyboardTheme(
        id: "graphite",
        name: "Graphite",
        isBuiltIn: true,
        backgroundColorHex: "#2B2D31",
        backgroundOpacity: 0.9,
        backgroundBlur: true,
        keycapBaseColorHex: "#3A3D43",
        keycapActiveColorHex: "#E5E7EB",
        keycapTextColorHex: "#E5E7EB",
        accentColorHex: "#8E8E93",
        modifierKeyColorHex: "#33363B",
        cornerRadius: 5.0,
        keySpacing: 4.0,
        borderWidth: 0.5,
        borderColorHex: "#4B4F57",
        borderOpacity: 0.6,
        keyElevation: 1.2,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let silverAluminum = KeyboardTheme(
        id: "silver_aluminum",
        name: "Silver Aluminum",
        isBuiltIn: true,
        backgroundColorHex: "#D9DBDF",
        backgroundOpacity: 0.85,
        backgroundBlur: true,
        keycapBaseColorHex: "#F4F5F7",
        keycapActiveColorHex: "#5B6270",
        keycapTextColorHex: "#2B2F36",
        accentColorHex: "#5E7CE2",
        modifierKeyColorHex: "#E6E8EC",
        cornerRadius: 5.0,
        keySpacing: 4.0,
        borderWidth: 0.5,
        borderColorHex: "#AEB3BD",
        borderOpacity: 0.7,
        keyElevation: 1.2,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let spaceBlack = KeyboardTheme(
        id: "space_black",
        name: "Space Black",
        isBuiltIn: true,
        backgroundColorHex: "#0B0B0D",
        backgroundOpacity: 0.92,
        backgroundBlur: true,
        keycapBaseColorHex: "#1B1B1F",
        keycapActiveColorHex: "#F2F2F7",
        keycapTextColorHex: "#F2F2F7",
        accentColorHex: "#0A84FF",
        modifierKeyColorHex: "#141417",
        cornerRadius: 6.0,
        keySpacing: 4.0,
        borderWidth: 0.5,
        borderColorHex: "#2C2C30",
        borderOpacity: 0.8,
        keyElevation: 1.0,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let paperWhite = KeyboardTheme(
        id: "paper_white",
        name: "Paper White",
        isBuiltIn: true,
        backgroundColorHex: "#FAF8F3",
        backgroundOpacity: 0.98,
        backgroundBlur: false,
        keycapBaseColorHex: "#FFFFFF",
        keycapActiveColorHex: "#3A3A3A",
        keycapTextColorHex: "#2E2E2E",
        accentColorHex: "#C2410C",
        modifierKeyColorHex: "#F3F0E8",
        cornerRadius: 4.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#D6D1C4",
        borderOpacity: 0.9,
        keyElevation: 0.8,
        keycapStyle: .flat,
        fontDesign: "serif"
    )

    public static let terminalGreen = KeyboardTheme(
        id: "terminal_green",
        name: "Terminal Green",
        isBuiltIn: true,
        backgroundColorHex: "#020A04",
        backgroundOpacity: 0.96,
        backgroundBlur: false,
        keycapBaseColorHex: "#06140A",
        keycapActiveColorHex: "#22C55E",
        keycapTextColorHex: "#4ADE80",
        accentColorHex: "#22C55E",
        modifierKeyColorHex: "#04100A",
        cornerRadius: 3.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#14532D",
        borderOpacity: 0.9,
        keyElevation: 0.0,
        keycapStyle: .flat,
        fontDesign: "monospaced"
    )

    public static let amberCrt = KeyboardTheme(
        id: "amber_crt",
        name: "Amber CRT",
        isBuiltIn: true,
        backgroundColorHex: "#0C0700",
        backgroundOpacity: 0.96,
        backgroundBlur: false,
        keycapBaseColorHex: "#1A1002",
        keycapActiveColorHex: "#F59E0B",
        keycapTextColorHex: "#FBBF24",
        accentColorHex: "#F59E0B",
        modifierKeyColorHex: "#120B01",
        cornerRadius: 3.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#78350F",
        borderOpacity: 0.9,
        keyElevation: 0.0,
        keycapStyle: .flat,
        fontDesign: "monospaced"
    )

    public static let oceanBreeze = KeyboardTheme(
        id: "ocean_breeze",
        name: "Ocean Breeze",
        isBuiltIn: true,
        backgroundColorHex: "#0B2236",
        backgroundOpacity: 0.9,
        backgroundBlur: true,
        keycapBaseColorHex: "#123553",
        keycapActiveColorHex: "#7DD3FC",
        keycapTextColorHex: "#E0F2FE",
        accentColorHex: "#38BDF8",
        modifierKeyColorHex: "#0F2C45",
        cornerRadius: 7.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#1E4E75",
        borderOpacity: 0.7,
        keyElevation: 2.0,
        keycapStyle: .raised,
        fontDesign: "rounded"
    )

    public static let forestMoss = KeyboardTheme(
        id: "forest_moss",
        name: "Forest Moss",
        isBuiltIn: true,
        backgroundColorHex: "#16231B",
        backgroundOpacity: 0.94,
        backgroundBlur: true,
        keycapBaseColorHex: "#22352A",
        keycapActiveColorHex: "#A7F3D0",
        keycapTextColorHex: "#D1FAE5",
        accentColorHex: "#34D399",
        modifierKeyColorHex: "#1B2C22",
        cornerRadius: 6.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#2F4A3A",
        borderOpacity: 0.7,
        keyElevation: 2.2,
        keycapStyle: .raised,
        fontDesign: "default"
    )

    public static let sakuraBlossom = KeyboardTheme(
        id: "sakura_blossom",
        name: "Sakura Blossom",
        isBuiltIn: true,
        backgroundColorHex: "#FCE7EF",
        backgroundOpacity: 0.95,
        backgroundBlur: true,
        keycapBaseColorHex: "#FFF5F8",
        keycapActiveColorHex: "#BE185D",
        keycapTextColorHex: "#831843",
        accentColorHex: "#EC4899",
        modifierKeyColorHex: "#FBDDE7",
        cornerRadius: 8.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#F4B6CB",
        borderOpacity: 0.8,
        keyElevation: 1.5,
        keycapStyle: .chicklet,
        fontDesign: "rounded"
    )

    public static let sunsetGlow = KeyboardTheme(
        id: "sunset_glow",
        name: "Sunset Glow",
        isBuiltIn: true,
        backgroundColorHex: "#2A1220",
        backgroundOpacity: 0.92,
        backgroundBlur: true,
        keycapBaseColorHex: "#3D1A2C",
        keycapActiveColorHex: "#FDBA74",
        keycapTextColorHex: "#FED7AA",
        accentColorHex: "#FB923C",
        modifierKeyColorHex: "#341626",
        cornerRadius: 7.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#7C2D4A",
        borderOpacity: 0.6,
        keyElevation: 2.2,
        keycapStyle: .raised,
        fontDesign: "rounded"
    )

    public static let lavenderHaze = KeyboardTheme(
        id: "lavender_haze",
        name: "Lavender Haze",
        isBuiltIn: true,
        backgroundColorHex: "#EDE9FE",
        backgroundOpacity: 0.94,
        backgroundBlur: true,
        keycapBaseColorHex: "#F7F5FF",
        keycapActiveColorHex: "#6D28D9",
        keycapTextColorHex: "#3B2A6B",
        accentColorHex: "#8B5CF6",
        modifierKeyColorHex: "#E4DEFC",
        cornerRadius: 7.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#C4B5FD",
        borderOpacity: 0.8,
        keyElevation: 1.4,
        keycapStyle: .chicklet,
        fontDesign: "rounded"
    )

    public static let mintFresh = KeyboardTheme(
        id: "mint_fresh",
        name: "Mint Fresh",
        isBuiltIn: true,
        backgroundColorHex: "#E6F7F1",
        backgroundOpacity: 0.95,
        backgroundBlur: true,
        keycapBaseColorHex: "#F6FDFA",
        keycapActiveColorHex: "#047857",
        keycapTextColorHex: "#064E3B",
        accentColorHex: "#10B981",
        modifierKeyColorHex: "#DCF3EA",
        cornerRadius: 6.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#A7DCC7",
        borderOpacity: 0.8,
        keyElevation: 1.4,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let mochaLatte = KeyboardTheme(
        id: "mocha_latte",
        name: "Mocha Latte",
        isBuiltIn: true,
        backgroundColorHex: "#3B2A22",
        backgroundOpacity: 0.95,
        backgroundBlur: false,
        keycapBaseColorHex: "#5A4034",
        keycapActiveColorHex: "#F5E6D3",
        keycapTextColorHex: "#F5E6D3",
        accentColorHex: "#D4A373",
        modifierKeyColorHex: "#4B352B",
        cornerRadius: 6.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#7A5A48",
        borderOpacity: 0.7,
        keyElevation: 2.6,
        keycapStyle: .raised,
        fontDesign: "serif"
    )

    public static let polarNight = KeyboardTheme(
        id: "polar_night",
        name: "Polar Night",
        isBuiltIn: true,
        backgroundColorHex: "#2E3440",
        backgroundOpacity: 0.94,
        backgroundBlur: true,
        keycapBaseColorHex: "#3B4252",
        keycapActiveColorHex: "#88C0D0",
        keycapTextColorHex: "#ECEFF4",
        accentColorHex: "#88C0D0",
        modifierKeyColorHex: "#343B49",
        cornerRadius: 6.0,
        keySpacing: 4.5,
        borderWidth: 0.8,
        borderColorHex: "#4C566A",
        borderOpacity: 0.7,
        keyElevation: 1.6,
        keycapStyle: .chicklet,
        fontDesign: "default"
    )

    public static let solarDark = KeyboardTheme(
        id: "solar_dark",
        name: "Solar Dark",
        isBuiltIn: true,
        backgroundColorHex: "#002B36",
        backgroundOpacity: 0.96,
        backgroundBlur: false,
        keycapBaseColorHex: "#073642",
        keycapActiveColorHex: "#B58900",
        keycapTextColorHex: "#EEE8D5",
        accentColorHex: "#268BD2",
        modifierKeyColorHex: "#04313C",
        cornerRadius: 5.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#0E4B59",
        borderOpacity: 0.8,
        keyElevation: 1.6,
        keycapStyle: .raised,
        fontDesign: "monospaced"
    )

    public static let solarLight = KeyboardTheme(
        id: "solar_light",
        name: "Solar Light",
        isBuiltIn: true,
        backgroundColorHex: "#FDF6E3",
        backgroundOpacity: 0.97,
        backgroundBlur: false,
        keycapBaseColorHex: "#EEE8D5",
        keycapActiveColorHex: "#268BD2",
        keycapTextColorHex: "#586E75",
        accentColorHex: "#CB4B16",
        modifierKeyColorHex: "#E8E1CB",
        cornerRadius: 5.0,
        keySpacing: 4.0,
        borderWidth: 1.0,
        borderColorHex: "#D3CBB4",
        borderOpacity: 0.8,
        keyElevation: 1.6,
        keycapStyle: .raised,
        fontDesign: "monospaced"
    )

    public static let vampireNight = KeyboardTheme(
        id: "vampire_night",
        name: "Vampire Night",
        isBuiltIn: true,
        backgroundColorHex: "#1E1F29",
        backgroundOpacity: 0.95,
        backgroundBlur: true,
        keycapBaseColorHex: "#2B2D3A",
        keycapActiveColorHex: "#FF79C6",
        keycapTextColorHex: "#F8F8F2",
        accentColorHex: "#BD93F9",
        modifierKeyColorHex: "#252632",
        cornerRadius: 6.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#44475A",
        borderOpacity: 0.8,
        keyElevation: 2.0,
        keycapStyle: .raised,
        fontDesign: "monospaced"
    )

    public static let carbonFiber = KeyboardTheme(
        id: "carbon_fiber",
        name: "Carbon Fiber",
        isBuiltIn: true,
        backgroundColorHex: "#111214",
        backgroundOpacity: 0.96,
        backgroundBlur: false,
        keycapBaseColorHex: "#1C1D20",
        keycapActiveColorHex: "#EF4444",
        keycapTextColorHex: "#D4D4D8",
        accentColorHex: "#EF4444",
        modifierKeyColorHex: "#161719",
        cornerRadius: 3.0,
        keySpacing: 5.0,
        borderWidth: 1.2,
        borderColorHex: "#3F3F46",
        borderOpacity: 0.8,
        keyElevation: 2.8,
        keycapStyle: .raised,
        fontDesign: "monospaced"
    )

    public static let roseGold = KeyboardTheme(
        id: "rose_gold",
        name: "Rose Gold",
        isBuiltIn: true,
        backgroundColorHex: "#F6E3DD",
        backgroundOpacity: 0.95,
        backgroundBlur: true,
        keycapBaseColorHex: "#FFF6F2",
        keycapActiveColorHex: "#B76E79",
        keycapTextColorHex: "#5A3A3F",
        accentColorHex: "#B76E79",
        modifierKeyColorHex: "#F1DAD2",
        cornerRadius: 8.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#E3BDB3",
        borderOpacity: 0.8,
        keyElevation: 1.5,
        keycapStyle: .chicklet,
        fontDesign: "rounded"
    )

    public static let matcha = KeyboardTheme(
        id: "matcha",
        name: "Matcha",
        isBuiltIn: true,
        backgroundColorHex: "#E8EDD9",
        backgroundOpacity: 0.96,
        backgroundBlur: false,
        keycapBaseColorHex: "#F5F8EC",
        keycapActiveColorHex: "#5A7A2E",
        keycapTextColorHex: "#2F3B1E",
        accentColorHex: "#7BA05B",
        modifierKeyColorHex: "#DFE6CC",
        cornerRadius: 6.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#B8C79A",
        borderOpacity: 0.8,
        keyElevation: 1.8,
        keycapStyle: .raised,
        fontDesign: "rounded"
    )

    public static let deepOceanGlass = KeyboardTheme(
        id: "deep_ocean_glass",
        name: "Deep Ocean Glass",
        isBuiltIn: true,
        backgroundColorHex: "#0C4A6E",
        backgroundOpacity: 0.28,
        backgroundBlur: true,
        keycapBaseColorHex: "#7DD3FC",
        keycapActiveColorHex: "#38BDF8",
        keycapTextColorHex: "#F0F9FF",
        accentColorHex: "#38BDF8",
        modifierKeyColorHex: "#BAE6FD",
        cornerRadius: 9.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#E0F2FE",
        borderOpacity: 0.35,
        keyElevation: 1.0,
        keycapStyle: .glass,
        fontDesign: "rounded"
    )

    public static let auroraGlass = KeyboardTheme(
        id: "aurora_glass",
        name: "Aurora Glass",
        isBuiltIn: true,
        backgroundColorHex: "#4C1D95",
        backgroundOpacity: 0.26,
        backgroundBlur: true,
        keycapBaseColorHex: "#C4B5FD",
        keycapActiveColorHex: "#34D399",
        keycapTextColorHex: "#FFFFFF",
        accentColorHex: "#34D399",
        modifierKeyColorHex: "#DDD6FE",
        cornerRadius: 9.0,
        keySpacing: 4.5,
        borderWidth: 1.0,
        borderColorHex: "#FFFFFF",
        borderOpacity: 0.35,
        keyElevation: 1.0,
        keycapStyle: .glass,
        fontDesign: "rounded"
    )

    public static let highContrast = KeyboardTheme(
        id: "high_contrast",
        name: "High Contrast",
        isBuiltIn: true,
        backgroundColorHex: "#000000",
        backgroundOpacity: 1.0,
        backgroundBlur: false,
        keycapBaseColorHex: "#000000",
        keycapActiveColorHex: "#FFFF00",
        keycapTextColorHex: "#FFFFFF",
        accentColorHex: "#FFFF00",
        modifierKeyColorHex: "#000000",
        cornerRadius: 4.0,
        keySpacing: 5.0,
        borderWidth: 2.0,
        borderColorHex: "#FFFFFF",
        borderOpacity: 1.0,
        keyElevation: 0.0,
        keycapStyle: .flat,
        fontDesign: "default"
    )

    public static let bubblegum = KeyboardTheme(
        id: "bubblegum",
        name: "Bubblegum",
        isBuiltIn: true,
        backgroundColorHex: "#FFE4F1",
        backgroundOpacity: 0.95,
        backgroundBlur: true,
        keycapBaseColorHex: "#FFFFFF",
        keycapActiveColorHex: "#06B6D4",
        keycapTextColorHex: "#9D174D",
        accentColorHex: "#06B6D4",
        modifierKeyColorHex: "#FFD6EA",
        cornerRadius: 10.0,
        keySpacing: 5.0,
        borderWidth: 1.5,
        borderColorHex: "#F9A8D4",
        borderOpacity: 0.9,
        keyElevation: 2.4,
        keycapStyle: .raised,
        fontDesign: "rounded"
    )

    public static let builtInThemes: [KeyboardTheme] = [
        .appleNative,
        .darkMechanical,
        .minimalistLight,
        .midnightNeon,
        .cyberpunk,
        .classicRetro,
        .frostGlass,
        .graphite,
        .silverAluminum,
        .spaceBlack,
        .paperWhite,
        .terminalGreen,
        .amberCrt,
        .oceanBreeze,
        .forestMoss,
        .sakuraBlossom,
        .sunsetGlow,
        .lavenderHaze,
        .mintFresh,
        .mochaLatte,
        .polarNight,
        .solarDark,
        .solarLight,
        .vampireNight,
        .carbonFiber,
        .roseGold,
        .matcha,
        .deepOceanGlass,
        .auroraGlass,
        .highContrast,
        .bubblegum
    ]
}
