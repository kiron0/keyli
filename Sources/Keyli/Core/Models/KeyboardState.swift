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
    public var locked: Set<ModifierType>

    public init(shift: Bool = false, option: Bool = false, control: Bool = false, command: Bool = false, capsLock: Bool = false, fn: Bool = false, locked: Set<ModifierType> = []) {
        self.shift = shift
        self.option = option
        self.control = control
        self.command = command
        self.capsLock = capsLock
        self.fn = fn
        self.locked = locked
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
    @Published public private(set) var lockedModifiers: Set<ModifierType> = []
    private var pressRecords: [ModifierType: ModifierPressRecord] = [:]

    public let presses = KeyPressState()

    public var pressedPhysicalKeyCodes: Set<UInt16> {
        get { presses.physicalKeyCodes }
        set { presses.physicalKeyCodes = newValue }
    }

    public var virtualPressedKeyId: String? {
        get { presses.virtualKeyId }
        set { presses.virtualKeyId = newValue }
    }

    @Published public var targetAppName: String = "No Target Selected"
    @Published public var targetAppBundleId: String = ""
    @Published public var targetAppIcon: NSImage? = nil

    @Published public var dispatchIssue: KeyDispatchIssue? = nil

    @Published public var currentLayout: KeyboardLayout {
        didSet {
            availableKeyCodes = Set(currentLayout.keys.map { $0.keyCode })
        }
    }
    @Published public var currentTheme: KeyboardTheme

    public private(set) var availableKeyCodes: Set<UInt16> = []

    public init() {
        self.currentTheme = .defaultTheme
        self.currentLayout = KeyboardLayout(
            id: "ansi_default",
            name: "US ANSI",
            geometryType: .ansi,
            unitWidth: 14.5,
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
            fn: isFnActive,
            locked: lockedModifiers
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
        copy.lockedModifiers = lockedModifiers
        copy.currentLayout = currentLayout
        return copy
    }

    public func setModifiers(shift: Bool, option: Bool, control: Bool, command: Bool, capsLock: Bool) {
        let shift = shift || lockedModifiers.contains(.shift)
        let option = option || lockedModifiers.contains(.option)
        let control = control || lockedModifiers.contains(.control)
        let command = command || lockedModifiers.contains(.command)
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
        if !lockedModifiers.isEmpty { lockedModifiers.removeAll() }
        pressRecords.removeAll()
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
        if !isActive(type), lockedModifiers.contains(type) {
            lockedModifiers.remove(type)
        }
    }

    public func isActive(_ type: ModifierType) -> Bool {
        switch type {
        case .shift: return isShiftActive
        case .option: return isOptionActive
        case .control: return isControlActive
        case .command: return isCommandActive
        case .capsLock: return isCapsLockActive
        case .fn: return isFnActive
        }
    }

    private func setActive(_ type: ModifierType, _ on: Bool) {
        switch type {
        case .shift: if isShiftActive != on { isShiftActive = on }
        case .option: if isOptionActive != on { isOptionActive = on }
        case .control: if isControlActive != on { isControlActive = on }
        case .command: if isCommandActive != on { isCommandActive = on }
        case .capsLock: if isCapsLockActive != on { isCapsLockActive = on }
        case .fn: if isFnActive != on { isFnActive = on }
        }
    }

    public func level(of type: ModifierType) -> ModifierLevel {
        if lockedModifiers.contains(type) { return .locked }
        return isActive(type) ? .once : .off
    }

    private func apply(_ level: ModifierLevel, to type: ModifierType) {
        setActive(type, level != .off)
        if level == .locked {
            if !lockedModifiers.contains(type) { lockedModifiers.insert(type) }
        } else if lockedModifiers.contains(type) {
            lockedModifiers.remove(type)
        }
    }

    @discardableResult
    public func pressModifier(
        _ type: ModifierType,
        press: ModifierPress,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime,
        doubleClickInterval: TimeInterval = NSEvent.doubleClickInterval,
        oneShot: Bool? = nil
    ) -> ModifierLevel {
        guard ModifierLatch.isLockable(type) else {
            toggleModifier(type)
            return level(of: type)
        }
        let current = level(of: type)
        let next = ModifierLatch.next(
            current: current,
            press: press,
            now: now,
            last: pressRecords[type],
            doubleClickInterval: doubleClickInterval,
            oneShot: oneShot ?? ConfigStore.shared.config.modifierStickyMode
        )
        apply(next, to: type)
        pressRecords[type] = ModifierPressRecord(at: now, from: current, to: next)
        return next
    }

    public func lockModifier(_ type: ModifierType, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard ModifierLatch.isLockable(type) else { return }
        let current = level(of: type)
        apply(.locked, to: type)
        pressRecords[type] = ModifierPressRecord(at: now, from: current, to: .locked)
    }

    public func releaseOneShotModifiers() {
        for type in ModifierLatch.lockable where !lockedModifiers.contains(type) {
            setActive(type, false)
        }
        if isFnActive { isFnActive = false }
    }

    public func releaseAllModifiers() {
        if !lockedModifiers.isEmpty { lockedModifiers.removeAll() }
        for type in ModifierLatch.lockable {
            setActive(type, false)
        }
        if isFnActive { isFnActive = false }
        pressRecords.removeAll()
    }

    public func isKeyCurrentlyPressed(keyCode: UInt16, keyId: String) -> Bool {
        if virtualPressedKeyId == keyId {
            return true
        }
        return pressedPhysicalKeyCodes.contains(keyCode)
    }
}
