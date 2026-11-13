import Foundation
import AppKit
import Combine

public struct KeyModifierSnapshot: Equatable {
    public var shift: Bool
    public var option: Bool
    public var control: Bool
    public var command: Bool
    public var capsLock: Bool
    public var fn: Bool

    public init(shift: Bool = false, option: Bool = false, control: Bool = false, command: Bool = false, capsLock: Bool = false, fn: Bool = false) {
        self.shift = shift
        self.option = option
        self.control = control
        self.command = command
        self.capsLock = capsLock
        self.fn = fn
    }
}

public final class KeyPressState: ObservableObject {
    @Published public var physicalKeyCodes: Set<UInt16> = []
    @Published public var virtualKeyId: String? = nil

    public init() {}
}

public final class KeyboardState: ObservableObject {
    public static let shared = KeyboardState()

    @Published public var isShiftActive: Bool = false
    @Published public var isOptionActive: Bool = false
    @Published public var isControlActive: Bool = false
    @Published public var isCommandActive: Bool = false
    @Published public var isCapsLockActive: Bool = false
    @Published public var isFnActive: Bool = false

    public let presses = KeyPressState()

    /// Keycodes currently physically pressed down (from PhysicalKeyboardMonitor)
    public var pressedPhysicalKeyCodes: Set<UInt16> {
        get { presses.physicalKeyCodes }
        set { presses.physicalKeyCodes = newValue }
    }

    /// Virtual keycap ID currently depressed via mouse/pointer click
    public var virtualPressedKeyId: String? {
        get { presses.virtualKeyId }
        set { presses.virtualKeyId = newValue }
    }

    /// Target application information
    @Published public var targetAppName: String = "No Target Selected"
    @Published public var targetAppBundleId: String = ""
    @Published public var targetAppIcon: NSImage? = nil

    @Published public var dispatchIssue: KeyDispatchIssue? = nil

    /// Active layout and theme
    @Published public var currentLayout: KeyboardLayout
    @Published public var currentTheme: KeyboardTheme

    public init() {
        self.currentTheme = .defaultTheme
        self.currentLayout = KeyboardLayout(
            id: "ansi_default",
            name: "US ANSI",
            geometryType: .ansi,
            unitWidth: 15.0,
            unitHeight: 6.0,
            keys: []
        )
    }

    public var modifierSnapshot: KeyModifierSnapshot {
        KeyModifierSnapshot(
            shift: isShiftActive,
            option: isOptionActive,
            control: isControlActive,
            command: isCommandActive,
            capsLock: isCapsLockActive,
            fn: isFnActive
        )
    }

    public func detachedCopy() -> KeyboardState {
        let copy = KeyboardState()
        copy.isShiftActive = isShiftActive
        copy.isOptionActive = isOptionActive
        copy.isControlActive = isControlActive
        copy.isCommandActive = isCommandActive
        copy.isCapsLockActive = isCapsLockActive
        copy.isFnActive = isFnActive
        copy.currentLayout = currentLayout
        return copy
    }

    public func setModifiers(shift: Bool, option: Bool, control: Bool, command: Bool, capsLock: Bool) {
        if isShiftActive != shift { isShiftActive = shift }
        if isOptionActive != option { isOptionActive = option }
        if isControlActive != control { isControlActive = control }
        if isCommandActive != command { isCommandActive = command }
        if isCapsLockActive != capsLock { isCapsLockActive = capsLock }
    }

    public func resetModifiers() {
        isShiftActive = false
        isOptionActive = false
        isControlActive = false
        isCommandActive = false
        isFnActive = false
    }

    public func toggleModifier(_ type: ModifierType) {
        switch type {
        case .shift:
            isShiftActive.toggle()
        case .option:
            isOptionActive.toggle()
        case .control:
            isControlActive.toggle()
        case .command:
            isCommandActive.toggle()
        case .capsLock:
            isCapsLockActive.toggle()
        case .fn:
            isFnActive.toggle()
        }
    }

    public func isKeyCurrentlyPressed(keyCode: UInt16, keyId: String) -> Bool {
        if virtualPressedKeyId == keyId {
            return true
        }
        return pressedPhysicalKeyCodes.contains(keyCode)
    }
}
