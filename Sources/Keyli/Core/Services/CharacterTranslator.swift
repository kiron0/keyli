import Foundation
import Carbon

public final class CharacterTranslator {
    public static let shared = CharacterTranslator()

    private static let inputSourceLock = NSRecursiveLock()
    private var cachedLayoutData: Data?
    public private(set) var activeInputSourceName: String = "US"
    public private(set) var activeInputSourceID: String = ""

    private init() {
        refreshInputSource()
    }

    public func refreshInputSource() {
        Self.inputSourceLock.lock()
        defer { Self.inputSourceLock.unlock() }
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()

        if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            self.activeInputSourceName = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        } else {
            self.activeInputSourceName = "Standard"
        }

        if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            self.activeInputSourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        } else {
            self.activeInputSourceID = ""
        }

        if let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            self.cachedLayoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        } else {
            self.cachedLayoutData = nil
        }
    }

    public func translateKeycode(_ keyCode: UInt16) -> KeyLabels {
        Self.inputSourceLock.lock()
        defer { Self.inputSourceLock.unlock() }
        guard let data = cachedLayoutData else {
            return fallbackLabels(for: keyCode)
        }

        return data.withUnsafeBytes { buffer -> KeyLabels in
            guard let header = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return fallbackLabels(for: keyCode)
            }

            let def = translate(header: header, keyCode: keyCode, modifier: 0)
            let shiftMod = UInt32((shiftKey >> 8) & 0xFF)
            let shift = translate(header: header, keyCode: keyCode, modifier: shiftMod)
            let optMod = UInt32((optionKey >> 8) & 0xFF)
            let opt = translate(header: header, keyCode: keyCode, modifier: optMod)
            let shiftOptMod = UInt32(((shiftKey | optionKey) >> 8) & 0xFF)
            let shiftOpt = translate(header: header, keyCode: keyCode, modifier: shiftOptMod)

            return KeyLabels(
                defaultLabel: def.isEmpty ? fallbackLabel(for: keyCode) : def,
                shiftLabel: shift.isEmpty ? nil : shift,
                optionLabel: opt.isEmpty ? nil : opt,
                shiftOptionLabel: shiftOpt.isEmpty ? nil : shiftOpt
            )
        }
    }

    private func translate(header: UnsafePointer<UCKeyboardLayout>, keyCode: UInt16, modifier: UInt32) -> String {
        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            header,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            modifier,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            4,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return "" }
        return String(utf16CodeUnits: chars, count: length)
    }

    private func fallbackLabels(for keyCode: UInt16) -> KeyLabels {
        let def = fallbackLabel(for: keyCode)
        return KeyLabels(defaultLabel: def)
    }

    private func fallbackLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "o"
        case 32: return "u"
        case 33: return "["
        case 34: return "i"
        case 35: return "p"
        case 37: return "l"
        case 38: return "j"
        case 39: return "'"
        case 40: return "k"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "n"
        case 46: return "m"
        case 47: return "."
        case 50: return "`"
        case 10: return "§"
        case 93: return "¥"
        case 94: return "_"
        default: return ""
        }
    }
}
