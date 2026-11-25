import AppKit
import Carbon
import CoreGraphics
import Foundation

public final class PhysicalKeyboardLockService: ObservableObject {
    public static let shared = PhysicalKeyboardLockService()

    public enum TapDecision: Equatable {
        case passThrough
        case drop
        case unlockAndDrop
    }

    public struct FilterState {
        public static let trackedModifierFlags: CGEventFlags = [
            .maskShift,
            .maskControl,
            .maskAlternate,
            .maskCommand,
            .maskSecondaryFn
        ]

        public var pendingReleaseKeyCodes: Set<UInt16>
        public var pendingModifierFlags: CGEventFlags

        public init(pendingReleaseKeyCodes: Set<UInt16> = [], pendingModifierFlags: CGEventFlags = []) {
            self.pendingReleaseKeyCodes = pendingReleaseKeyCodes
            self.pendingModifierFlags = pendingModifierFlags.intersection(Self.trackedModifierFlags)
        }

        public static func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
            var modifiers: UInt32 = 0
            if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
            if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
            if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
            if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
            return modifiers
        }

        public mutating func decision(
            type: CGEventType,
            userData: Int64,
            keyCode: UInt16,
            flags: CGEventFlags,
            isAutorepeat: Bool,
            systemDefinedSubtype: Int16?,
            unlockShortcut: (keyCode: UInt32, modifiers: UInt32)?
        ) -> TapDecision {
            if userData == KeyliConstants.syntheticEventUserData {
                return .passThrough
            }

            if type.rawValue == PhysicalKeyMap.systemDefinedEventType {
                return systemDefinedSubtype == PhysicalKeyMap.auxControlButtonsSubtype ? .drop : .passThrough
            }

            switch type {
            case .keyDown:
                if !isAutorepeat,
                   let unlockShortcut,
                   UInt32(keyCode) == unlockShortcut.keyCode,
                   Self.carbonModifiers(from: flags) == unlockShortcut.modifiers {
                    return .unlockAndDrop
                }
                return .drop

            case .keyUp:
                if pendingReleaseKeyCodes.remove(keyCode) != nil {
                    return .passThrough
                }
                return .drop

            case .flagsChanged:
                let incoming = flags.intersection(Self.trackedModifierFlags)
                if !pendingModifierFlags.isEmpty,
                   incoming.isSubset(of: pendingModifierFlags),
                   incoming != pendingModifierFlags {
                    pendingModifierFlags = incoming
                    return .passThrough
                }
                return .drop

            default:
                return .passThrough
            }
        }
    }

    struct TapHandle {
        let enable: (Bool) -> Void
        let invalidate: () -> Void
        let isEnabled: () -> Bool
    }

    typealias TapCreator = (@escaping (CGEventType, CGEvent) -> Unmanaged<CGEvent>?) -> TapHandle?
    typealias UnlockShortcutProvider = () -> (keyCode: UInt32, modifiers: UInt32)?
    typealias KeyStateReader = (UInt16) -> Bool
    typealias FlagsReader = () -> CGEventFlags
    typealias PermissionAlertHandler = () -> Void

    @Published public private(set) var isLocked: Bool = false

    private var tapHandle: TapHandle?
    private var filterState = FilterState()
    private var isUnlocking = false
    private var activeUnlockShortcut: (keyCode: UInt32, modifiers: UInt32)?
    private var lastShortcutUnlockAt: TimeInterval = -.infinity
    private var wakeObservers: [NSObjectProtocol] = []

    private let createTap: TapCreator
    private let unlockShortcutProvider: UnlockShortcutProvider
    private let keyStateReader: KeyStateReader
    private let flagsReader: FlagsReader
    private let onLockStart: () -> Void
    private let onPermissionDenied: PermissionAlertHandler

    private convenience init() {
        self.init(
            observeWake: true,
            unlockShortcutProvider: {
                let binding = ShortcutManager.shared.binding(for: .togglePhysicalKeyboardLock)
                guard binding.isEnabled else { return nil }
                return ShortcutManager.keysToCarbon(keys: binding.keys)
            },
            keyStateReader: { CGEventSource.keyState(.combinedSessionState, key: CGKeyCode($0)) },
            flagsReader: { CGEventSource.flagsState(.combinedSessionState) },
            onLockStart: {
                PhysicalKeyboardMonitor.shared.clearPressedKeys()
                KeySoundEngine.shared.releaseAll(source: .physical)
            },
            onPermissionDenied: {
                PermissionsManager.shared.checkPermissions()
                Self.presentAccessibilityAlert()
            }
        )
    }

    init(
        observeWake: Bool = false,
        createTap: TapCreator? = nil,
        unlockShortcutProvider: @escaping UnlockShortcutProvider = { nil },
        keyStateReader: @escaping KeyStateReader = { _ in false },
        flagsReader: @escaping FlagsReader = { [] },
        onLockStart: @escaping () -> Void = {},
        onPermissionDenied: @escaping PermissionAlertHandler = {}
    ) {
        self.createTap = createTap ?? Self.makeSystemTap
        self.unlockShortcutProvider = unlockShortcutProvider
        self.keyStateReader = keyStateReader
        self.flagsReader = flagsReader
        self.onLockStart = onLockStart
        self.onPermissionDenied = onPermissionDenied

        if observeWake {
            let center = NSWorkspace.shared.notificationCenter
            let names: [Notification.Name] = [
                NSWorkspace.didWakeNotification,
                NSWorkspace.screensDidWakeNotification,
                NSWorkspace.sessionDidBecomeActiveNotification
            ]
            wakeObservers = names.map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.rearm()
                }
            }
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in wakeObservers {
            center.removeObserver(observer)
        }
    }

    @discardableResult
    public func lock() -> Bool {
        guard !isLocked else { return true }
        guard installTap() else { return false }
        self.isLocked = true
        onLockStart()
        return true
    }

    private func installTap() -> Bool {
        isUnlocking = false
        activeUnlockShortcut = unlockShortcutProvider()

        let heldKeyCodes = Set((UInt16(0)..<128).filter { keyStateReader($0) })
        filterState = FilterState(
            pendingReleaseKeyCodes: heldKeyCodes,
            pendingModifierFlags: flagsReader()
        )

        guard let handle = createTap({ [weak self] type, event in
            guard let self else { return Unmanaged.passUnretained(event) }
            return self.handleTapEvent(type: type, event: event)
        }) else {
            filterState = FilterState()
            return false
        }

        handle.enable(true)
        guard handle.isEnabled() else {
            handle.invalidate()
            filterState = FilterState()
            return false
        }

        self.tapHandle = handle
        return true
    }

    public func unlock() {
        guard isLocked || tapHandle != nil else { return }
        if let handle = tapHandle {
            handle.enable(false)
            handle.invalidate()
        }
        tapHandle = nil
        isUnlocking = false
        activeUnlockShortcut = nil
        filterState = FilterState()
        if isLocked {
            isLocked = false
        }
    }

    public func toggleWithPermissionCheck() {
        if isLocked {
            unlock()
            return
        }
        if ProcessInfo.processInfo.systemUptime - lastShortcutUnlockAt < 0.5 {
            return
        }
        if !lock() {
            onPermissionDenied()
        }
    }

    public func rearm() {
        guard isLocked else { return }
        if let handle = tapHandle {
            handle.enable(false)
            handle.invalidate()
        }
        tapHandle = nil
        guard installTap() else {
            unlock()
            return
        }
        onLockStart()
    }

    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if !isUnlocking {
                tapHandle?.enable(true)
            }
            return Unmanaged.passUnretained(event)
        }

        let userData = event.getIntegerValueField(.eventSourceUserData)
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        var subtype: Int16?
        if type.rawValue == PhysicalKeyMap.systemDefinedEventType {
            subtype = autoreleasepool {
                NSEvent(cgEvent: event)?.subtype.rawValue
            }
        }

        let decision = filterState.decision(
            type: type,
            userData: userData,
            keyCode: keyCode,
            flags: event.flags,
            isAutorepeat: isAutorepeat,
            systemDefinedSubtype: subtype,
            unlockShortcut: activeUnlockShortcut
        )

        switch decision {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .drop:
            return nil
        case .unlockAndDrop:
            if !isUnlocking {
                isUnlocking = true
                lastShortcutUnlockAt = ProcessInfo.processInfo.systemUptime
                tapHandle?.enable(false)
                DispatchQueue.main.async { [weak self] in
                    self?.unlock()
                }
            }
            return nil
        }
    }

    private static func makeSystemTap(handler: @escaping (CGEventType, CGEvent) -> Unmanaged<CGEvent>?) -> TapHandle? {
        final class CallbackBox {
            let handler: (CGEventType, CGEvent) -> Unmanaged<CGEvent>?
            init(handler: @escaping (CGEventType, CGEvent) -> Unmanaged<CGEvent>?) {
                self.handler = handler
            }
        }

        let box = CallbackBox(handler: handler)
        let boxPointer = Unmanaged.passRetained(box).toOpaque()

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << PhysicalKeyMap.systemDefinedEventType)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let box = Unmanaged<CallbackBox>.fromOpaque(refcon).takeUnretainedValue()
            return box.handler(type, event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: boxPointer
        ) else {
            Unmanaged<CallbackBox>.fromOpaque(boxPointer).release()
            return nil
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            Unmanaged<CallbackBox>.fromOpaque(boxPointer).release()
            return nil
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        return TapHandle(
            enable: { CGEvent.tapEnable(tap: tap, enable: $0) },
            invalidate: {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                CFMachPortInvalidate(tap)
                Unmanaged<CallbackBox>.fromOpaque(boxPointer).release()
            },
            isEnabled: { CGEvent.tapIsEnabled(tap: tap) }
        )
    }

    private static func presentAccessibilityAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Keyli needs Accessibility access to lock your physical keyboard while keeping on-screen typing and your mouse working."
        alert.addButton(withTitle: "Open Permissions")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsWindowController.shared.showSettings(tab: .permissions)
        }
    }
}
