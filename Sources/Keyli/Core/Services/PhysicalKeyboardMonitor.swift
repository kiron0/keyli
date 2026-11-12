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
        let shouldRun = ConfigStore.shared.config.isPhysicalMonitoringEnabled
            && hasVisibleKeyboard

        if shouldRun {
            start()
        } else {
            stop()
        }
    }

    public func start() {
        guard !isRunning else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

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

    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        if event.getIntegerValueField(.eventSourceUserData) == KeyliConstants.syntheticEventUserData {
            return
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let state = KeyboardState.shared

        switch type {
        case .keyDown:
            if !state.pressedPhysicalKeyCodes.contains(keyCode) {
                state.pressedPhysicalKeyCodes.insert(keyCode)
            }
        case .keyUp:
            state.pressedPhysicalKeyCodes.remove(keyCode)
        case .flagsChanged:
            let flags = event.flags
            state.isShiftActive = flags.contains(.maskShift)
            state.isOptionActive = flags.contains(.maskAlternate)
            state.isControlActive = flags.contains(.maskControl)
            state.isCommandActive = flags.contains(.maskCommand)
            state.isCapsLockActive = flags.contains(.maskAlphaShift)

            let isModDown: Bool
            switch keyCode {
            case 56, 60: isModDown = flags.contains(.maskShift)
            case 58, 61: isModDown = flags.contains(.maskAlternate)
            case 55, 54: isModDown = flags.contains(.maskCommand)
            case 59, 62: isModDown = flags.contains(.maskControl)
            case 57:     isModDown = flags.contains(.maskAlphaShift)
            case 63:     isModDown = flags.contains(.maskSecondaryFn)
            default:     isModDown = false
            }

            if isModDown {
                state.pressedPhysicalKeyCodes.insert(keyCode)
            } else {
                state.pressedPhysicalKeyCodes.remove(keyCode)
            }
        default:
            break
        }
    }
}
