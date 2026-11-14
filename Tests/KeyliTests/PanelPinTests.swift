import Testing
import AppKit
@testable import Keyli

@Suite("Floating Keyboard Pin", .serialized)
@MainActor
struct PanelPinTests {
    @Test("Pin keeps the keyboard above other windows, unpin lets them cover it, and it stays movable")
    func testPinSwitchesWindowLevel() {
        let store = ConfigStore.shared
        let original = store.config
        defer { store.config = original }

        let panel = PanelManager.shared.getOrCreateFloatingPanel()

        store.config.isFloatingPinned = true
        PanelManager.shared.applyWindowConfig()
        #expect(panel.level == .floating)
        #expect(panel.isMovable)

        store.config.isFloatingPinned = false
        PanelManager.shared.applyWindowConfig()
        #expect(panel.level == .normal)
        #expect(panel.isMovable)
    }
}
