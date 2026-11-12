import Foundation
import CoreGraphics
import AppKit
import Carbon

public enum KeyDispatchIssue: Equatable {
    case missingPermission
    case secureInput
    case noTarget
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

    public func currentIssue() -> KeyDispatchIssue? {
        if NSRunningApplication.current.isActive {
            return .noTarget
        }
        if !PermissionsManager.canTypeNow {
            return .missingPermission
        }
        if IsSecureEventInputEnabled() {
            return .secureInput
        }
        if !FocusManager.shared.isTargetValid {
            return .noTarget
        }
        return nil
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

        if let issue = currentIssue() {
            state.dispatchIssue = issue
            if issue == .missingPermission {
                PermissionsManager.shared.startPollingForPermissions()
            }
            return issue
        }

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
        return nil
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
