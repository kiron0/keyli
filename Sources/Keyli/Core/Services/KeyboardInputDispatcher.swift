import Foundation
import CoreGraphics
import AppKit
import Carbon

public enum KeyDispatchIssue: Equatable {
    case missingPermission
    case secureInput
    case noTarget
}

public enum GlobeKeyAction: Int, Equatable {
    case doNothing = 0
    case changeInputSource = 1
    case showEmojiAndSymbols = 2
    case startDictation = 3

    public static var current: GlobeKeyAction {
        let value = CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, "com.apple.HIToolbox" as CFString) as? Int
        return value.flatMap(GlobeKeyAction.init(rawValue:)) ?? .changeInputSource
    }
}

public enum KeyDispatchAction: Equatable {
    case none
    case toggleModifier(ModifierType)
    case text(String, keyCode: UInt16)
    case keyCode(UInt16)
    case system(KeySystemAction)
}

public final class KeyboardInputDispatcher {
    public static let shared = KeyboardInputDispatcher()

    private init() {}

    public func action(for key: KeyboardKey, state: KeyboardState) -> KeyDispatchAction {
        switch key.kind {
        case .modifier:
            if let mod = key.modifierType {
                return .toggleModifier(mod)
            }
            return .none

        case .character:
            if state.isCommandActive || state.isControlActive {
                return .keyCode(key.keyCode)
            }
            let textToType = key.displayedLabel(
                shift: state.isShiftActive,
                option: state.isOptionActive,
                capsLock: state.isCapsLockActive
            )
            return textToType.isEmpty ? .none : .text(textToType, keyCode: key.keyCode)

        case .function, .navigation, .system:
            if state.isFnActive, let mapped = KeyboardInputDispatcher.fnAlternateKeyCode(for: key) {
                return .keyCode(mapped)
            }
            if let systemAction = key.systemAction {
                if key.kind != .function || !state.isFnActive {
                    return .system(systemAction)
                }
            }
            return key.keyCode == KeyliConstants.noKeyCode ? .none : .keyCode(key.keyCode)

        case .spacer:
            return .none
        }
    }

    public static func fnAlternateKeyCode(for key: KeyboardKey) -> UInt16? {
        switch key.keyCode {
        case 123: return 115
        case 124: return 119
        case 126: return 116
        case 125: return 121
        case 51: return 117
        case 36: return 76
        default: return nil
        }
    }

    public enum DispatchPlan: Equatable {
        case send
        case activateTargetThenSend
        case refuse(KeyDispatchIssue)
    }

    public static func needsTargetApp(_ action: KeyDispatchAction) -> Bool {
        switch action {
        case .text, .keyCode:
            return true
        case .system, .none, .toggleModifier:
            return false
        }
    }

    public static func needsEventPermission(_ action: KeyDispatchAction) -> Bool {
        switch action {
        case .system(.missionControl):
            return false
        case .text, .keyCode, .system:
            return true
        case .none, .toggleModifier:
            return false
        }
    }

    public static func plan(
        for action: KeyDispatchAction,
        canPostEvents: Bool,
        secureInput: Bool,
        keyliIsActive: Bool,
        hasTarget: Bool
    ) -> DispatchPlan {
        if needsEventPermission(action) && !canPostEvents {
            return .refuse(.missingPermission)
        }
        guard needsTargetApp(action) else {
            return .send
        }
        if secureInput {
            return .refuse(.secureInput)
        }
        if keyliIsActive {
            return hasTarget ? .activateTargetThenSend : .refuse(.noTarget)
        }
        return hasTarget ? .send : .refuse(.noTarget)
    }

    public enum GlobeTapOutcome: Equatable {
        case switchedInputSource
        case showedEmoji
        case latchedFn
    }

    public static func globeTapPlan(_ setting: GlobeKeyAction, inputSourceCount: Int) -> GlobeTapOutcome {
        switch setting {
        case .changeInputSource:
            return inputSourceCount > 1 ? .switchedInputSource : .latchedFn
        case .showEmojiAndSymbols:
            return .showedEmoji
        case .doNothing, .startDictation:
            return .latchedFn
        }
    }

    @discardableResult
    public func handleGlobeTap(state: KeyboardState) -> GlobeTapOutcome {
        let outcome = KeyboardInputDispatcher.globeTapPlan(GlobeKeyAction.current, inputSourceCount: InputSourceService.shared.sources.count)
        switch outcome {
        case .switchedInputSource:
            if InputSourceService.shared.selectNext() {
                SoundService.shared.playModifierClick()
                if state.isFnActive { state.isFnActive = false }
                return outcome
            }
            state.toggleModifier(.fn)
            SoundService.shared.playModifierClick()
            return .latchedFn
        case .showedEmoji:
            let shortcutState = KeyboardState()
            shortcutState.isControlActive = true
            shortcutState.isCommandActive = true
            let space = KeyboardKey(id: "k_space", keyCode: 49, kind: .character, unitFrame: KeyUnitFrame(x: 0, y: 0), labels: KeyLabels(defaultLabel: " "))
            dispatchKey(space, state: shortcutState)
            if state.isFnActive { state.isFnActive = false }
            return outcome
        case .latchedFn:
            state.toggleModifier(.fn)
            SoundService.shared.playModifierClick()
            return outcome
        }
    }

