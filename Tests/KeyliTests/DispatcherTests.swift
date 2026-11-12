import Testing
import Foundation
import Combine
import ServiceManagement
import IOKit.hid
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

    @Test("Media And System Keys Work Without A Target App")
    func testSystemKeysNeedNoTarget() {
        let plan = KeyboardInputDispatcher.plan
        #expect(plan(.system(.mute), true, false, true, false) == .send)
        #expect(plan(.system(.volumeUp), true, true, false, false) == .send)
        #expect(plan(.system(.missionControl), false, false, true, false) == .send)
        #expect(plan(.system(.mute), false, false, false, true) == .refuse(.missingPermission))
    }

    @Test("Typing Refuses Or Refocuses Safely")
    func testTypingPlan() {
        let plan = KeyboardInputDispatcher.plan
        let text = KeyDispatchAction.text("a", keyCode: 0)
        #expect(plan(text, true, false, false, true) == .send)
        #expect(plan(text, false, false, false, true) == .refuse(.missingPermission))
        #expect(plan(text, true, true, false, true) == .refuse(.secureInput))
        #expect(plan(text, true, false, false, false) == .refuse(.noTarget))
        #expect(plan(text, true, false, true, true) == .activateTargetThenSend)
        #expect(plan(text, true, false, true, false) == .refuse(.noTarget))
        #expect(plan(.keyCode(36), true, false, true, true) == .activateTargetThenSend)
    }

    @Test("Live Permission Status Mapping")
    func testLivePermissionStatus() {
        #expect(PermissionStatus.accessibility(trusted: true, wasGrantedBefore: false, isWaiting: true) == .granted)
        #expect(PermissionStatus.accessibility(trusted: false, wasGrantedBefore: false, isWaiting: true) == .waiting)
        #expect(PermissionStatus.accessibility(trusted: false, wasGrantedBefore: true, isWaiting: false) == .needsRepair)

        #expect(PermissionStatus.inputMonitoring(access: kIOHIDAccessTypeGranted, tapNeeded: true, tapRunning: true, wasGrantedBefore: false, isWaiting: false) == .granted)
        #expect(PermissionStatus.inputMonitoring(access: kIOHIDAccessTypeGranted, tapNeeded: false, tapRunning: false, wasGrantedBefore: false, isWaiting: false) == .granted)
        #expect(PermissionStatus.inputMonitoring(access: kIOHIDAccessTypeGranted, tapNeeded: true, tapRunning: false, wasGrantedBefore: true, isWaiting: false) == .needsRelaunch)
        #expect(PermissionStatus.inputMonitoring(access: kIOHIDAccessTypeDenied, tapNeeded: true, tapRunning: false, wasGrantedBefore: false, isWaiting: false) == .denied)
        #expect(PermissionStatus.inputMonitoring(access: kIOHIDAccessTypeDenied, tapNeeded: true, tapRunning: false, wasGrantedBefore: true, isWaiting: false) == .needsRepair)
        #expect(PermissionStatus.inputMonitoring(access: kIOHIDAccessTypeUnknown, tapNeeded: true, tapRunning: false, wasGrantedBefore: false, isWaiting: true) == .waiting)

        #expect(PermissionStatus.loginItem(.enabled, wanted: false) == .granted)
        #expect(PermissionStatus.loginItem(.requiresApproval, wanted: true) == .requiresApproval)
        #expect(PermissionStatus.loginItem(.notRegistered, wanted: false) == .off)
        #expect(PermissionStatus.loginItem(.notRegistered, wanted: true) == .notGranted)
    }

    @Test("Every Key On Every Layout Produces The Right Action")
    func testEveryKeyAction() {
        let dispatcher = KeyboardInputDispatcher.shared
        let expectedKeyCodes: [String: UInt16] = [
            "k_esc": 53, "k_tab": 48, "k_return": 36, "k_delete": 51,
            "k_larrow": 123, "k_rarrow": 124, "k_uarrow": 126, "k_darrow": 125,
            "k_eisu": 102, "k_kana": 104
        ]
        let mediaKeys: [UInt16: KeySystemAction] = [
            122: .brightnessDown, 120: .brightnessUp, 99: .missionControl, 118: .spotlight,
            98: .previousTrack, 100: .playPause, 101: .nextTrack,
            109: .mute, 103: .volumeDown, 111: .volumeUp
        ]

        for geometry in GeometryType.allCases {
            let layout = KeyboardLayoutManager.shared.generateLayout(geometry: geometry)
            for key in layout.keys {
                let plain = KeyboardState()
                let action = dispatcher.action(for: key, state: plain)

                switch key.kind {
                case .character:
                    if case .text(let text, let code) = action {
                        #expect(!text.isEmpty, "\(geometry.rawValue) \(key.id) types nothing")
                        #expect(code == key.keyCode)
                    } else {
                        Issue.record("\(geometry.rawValue) \(key.id) should type text, got \(action)")
                    }

                    let command = KeyboardState()
                    command.isCommandActive = true
                    #expect(dispatcher.action(for: key, state: command) == .keyCode(key.keyCode))

                    let shifted = KeyboardState()
                    shifted.isShiftActive = true
                    if case .text(let text, _) = dispatcher.action(for: key, state: shifted) {
                        #expect(!text.isEmpty)
                    } else {
                        Issue.record("\(key.id) shifted should type text")
                    }

                case .modifier:
                    #expect(action == .toggleModifier(key.modifierType!), "\(key.id)")

                case .function:
                    if let media = mediaKeys[key.keyCode] {
                        #expect(action == .system(media), "\(key.id)")
                    } else {
                        #expect(action == .keyCode(key.keyCode), "\(key.id)")
                    }
                    let fn = KeyboardState()
                    fn.isFnActive = true
                    #expect(dispatcher.action(for: key, state: fn) == .keyCode(key.keyCode), "fn+\(key.id)")

                case .navigation, .system:
                    if key.id == "k_lock" {
                        #expect(action == .system(.lockScreen))
                    } else if let expected = expectedKeyCodes[key.id] {
                        #expect(action == .keyCode(expected), "\(key.id)")
                    } else {
                        Issue.record("\(key.id) has no expected key code")
                    }

                case .spacer:
                    #expect(action == .none)
                }
            }
        }
    }

    @Test("Fn Turns Arrows, Delete And Return Into Their Alternate Keys")
    func testFnAlternates() {
        let dispatcher = KeyboardInputDispatcher.shared
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        let fn = KeyboardState()
        fn.isFnActive = true
        let expected: [String: UInt16] = ["k_larrow": 115, "k_rarrow": 119, "k_uarrow": 116, "k_darrow": 121, "k_delete": 117, "k_return": 76]
        for (id, code) in expected {
            let key = layout.keys.first { $0.id == id }!
            #expect(dispatcher.action(for: key, state: fn) == .keyCode(code), "fn+\(id)")
        }
        let esc = layout.keys.first { $0.id == "k_esc" }!
        #expect(dispatcher.action(for: esc, state: fn) == .keyCode(53))
    }

    @Test("Held Key Repeats With The Modifiers From The Moment It Was Pressed")
    func testRepeatSnapshot() {
        let state = KeyboardState()
        state.isShiftActive = true
        state.isCapsLockActive = true
        let copy = state.detachedCopy()
        state.resetModifiers()
        #expect(copy.isShiftActive)
        #expect(copy.isCapsLockActive)
        #expect(copy !== state)
        #expect(state.isShiftActive == false)
    }

    @Test("Pressed Keys Publish Separately From Keyboard State")
    func testPressStateIsolation() {
        let state = KeyboardState()
        var stateChanges = 0
        let cancellable = state.objectWillChange.sink { _ in stateChanges += 1 }
        state.pressedPhysicalKeyCodes.insert(0)
        state.virtualPressedKeyId = "k_0"
        #expect(stateChanges == 0)
        #expect(state.presses.physicalKeyCodes.contains(0))
        #expect(state.isKeyCurrentlyPressed(keyCode: 5, keyId: "k_0"))

        state.setModifiers(shift: false, option: false, control: false, command: false, capsLock: false)
        #expect(stateChanges == 0)
        state.setModifiers(shift: true, option: false, control: false, command: false, capsLock: false)
        #expect(stateChanges == 1)
        cancellable.cancel()
    }
}
