import Testing
import Foundation
import SwiftUI
@testable import Keyli

@Suite("Keyboard Theme Tests", .serialized)
struct ThemeTests {
    @Test("Built-in Themes Count and Presence")
    func testBuiltInThemesExist() {
        #expect(KeyboardTheme.builtInThemes.count == 7)
        let ids = KeyboardTheme.builtInThemes.map { $0.id }
        #expect(ids.contains("apple_native"))
        #expect(ids.contains("dark_mechanical"))
        #expect(ids.contains("minimalist_light"))
        #expect(ids.contains("midnight_neon"))
        #expect(ids.contains("cyberpunk"))
        #expect(ids.contains("classic_retro"))
        #expect(ids.contains("frost_glass"))
    }

    @Test("Theme JSON Encoding and Decoding")
    func testThemeJSONSerialization() throws {
        let theme = KeyboardTheme.darkMechanical
        let encoder = JSONEncoder()
        let data = try encoder.encode(theme)
        let decoded = try JSONDecoder().decode(KeyboardTheme.self, from: data)

        #expect(decoded.id == theme.id)
        #expect(decoded.name == theme.name)
        #expect(decoded.backgroundColorHex == theme.backgroundColorHex)
        #expect(decoded.accentColorHex == theme.accentColorHex)
        #expect(decoded.cornerRadius == theme.cornerRadius)
    }

    @Test("Color Hex Serialization")
    func testColorHexParsing() {
        let redColor = Color(hex: "#FF0000")
        let redHex = redColor.toHex()
        #expect(redHex.contains("FF"))
    }

    private func makeIsolatedManager() -> (ThemeManager, ConfigStore, KeyboardState, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyli-theme-tests-\(UUID().uuidString)", isDirectory: true)
        let suiteName = "io.coreify.keyli.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let configStore = ConfigStore(defaults: defaults)
        let state = KeyboardState()
        let manager = ThemeManager(themesDirectory: directory, configStore: configStore, state: state)
        return (manager, configStore, state, directory)
    }

    @Test("Theme Export and Import Roundtrip")
    func testThemeExportAndImport() {
        let (manager, _, _, directory) = makeIsolatedManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        let theme = KeyboardTheme.cyberpunk
        let json = manager.exportThemeJSON(theme)
        #expect(json != nil)

        if let json = json {
            let imported = manager.importTheme(fromJSON: json)
            #expect(imported != nil)
            #expect(imported?.isBuiltIn == false)
            #expect(imported?.accentColorHex == theme.accentColorHex)
            #expect(imported?.id != theme.id)
            #expect(manager.customThemes.count == 1)
        }
    }

    @Test("Invalid Theme JSON Is Rejected")
    func testInvalidThemeImport() {
        let (manager, _, _, directory) = makeIsolatedManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(manager.importTheme(fromJSON: "{}") == nil)
        #expect(manager.importTheme(fromJSON: "not json") == nil)
        #expect(manager.customThemes.isEmpty)
    }

    @Test("Older Theme Files Without New Fields Still Decode")
    func testLegacyThemeDecoding() throws {
        let legacy = """
        {"id":"custom_legacy","name":"Legacy","backgroundColorHex":"#101010","keycapBaseColorHex":"#202020"}
        """
        let theme = try JSONDecoder().decode(KeyboardTheme.self, from: Data(legacy.utf8))
        #expect(theme.schemaVersion == 1)
        #expect(theme.name == "Legacy")
        #expect(theme.isBuiltIn == false)
        #expect(theme.keycapStyle == KeyboardTheme.appleNative.keycapStyle)
        #expect(theme.modifierKeyColorHex == "#202020")
    }

    @Test("Duplicate, Edit, and Delete Custom Theme")
    func testCustomThemeLifecycle() {
        let (manager, configStore, state, directory) = makeIsolatedManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        let copy = manager.duplicateTheme(.darkMechanical)
        #expect(copy.isBuiltIn == false)
        #expect(copy.name == "Dark Mechanical Copy")
        #expect(manager.currentTheme.id == copy.id)
        #expect(configStore.config.themeId == copy.id)

        var edited = copy
        edited.cornerRadius = 11
        manager.updateCustomTheme(edited)
        manager.flushPendingWrites()
        #expect(state.currentTheme.cornerRadius == 11)

        let reloaded = ThemeManager(themesDirectory: directory, configStore: configStore, state: KeyboardState())
        #expect(reloaded.currentTheme.id == copy.id)
        #expect(reloaded.currentTheme.cornerRadius == 11)

        var builtIn = KeyboardTheme.darkMechanical
        builtIn.cornerRadius = 1
        manager.updateCustomTheme(builtIn)
        #expect(manager.availableThemes.first { $0.id == "dark_mechanical" }?.cornerRadius == KeyboardTheme.darkMechanical.cornerRadius)

        manager.deleteCustomTheme(edited)
        #expect(manager.customThemes.isEmpty)
        #expect(manager.currentTheme.id == KeyboardTheme.appleNative.id)
    }

    @Test("macOS Native Theme Follows System Appearance")
    func testNativeThemeFollowsAppearance() {
        let (manager, _, state, directory) = makeIsolatedManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        manager.isSystemDark = { true }
        manager.selectTheme(.appleNative)
        #expect(state.currentTheme.isDarkBackground == true)

        manager.isSystemDark = { false }
        manager.refreshResolvedTheme()
        #expect(state.currentTheme.isDarkBackground == false)
        #expect(state.currentTheme.id == KeyboardTheme.appleNative.id)

        manager.selectTheme(.darkMechanical)
        #expect(state.currentTheme == KeyboardTheme.darkMechanical)
    }

    @Test("Pressed Key Label Contrast")
    func testActiveTextContrast() {
        #expect(KeyboardTheme.appleNative.activeTextColorHex == "#000000")
        #expect(KeyboardTheme.appleNativeLight.activeTextColorHex == "#FFFFFF")
        #expect(KeyboardTheme.relativeLuminance(hex: "#FFFFFF") > 0.99)
        #expect(KeyboardTheme.relativeLuminance(hex: "#000000") < 0.01)
        #expect(KeyboardTheme.relativeLuminance(hex: "garbage") == 0)
    }
}