    /// Dispatches a virtual key press into the active system application
    @discardableResult
    public func dispatchKey(_ key: KeyboardKey, state: KeyboardState) -> KeyDispatchIssue? {
        let action = action(for: key, state: state)

        switch action {
        case .none:
            return nil
        case .toggleModifier(let mod):
            state.toggleModifier(mod)
            SoundService.shared.playModifierClick()
            return nil
        default:
            break
        }

        let plan = KeyboardInputDispatcher.plan(
            for: action,
            canPostEvents: PermissionsManager.canTypeNow,
            secureInput: IsSecureEventInputEnabled(),
            keyliIsActive: NSRunningApplication.current.isActive,
            hasTarget: FocusManager.shared.isTargetValid
        )

        switch plan {
        case .refuse(let issue):
            state.dispatchIssue = issue
            if issue == .missingPermission {
                PermissionsManager.shared.startPollingForPermissions()
            }
            return issue

        case .activateTargetThenSend:
            guard let target = FocusManager.shared.targetApplication else {
                state.dispatchIssue = .noTarget
                return .noTarget
            }
            target.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                guard target.isActive, !target.isTerminated else {
                    state.dispatchIssue = .noTarget
                    return
                }
                self?.perform(action, state: state)
            }
            return nil

        case .send:
            perform(action, state: state)
            return nil
        }
    }

    private func perform(_ action: KeyDispatchAction, state: KeyboardState) {
        if state.dispatchIssue != nil {
            state.dispatchIssue = nil
        }
        SoundService.shared.playKeyClick()

        switch action {
        case .text(let text, let keyCode):
            typeText(text, keyCode: keyCode, state: state)
        case .keyCode(let keyCode):
            sendKeycode(keyCode, state: state)
        case .system(let systemAction):
            performSystemAction(systemAction)
        case .none, .toggleModifier:
            break
        }

        handlePostTypingModifiers(state: state)
    }

    /// Injects Unicode text into the target application
    public func typeText(_ text: String, keyCode: UInt16 = 0, state: KeyboardState) {
        guard !text.isEmpty, PermissionsManager.canTypeNow else { return }

        let characters = Array(text.utf16)
        let flags = currentEventFlags(from: state)

        postKeyPair(keyCode: keyCode, flags: flags) { event in
            characters.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress {
                    event.keyboardSetUnicodeString(
                        stringLength: buffer.count,
                        unicodeString: base
                    )
                }
            }
        }
    }

    /// Sends a virtual keycode event (e.g. Return, Backspace, Arrows, Tab, Esc)
    public func sendKeycode(_ keyCode: UInt16, state: KeyboardState) {
        guard PermissionsManager.canTypeNow else { return }
        postKeyPair(keyCode: keyCode, flags: currentEventFlags(from: state), configure: nil)
    }

    private func postKeyPair(keyCode: UInt16, flags: CGEventFlags, configure: ((CGEvent) -> Void)?) {
        func makeEvent(keyDown: Bool) -> CGEvent? {
            guard let event = CGEvent(
                keyboardEventSource: nil,
                virtualKey: keyCode,
                keyDown: keyDown
            ) else {
                return nil
            }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: KeyliConstants.syntheticEventUserData)
            configure?(event)
            return event
        }

        makeEvent(keyDown: true)?.post(tap: .cghidEventTap)

        let delayMs = max(0, ConfigStore.shared.config.syntheticTypingDelayMs)
        guard let keyUp = makeEvent(keyDown: false) else { return }
        if delayMs == 0 {
            keyUp.post(tap: .cghidEventTap)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    private func performSystemAction(_ action: KeySystemAction) {
        switch action {
        case .brightnessUp: postMediaKey(2)
        case .brightnessDown: postMediaKey(3)
        case .volumeUp: postMediaKey(0)
        case .volumeDown: postMediaKey(1)
        case .mute: postMediaKey(7)
        case .playPause: postMediaKey(16)
        case .nextTrack: postMediaKey(17)
        case .previousTrack: postMediaKey(18)
        case .missionControl:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
        case .spotlight:
            postKeyPair(keyCode: 49, flags: .maskCommand, configure: nil)
        case .lockScreen:
            postKeyPair(keyCode: 12, flags: [.maskCommand, .maskControl], configure: nil)
        }
    }

    private func postMediaKey(_ keyType: Int) {
        for isDown in [true, false] {
            let stateBits = isDown ? 0xA : 0xB
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(stateBits << 8)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: (keyType << 16) | (stateBits << 8),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    private func currentEventFlags(from state: KeyboardState) -> CGEventFlags {
        var flags: CGEventFlags = []
        if state.isShiftActive { flags.insert(.maskShift) }
        if state.isOptionActive { flags.insert(.maskAlternate) }
        if state.isControlActive { flags.insert(.maskControl) }
        if state.isCommandActive { flags.insert(.maskCommand) }
        if state.isCapsLockActive { flags.insert(.maskAlphaShift) }
        return flags
    }

    private func handlePostTypingModifiers(state: KeyboardState) {
        // In sticky modifier mode, reset temporary modifiers (Shift, Option) after character dispatch
        if ConfigStore.shared.config.modifierStickyMode {
            if state.isShiftActive { state.isShiftActive = false }
            if state.isOptionActive { state.isOptionActive = false }
            if state.isControlActive { state.isControlActive = false }
            if state.isCommandActive { state.isCommandActive = false }
            if state.isFnActive { state.isFnActive = false }
        }
    }
}
