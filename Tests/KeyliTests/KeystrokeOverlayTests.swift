import Testing
import Foundation
import CoreGraphics
@testable import Keyli

@Suite("Keystroke Overlay", .serialized)
struct KeystrokeOverlayTests {
    @Test func shortcutsModeShowsOnlyShortcuts() {
        #expect(KeystrokeFormatter.keycaps(keyCode: 21, flags: [.maskCommand, .maskShift], character: "4", mode: .shortcuts) == ["⇧", "⌘", "4"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 0, flags: [], character: "a", mode: .shortcuts) == nil)
        #expect(KeystrokeFormatter.keycaps(keyCode: 0, flags: [.maskShift], character: "A", mode: .shortcuts) == nil)
        #expect(KeystrokeFormatter.keycaps(keyCode: 53, flags: [], character: nil, mode: .shortcuts) == ["esc"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 122, flags: [], character: nil, mode: .shortcuts) == ["F1"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 123, flags: [.maskControl, .maskAlternate], character: nil, mode: .shortcuts) == ["⌃", "⌥", "←"])
    }

    @Test func modifiedKeysShowTheBaseKeyNotTheComposedCharacter() {
        #expect(KeystrokeFormatter.keycaps(keyCode: 8, flags: [.maskAlternate, .maskCommand], character: "ç", mode: .shortcuts) == ["⌥", "⌘", "C"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 0, flags: [.maskControl], character: nil, mode: .shortcuts) == ["⌃", "A"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 44, flags: [.maskCommand, .maskShift], character: "?", mode: .shortcuts) == ["⇧", "⌘", "/"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 83, flags: [.maskCommand], character: "1", mode: .shortcuts)?.last != "?")
        #expect(KeystrokeFormatter.keycaps(keyCode: 0, flags: [.maskAlternate], character: "å", mode: .all) == ["⌥", "A"])
    }

    @Test func allModeShowsEveryKey() {
        #expect(KeystrokeFormatter.keycaps(keyCode: 0, flags: [], character: "a", mode: .all) == ["A"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 49, flags: [], character: " ", mode: .all) == ["space"])
        #expect(KeystrokeFormatter.keycaps(keyCode: 36, flags: [], character: nil, mode: .all) == ["↩"])
    }

    @Test func overlayFramesSitAtTopOrBottom() {
        let screen = NSRect(x: 0, y: 0, width: 1600, height: 1000)
        let bottom = KeystrokeOverlay.frame(on: screen, position: "bottom")
        let top = KeystrokeOverlay.frame(on: screen, position: "top")
        let m = KeystrokeOverlay.edgeMargin
        #expect(bottom.midX == 800 && bottom.minY == m)
        #expect(screen.maxY - top.maxY == m)
        let topLeft = KeystrokeOverlay.frame(on: screen, position: "top-left")
        let bottomRight = KeystrokeOverlay.frame(on: screen, position: "bottom-right")
        #expect(topLeft.minX == m && screen.maxY - topLeft.maxY == m)
        #expect(screen.maxX - bottomRight.maxX == m && bottomRight.minY == m)
        #expect(KeystrokeOverlay.positions.count == 6)
    }

    @Test @MainActor func overlayCollectsTypingAndShortcuts() {
        let store = ConfigStore.shared
        let saved = store.config
        defer { store.config = saved; KeystrokeOverlay.shared.hide() }
        store.config.keystrokeOverlayEnabled = true
        store.config.keystrokeOverlayMode = "all"
        let overlay = KeystrokeOverlay.shared
        overlay.handleKeyDown(keyCode: 4, flags: [], character: "h", isRepeat: false)
        overlay.handleKeyDown(keyCode: 34, flags: [], character: "i", isRepeat: false)
        overlay.handleKeyDown(keyCode: 34, flags: [], character: "i", isRepeat: true)
        #expect(overlay.currentTyped == "hi")
        overlay.handleKeyDown(keyCode: 1, flags: [.maskCommand], character: "s", isRepeat: false)
        #expect(overlay.currentKeycaps == ["⌘", "S"])
        #expect(overlay.currentTyped.isEmpty)
        #expect(overlay.isShowing)
        store.config.keystrokeOverlayEnabled = false
        overlay.handleKeyDown(keyCode: 2, flags: [.maskCommand], character: "d", isRepeat: false)
        #expect(overlay.currentKeycaps == ["⌘", "S"])
    }
}
