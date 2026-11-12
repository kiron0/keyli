import Testing
import Foundation
@testable import Keyli

@Suite("Keyli Configuration Tests")
struct ConfigTests {
    @Test("Default Configuration Invariants")
    func testDefaultConfigValues() {
        let config = KeyliConfig()
        #expect(config.version == 1)
        #expect(config.themeId == "apple_native")
        #expect(config.layoutGeometry == "ansi")
        #expect(config.isFloatingPinned == true)
        #expect(config.showMenuBarIcon == true)
        #expect(config.modifierStickyMode == true)
        #expect(config.isPhysicalMonitoringEnabled == false)
        #expect(config.isFloatingVisible == true)
        #expect(config.keyRepeatEnabled == true)
    }

    @Test("Older Stored Configuration Still Decodes")
    func testLegacyConfigDecoding() throws {
        let legacy = """
        {"version":1,"themeId":"cyberpunk","isPhysicalMonitoringEnabled":true,"alwaysOnTop":true,"keyClickVolume":0.6}
        """
        let decoded = try JSONDecoder().decode(KeyliConfig.self, from: Data(legacy.utf8))

        #expect(decoded.themeId == "cyberpunk")
        #expect(decoded.isPhysicalMonitoringEnabled == true)
        #expect(decoded.layoutGeometry == "ansi")
        #expect(decoded.isFloatingVisible == true)
        #expect(decoded.floatingWindowX == nil)
    }

    @Test("Config Store Persists And Resets")
    func testConfigStorePersistence() {
        let suiteName = "io.coreify.keyli.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConfigStore(defaults: defaults)
        store.config.layoutGeometry = "jis"
        #expect(ConfigStore(defaults: defaults).config.layoutGeometry == "jis")

        store.resetToDefaults()
        #expect(ConfigStore(defaults: defaults).config == KeyliConfig())
    }

    @Test("Configuration Serialization")
    func testConfigSerialization() throws {
        var config = KeyliConfig()
        config.themeId = "cyberpunk"
        config.floatingOpacity = 0.8
        config.layoutGeometry = "iso"

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(KeyliConfig.self, from: data)

        #expect(decoded.themeId == "cyberpunk")
        #expect(decoded.floatingOpacity == 0.8)
        #expect(decoded.layoutGeometry == "iso")
    }
}
