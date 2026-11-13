import Foundation
import CoreGraphics

public enum PhysicalKeyMap {
    public static let systemDefinedEventType: UInt32 = 14
    public static let auxControlButtonsSubtype: Int16 = 8

    public static let aliases: [UInt16: UInt16] = [
        62: 59,
        160: 99,
        130: 118,
        131: 118,
        177: 118,
        176: 96,
        178: 97,
        115: 123,
        119: 124,
        116: 126,
        121: 125,
        117: 51,
        76: 36,
        82: 29,
        83: 18,
        84: 19,
        85: 20,
        86: 21,
        87: 23,
        88: 22,
        89: 26,
        91: 28,
        92: 25,
        65: 47,
        78: 27,
        81: 24,
        69: 24,
        67: 28,
        75: 44,
        179: 63
    ]

    public static let mediaKeyCodes: [Int: UInt16] = [
        3: 122,
        2: 120,
        22: 96,
        21: 97,
        18: 98,
        20: 98,
        16: 100,
        17: 101,
        19: 101,
        7: 109,
        1: 103,
        0: 111
    ]

    public static func displayKeyCode(for keyCode: UInt16, availableKeyCodes: Set<UInt16>) -> UInt16? {
        if availableKeyCodes.contains(keyCode) {
            return keyCode
        }
        if let alias = aliases[keyCode], availableKeyCodes.contains(alias) {
            return alias
        }
        return nil
    }

    public static func mediaKeyCode(forData1 data1: Int) -> (keyCode: UInt16, isDown: Bool)? {
        let keyType = (data1 & 0xFFFF0000) >> 16
        let keyState = (data1 & 0xFF00) >> 8
        guard let keyCode = mediaKeyCodes[keyType] else { return nil }
        switch keyState {
        case 0x0A: return (keyCode, true)
        case 0x0B: return (keyCode, false)
        default: return nil
        }
    }

    private static let leftControl: UInt64 = 0x0000_0001
    private static let leftShift: UInt64 = 0x0000_0002
    private static let rightShift: UInt64 = 0x0000_0004
    private static let leftCommand: UInt64 = 0x0000_0008
    private static let rightCommand: UInt64 = 0x0000_0010
    private static let leftOption: UInt64 = 0x0000_0020
    private static let rightOption: UInt64 = 0x0000_0040
    private static let rightControl: UInt64 = 0x0000_2000

    public static func isModifierDown(keyCode: UInt16, flags: CGEventFlags) -> Bool? {
        let raw = flags.rawValue
        func side(_ own: UInt64, _ other: UInt64, _ generic: CGEventFlags) -> Bool {
            if raw & (own | other) != 0 {
                return raw & own != 0
            }
            return flags.contains(generic)
        }
        switch keyCode {
        case 56: return side(leftShift, rightShift, .maskShift)
        case 60: return side(rightShift, leftShift, .maskShift)
        case 59: return side(leftControl, rightControl, .maskControl)
        case 62: return side(rightControl, leftControl, .maskControl)
        case 58: return side(leftOption, rightOption, .maskAlternate)
        case 61: return side(rightOption, leftOption, .maskAlternate)
        case 55: return side(leftCommand, rightCommand, .maskCommand)
        case 54: return side(rightCommand, leftCommand, .maskCommand)
        case 57: return flags.contains(.maskAlphaShift)
        case 63: return flags.contains(.maskSecondaryFn)
        default: return nil
        }
    }
}
