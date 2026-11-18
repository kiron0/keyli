import Foundation
import IOKit.hid
import Carbon
import QuartzCore

public final class SecureInputKeySoundFallback {
    public static let shared = SecureInputKeySoundFallback(defaults: .standard)

    public private(set) var isRunning = false

    private struct PressKey: Hashable {
        var device: String
        var usage: UInt32
    }

    private struct PendingHID {
        var device: String
        var usage: UInt32
        var time: CFTimeInterval
    }

    private struct PendingTap {
        var keyCode: UInt16
        var time: CFTimeInterval
    }

    private var manager: IOHIDManager?
    private var pressed: Set<PressKey> = []
    private var sounded: [PressKey: UInt16] = [:]
    private var learned: [String: [UInt32: UInt16]] = [:]
    private var pendingHID: [PendingHID] = []
    private var pendingTaps: [PendingTap] = []
    private let defaults: UserDefaults?

    var isSecureInputActive: () -> Bool = { IsSecureEventInputEnabled() }
    var isISOKeyboard: () -> Bool = { KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardISO }
    var now: () -> CFTimeInterval = { CACurrentMediaTime() }

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        learned = Self.decode(defaults?.dictionary(forKey: Self.learnedKey))
    }

    static let learnedKey = "keyli.secureInputFallback.learnedKeyCodes"
    static let keyboardUsagePage: UInt32 = 0x07
    static let typingUsages: ClosedRange<UInt32> = 0x04...0xDF
    static let lockingUsages: Set<UInt32> = [0x39, 0x82, 0x83, 0x84]
    static let unknownKeyCode: UInt16 = 999
    static let matchWindow: CFTimeInterval = 0.04

    static let usageToKeyCode: [UInt32: UInt16] = [
        0x04: 0, 0x05: 11, 0x06: 8, 0x07: 2, 0x08: 14, 0x09: 3, 0x0A: 5, 0x0B: 4,
        0x0C: 34, 0x0D: 38, 0x0E: 40, 0x0F: 37, 0x10: 46, 0x11: 45, 0x12: 31, 0x13: 35,
        0x14: 12, 0x15: 15, 0x16: 1, 0x17: 17, 0x18: 32, 0x19: 9, 0x1A: 13, 0x1B: 7,
        0x1C: 16, 0x1D: 6,
        0x1E: 18, 0x1F: 19, 0x20: 20, 0x21: 21, 0x22: 23, 0x23: 22, 0x24: 26, 0x25: 28,
        0x26: 25, 0x27: 29,
        0x28: 36, 0x29: 53, 0x2A: 51, 0x2B: 48, 0x2C: 49, 0x2D: 27, 0x2E: 24, 0x2F: 33,
        0x30: 30, 0x31: 42, 0x32: 42, 0x33: 41, 0x34: 39, 0x35: 50, 0x36: 43, 0x37: 47,
        0x38: 44,
        0x3A: 122, 0x3B: 120, 0x3C: 99, 0x3D: 118, 0x3E: 96, 0x3F: 97, 0x40: 98, 0x41: 100,
        0x42: 101, 0x43: 109, 0x44: 103, 0x45: 111,
        0x46: 105, 0x47: 107, 0x48: 113,
        0x49: 114, 0x4A: 115, 0x4B: 116, 0x4C: 117, 0x4D: 119, 0x4E: 121,
        0x4F: 124, 0x50: 123, 0x51: 125, 0x52: 126,
        0x53: 71, 0x54: 75, 0x55: 67, 0x56: 78, 0x57: 69, 0x58: 76,
        0x59: 83, 0x5A: 84, 0x5B: 85, 0x5C: 86, 0x5D: 87, 0x5E: 88, 0x5F: 89, 0x60: 91,
        0x61: 92, 0x62: 82, 0x63: 65, 0x64: 10, 0x67: 81,
        0x68: 105, 0x69: 107, 0x6A: 113, 0x6B: 106, 0x6C: 64, 0x6D: 79, 0x6E: 80, 0x6F: 90,
        0x85: 95, 0x87: 94, 0x89: 93, 0x90: 104, 0x91: 102
    ]

    static func defaultKeyCode(usage: UInt32, iso: Bool) -> UInt16? {
        if iso {
            if usage == 0x35 { return 10 }
            if usage == 0x64 { return 50 }
        }
        return usageToKeyCode[usage]
    }

    public enum Output: Equatable {
        case down(UInt16)
        case up(UInt16)
    }

    static func isTypingUsage(page: UInt32, usage: UInt32) -> Bool {
        page == keyboardUsagePage && typingUsages.contains(usage) && !lockingUsages.contains(usage)
    }

    func keyCode(device: String, usage: UInt32) -> UInt16 {
        learned[device]?[usage]
            ?? Self.defaultKeyCode(usage: usage, iso: isISOKeyboard())
            ?? Self.unknownKeyCode
    }

    func learnedKeyCode(device: String, usage: UInt32) -> UInt16? {
        learned[device]?[usage]
    }

    func handle(device: String = "", usagePage: UInt32, usage: UInt32, pressed isDown: Bool) -> Output? {
        guard Self.isTypingUsage(page: usagePage, usage: usage) else { return nil }
        let key = PressKey(device: device, usage: usage)
        if isDown {
            guard pressed.insert(key).inserted else { return nil }
            if isSecureInputActive() {
                let code = keyCode(device: device, usage: usage)
                sounded[key] = code
                return .down(code)
            }
            pendingHID.append(PendingHID(device: device, usage: usage, time: now()))
            matchPending()
            return nil
        }
        guard pressed.remove(key) != nil, let code = sounded.removeValue(forKey: key) else { return nil }
        return .up(code)
    }

    func noteTapKeyDown(_ keyCode: UInt16) {
        guard !Self.reservedTapKeyCodes.contains(keyCode) else { return }
        pendingTaps.append(PendingTap(keyCode: keyCode, time: now()))
        matchPending()
    }

    static let reservedTapKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private func matchPending() {
        let cutoff = now() - Self.matchWindow
        pendingHID.removeAll { $0.time < cutoff }
        pendingTaps.removeAll { $0.time < cutoff }
        guard pendingHID.count == 1, pendingTaps.count == 1 else {
            if pendingHID.count > 1 || pendingTaps.count > 1 {
                pendingHID.removeAll()
                pendingTaps.removeAll()
            }
            return
        }
        let hid = pendingHID[0]
        let tap = pendingTaps[0]
        pendingHID.removeAll()
        pendingTaps.removeAll()
        guard learned[hid.device]?[hid.usage] != tap.keyCode else { return }
        learned[hid.device, default: [:]][hid.usage] = tap.keyCode
        defaults?.set(Self.encode(learned), forKey: Self.learnedKey)
    }

    static func encode(_ map: [String: [UInt32: UInt16]]) -> [String: [String: Int]] {
        map.mapValues { inner in
            Dictionary(uniqueKeysWithValues: inner.map { (String($0.key), Int($0.value)) })
        }
    }

    static func decode(_ raw: [String: Any]?) -> [String: [UInt32: UInt16]] {
        guard let raw else { return [:] }
        var result: [String: [UInt32: UInt16]] = [:]
        for (device, value) in raw {
            guard let inner = value as? [String: Int] else { continue }
            var map: [UInt32: UInt16] = [:]
            for (usage, code) in inner {
                guard let usage = UInt32(usage), (0..<Int(unknownKeyCode)).contains(code) else { continue }
                map[usage] = UInt16(code)
            }
            if !map.isEmpty { result[device] = map }
        }
        return result
    }

    func reset() {
        pressed.removeAll()
        sounded.removeAll()
        pendingHID.removeAll()
        pendingTaps.removeAll()
    }

    static func deviceKey(_ device: IOHIDDevice) -> String {
        let vendor = (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int) ?? 0
        let product = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int) ?? 0
        let transport = (IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String) ?? ""
        return "\(vendor):\(product):\(transport)"
    }

    public func start() {
        guard !isRunning else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Any]] = [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            let fallback = Unmanaged<SecureInputKeySoundFallback>.fromOpaque(context).takeUnretainedValue()
            let element = IOHIDValueGetElement(value)
            let device = SecureInputKeySoundFallback.deviceKey(IOHIDElementGetDevice(element))
            let output = fallback.handle(
                device: device,
                usagePage: IOHIDElementGetUsagePage(element),
                usage: IOHIDElementGetUsage(element),
                pressed: IOHIDValueGetIntegerValue(value) != 0
            )
            switch output {
            case .down(let keyCode):
                KeySoundEngine.shared.keyDown(keyCode, source: .physical)
            case .up(let keyCode):
                KeySoundEngine.shared.keyUp(keyCode, source: .physical)
            case nil:
                break
            }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            return
        }
        self.manager = manager
        isRunning = true
    }

    public func stop() {
        guard isRunning, let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        isRunning = false
        reset()
    }
}
