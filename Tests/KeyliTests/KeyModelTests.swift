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

        #expect(key.displayedLabel(shift: false, option: false) == "a")
        #expect(key.displayedLabel(shift: true, option: false) == "A")
        #expect(key.displayedLabel(shift: false, option: true) == "å")
        #expect(key.displayedLabel(shift: true, option: true) == "Å")
        #expect(key.displayedLabel(shift: false, option: false, capsLock: true) == "A")
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
