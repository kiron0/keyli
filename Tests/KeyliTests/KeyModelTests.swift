import Testing
import Foundation
@testable import Keyli

@Suite("Keyboard Key Model Tests")
struct KeyModelTests {
    @Test("Displayed Label With Modifier Combinations")
    func testDisplayedLabelWithModifiers() {
        let key = KeyboardKey(
            id: "key-a",
            keyCode: 0,
            kind: .character,
            unitFrame: KeyUnitFrame(x: 0, y: 0),
            labels: KeyLabels(
                defaultLabel: "a",
                shiftLabel: "A",
                optionLabel: "å",
                shiftOptionLabel: "Å"
            )
        )

        // Normal
        #expect(key.displayedLabel(shift: false, option: false) == "a")
        // Shift
        #expect(key.displayedLabel(shift: true, option: false) == "A")
        // Option
        #expect(key.displayedLabel(shift: false, option: true) == "å")
        // Shift + Option
        #expect(key.displayedLabel(shift: true, option: true) == "Å")
        // CapsLock ON
        #expect(key.displayedLabel(shift: false, option: false, capsLock: true) == "A")
        // CapsLock ON + Shift ON
        #expect(key.displayedLabel(shift: true, option: false, capsLock: true) == "a")
    }

    @Test("Fallback To Default When Modifier Label Missing")
    func testFallbackToDefaultWhenModifierLabelMissing() {
        let key = KeyboardKey(
            id: "key-space",
            keyCode: 49,
            kind: .character,
            unitFrame: KeyUnitFrame(x: 0, y: 0),
            labels: KeyLabels(defaultLabel: " ")
        )

        #expect(key.displayedLabel(shift: true, option: false) == " ")
        #expect(key.displayedLabel(shift: false, option: true) == " ")
    }
}
