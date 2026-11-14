import Foundation
import CoreGraphics
import AppKit

public final class PhysicalKeyboardMonitor: ObservableObject {
    public static let shared = PhysicalKeyboardMonitor()

    @Published public private(set) var isRunning: Bool = false

    public var hasVisibleKeyboard: Bool = false {
        didSet {
            if oldValue != hasVisibleKeyboard {
                refresh()
            }
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    public func refresh() {
        let oldIsRunningForRefresh = isRunning
        let shouldRun = ConfigStore.shared.config.isPhysicalMonitoringEnabled
            && hasVisibleKeyboard

        if shouldRun {
            start()
        } else {
            stop()
        }
        if oldIsRunningForRefresh != isRunning {
            DispatchQueue.main.async {
                PermissionsManager.shared.checkPermissions()
            }
        }
    }

    public func start() {
        guard !isRunning else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << PhysicalKeyMap.systemDefinedEventType)

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let eventCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<PhysicalKeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()

            // Automatically re-enable tap if disabled by system timeout or user input
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                monitor.clearPressedKeys()
                return Unmanaged.passUnretained(event)
            }

            monitor.handleCGEvent(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventCallback,
            userInfo: selfPointer
        )

        guard let tap = tap else { return }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.isRunning = true
    }

    public func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }

        self.eventTap = nil
        self.runLoopSource = nil
        self.isRunning = false
        clearPressedKeys()
    }

    public func clearPressedKeys() {
        if !KeyboardState.shared.pressedPhysicalKeyCodes.isEmpty {
            KeyboardState.shared.pressedPhysicalKeyCodes.removeAll()
        }
    }

    func handleCGEvent(type: CGEventType, event: CGEvent, state: KeyboardState = .shared) {
        if event.getIntegerValueField(.eventSourceUserData) == KeyliConstants.syntheticEventUserData {
            return
        }

        let available = state.availableKeyCodes

        if type.rawValue == PhysicalKeyMap.systemDefinedEventType {
            guard let nsEvent = NSEvent(cgEvent: event),
                  nsEvent.subtype.rawValue == PhysicalKeyMap.auxControlButtonsSubtype,
                  let media = PhysicalKeyMap.mediaKeyCode(forData1: nsEvent.data1),
                  available.contains(media.keyCode) else {
                return
            }
            setPressed(media.keyCode, media.isDown, state: state)
            return
        }

        let rawKeyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .keyDown, .keyUp:
            guard let keyCode = PhysicalKeyMap.displayKeyCode(for: rawKeyCode, availableKeyCodes: available) else { return }
            setPressed(keyCode, type == .keyDown, state: state)
        case .flagsChanged:
            let flags = event.flags
            state.setModifiers(
                shift: flags.contains(.maskShift),
                option: flags.contains(.maskAlternate),
                control: flags.contains(.maskControl),
                command: flags.contains(.maskCommand),
                capsLock: flags.contains(.maskAlphaShift)
            )
            guard let isDown = PhysicalKeyMap.isModifierDown(keyCode: rawKeyCode, flags: flags),
                  let keyCode = PhysicalKeyMap.displayKeyCode(for: rawKeyCode, availableKeyCodes: available) else { return }
            setPressed(keyCode, isDown, state: state)
        default:
            break
        }
    }

    private func setPressed(_ keyCode: UInt16, _ isDown: Bool, state: KeyboardState) {
        let contains = state.pressedPhysicalKeyCodes.contains(keyCode)
        if isDown && !contains {
            state.pressedPhysicalKeyCodes.insert(keyCode)
        } else if !isDown && contains {
            state.pressedPhysicalKeyCodes.remove(keyCode)
        }
    }
}
