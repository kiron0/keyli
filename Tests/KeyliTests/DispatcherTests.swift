import Testing
import Foundation
@testable import Keyli

@Suite("Input Dispatcher & State Tests", .serialized)
struct DispatcherTests {
    @Test("Synthetic Event Marker Invariant")
    func testSyntheticEventMarkerConstant() {
        #expect(KeyliConstants.syntheticEventUserData == 0x4B45594C)
    }

    @Test("Modifier State Toggle Logic")
    func testModifierToggleLogic() {
        let state = KeyboardState()
        #expect(state.isShiftActive == false)

        state.toggleModifier(.shift)
        #expect(state.isShiftActive == true)

        state.toggleModifier(.shift)
        #expect(state.isShiftActive == false)

        state.toggleModifier(.option)
        #expect(state.isOptionActive == true)

        state.resetModifiers()
        #expect(state.isOptionActive == false)
    }

    private func characterKey() -> KeyboardKey {
        KeyboardKey(
            id: "k_0",
            keyCode: 0,
            kind: .character,
            unitFrame: KeyUnitFrame(x: 0, y: 0),
            labels: KeyLabels(defaultLabel: "a", shiftLabel: "A", optionLabel: "å", shiftOptionLabel: "Å")
        )
    }

    @Test("Character Keys Resolve To Text With Modifiers")
    func testCharacterActionResolution() {
        let dispatcher = KeyboardInputDispatcher.shared
        let state = KeyboardState()
        let key = characterKey()

        #expect(dispatcher.action(for: key, state: state) == .text("a", keyCode: 0))

        state.isShiftActive = true
        #expect(dispatcher.action(for: key, state: state) == .text("A", keyCode: 0))

        state.isOptionActive = true
        #expect(dispatcher.action(for: key, state: state) == .text("Å", keyCode: 0))
    }

    @Test("Command And Control Send Keycodes For Shortcuts")
    func testShortcutActionResolution() {
        let dispatcher = KeyboardInputDispatcher.shared
        let state = KeyboardState()
        let key = characterKey()

        state.isCommandActive = true
        #expect(dispatcher.action(for: key, state: state) == .keyCode(0))

        state.isCommandActive = false
        state.isControlActive = true
        #expect(dispatcher.action(for: key, state: state) == .keyCode(0))
    }

    @Test("Modifier And Spacer Keys Never Post Events")
    func testModifierAndSpacerActions() {
        let dispatcher = KeyboardInputDispatcher.shared
        let state = KeyboardState()

        let shift = KeyboardKey(
            id: "k_lshift", keyCode: 56, kind: .modifier, modifierType: .shift,
            unitFrame: KeyUnitFrame(x: 0, y: 0), labels: KeyLabels(defaultLabel: "shift")
        )
        #expect(dispatcher.action(for: shift, state: state) == .toggleModifier(.shift))

        let spacer = KeyboardKey(
            id: "k_spacer", keyCode: 0, kind: .spacer,
            unitFrame: KeyUnitFrame(x: 0, y: 0), labels: KeyLabels(defaultLabel: "")
        )
        #expect(dispatcher.action(for: spacer, state: state) == .none)
    }

    @Test("Function Keys Use Media Actions Unless Fn Is Latched")
    func testFunctionKeyActions() {
        let dispatcher = KeyboardInputDispatcher.shared
        let state = KeyboardState()
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)

        let f12 = layout.keys.first { $0.keyCode == 111 }
        #expect(f12 != nil)
        if let f12 = f12 {
            #expect(dispatcher.action(for: f12, state: state) == .system(.volumeUp))
            state.isFnActive = true
            #expect(dispatcher.action(for: f12, state: state) == .keyCode(111))
            state.isFnActive = false
        }

        let f5 = layout.keys.first { $0.keyCode == 96 }
        if let f5 = f5 {
            #expect(dispatcher.action(for: f5, state: state) == .keyCode(96))
        }

        let lock = layout.keys.first { $0.id == "k_lock" }
        if let lock = lock {
            #expect(dispatcher.action(for: lock, state: state) == .system(.lockScreen))
        }

        let returnKey = layout.keys.first { $0.id == "k_return" }
        if let returnKey = returnKey {
            #expect(dispatcher.action(for: returnKey, state: state) == .keyCode(36))
        }
    }

    @Test("Permission Status Distinguishes Never Granted From Lost")
    func testPermissionStatusResolution() {
        #expect(PermissionStatus.resolve(isGranted: true, wasGrantedBefore: false) == .granted)
        #expect(PermissionStatus.resolve(isGranted: true, wasGrantedBefore: true) == .granted)
        #expect(PermissionStatus.resolve(isGranted: false, wasGrantedBefore: false) == .notGranted)
        #expect(PermissionStatus.resolve(isGranted: false, wasGrantedBefore: true) == .needsRepair)
    }
}
