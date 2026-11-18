import Testing
import Foundation
import Carbon
@testable import Keyli

@Suite("Key Sounds During Secure Input")
struct SecureInputSoundTests {
    @Test("HID usages map to the same virtual key codes the event tap reports")
    func usageMapping() {
        let map = SecureInputKeySoundFallback.usageToKeyCode
        #expect(map[0x04] == UInt16(kVK_ANSI_A))
        #expect(map[0x1D] == UInt16(kVK_ANSI_Z))
        #expect(map[0x1E] == UInt16(kVK_ANSI_1))
        #expect(map[0x27] == UInt16(kVK_ANSI_0))
        #expect(map[0x28] == UInt16(kVK_Return))
        #expect(map[0x2A] == UInt16(kVK_Delete))
        #expect(map[0x2C] == UInt16(kVK_Space))
        #expect(map[0x35] == UInt16(kVK_ANSI_Grave))
        #expect(map[0x3A] == UInt16(kVK_F1))
        #expect(map[0x45] == UInt16(kVK_F12))
        #expect(map[0x50] == UInt16(kVK_LeftArrow))
        #expect(map[0x58] == UInt16(kVK_ANSI_KeypadEnter))
        #expect(map[0x64] == UInt16(kVK_ISO_Section))
        #expect(map[0xE1] == nil)
        #expect(map[0x39] == nil)
    }

    @Test("Fallback stays silent while secure input is off")
    func silentWithoutSecureInput() {
        let fallback = SecureInputKeySoundFallback()
        fallback.isSecureInputActive = { false }
        #expect(fallback.handle(usagePage: 0x07, usage: 0x04, pressed: true) == nil)
        #expect(fallback.handle(usagePage: 0x07, usage: 0x04, pressed: false) == nil)
    }

    @Test("Fallback plays down and up while secure input is on")
    func playsWithSecureInput() {
        let fallback = SecureInputKeySoundFallback()
        fallback.isSecureInputActive = { true }
        #expect(fallback.handle(usagePage: 0x07, usage: 0x04, pressed: true) == .down(0))
        #expect(fallback.handle(usagePage: 0x07, usage: 0x04, pressed: true) == nil)
        #expect(fallback.handle(usagePage: 0x07, usage: 0x04, pressed: false) == .up(0))
        #expect(fallback.handle(usagePage: 0x07, usage: 0x04, pressed: false) == nil)
    }

    @Test("Release is skipped for a key pressed before secure input turned on")
    func releaseAfterTransition() {
        let fallback = SecureInputKeySoundFallback()
        var secure = false
        fallback.isSecureInputActive = { secure }
        #expect(fallback.handle(usagePage: 0x07, usage: 0x05, pressed: true) == nil)
        secure = true
        #expect(fallback.handle(usagePage: 0x07, usage: 0x05, pressed: false) == nil)
        #expect(fallback.handle(usagePage: 0x07, usage: 0x05, pressed: true) == .down(11))
    }

    @Test("Other usage pages and unmapped usages are ignored")
    func ignoresOtherUsages() {
        let fallback = SecureInputKeySoundFallback()
        fallback.isSecureInputActive = { true }
        #expect(fallback.handle(usagePage: 0x0C, usage: 0xE9, pressed: true) == nil)
        #expect(fallback.handle(usagePage: 0x07, usage: 0xE0, pressed: true) == nil)
        #expect(fallback.handle(usagePage: 0x07, usage: 0x01, pressed: true) == nil)
    }

    @Test("ISO keyboards swap the section and grave keys")
    func isoSwap() {
        let fallback = SecureInputKeySoundFallback()
        fallback.isSecureInputActive = { true }
        fallback.isISOKeyboard = { true }
        #expect(fallback.handle(usagePage: 0x07, usage: 0x35, pressed: true) == .down(UInt16(kVK_ISO_Section)))
        #expect(fallback.handle(usagePage: 0x07, usage: 0x64, pressed: true) == .down(UInt16(kVK_ANSI_Grave)))
        fallback.isISOKeyboard = { false }
        #expect(fallback.keyCode(device: "", usage: 0x35) == UInt16(kVK_ANSI_Grave))
        #expect(fallback.keyCode(device: "", usage: 0x64) == UInt16(kVK_ISO_Section))
    }

    @Test("Keys missing from the table still click with the default sound")
    func unknownKeysStillClick() {
        let fallback = SecureInputKeySoundFallback()
        fallback.isSecureInputActive = { true }
        let unknown = SecureInputKeySoundFallback.unknownKeyCode
        #expect(fallback.handle(usagePage: 0x07, usage: 0x70, pressed: true) == .down(unknown))
        #expect(fallback.handle(usagePage: 0x07, usage: 0x70, pressed: false) == .up(unknown))
        #expect(unknown < 1000)
    }

    @Test("Locking keys and modifiers are left to flagsChanged")
    func lockingKeysIgnored() {
        let fallback = SecureInputKeySoundFallback()
        fallback.isSecureInputActive = { true }
        #expect(fallback.handle(usagePage: 0x07, usage: 0x39, pressed: true) == nil)
        #expect(fallback.handle(usagePage: 0x07, usage: 0xE3, pressed: true) == nil)
    }

    @Test("Normal typing teaches each keyboard its real key codes")
    func learnsFromTap() {
        let fallback = SecureInputKeySoundFallback()
        var clock: CFTimeInterval = 100
        fallback.now = { clock }
        fallback.isSecureInputActive = { false }
        fallback.isISOKeyboard = { false }
        _ = fallback.handle(device: "kb1", usagePage: 0x07, usage: 0x35, pressed: true)
        clock += 0.005
        fallback.noteTapKeyDown(UInt16(kVK_ISO_Section))
        #expect(fallback.learnedKeyCode(device: "kb1", usage: 0x35) == UInt16(kVK_ISO_Section))
        #expect(fallback.learnedKeyCode(device: "kb2", usage: 0x35) == nil)
        _ = fallback.handle(device: "kb1", usagePage: 0x07, usage: 0x35, pressed: false)
        fallback.isSecureInputActive = { true }
        #expect(fallback.handle(device: "kb1", usagePage: 0x07, usage: 0x35, pressed: true) == .down(UInt16(kVK_ISO_Section)))
        #expect(fallback.handle(device: "kb2", usagePage: 0x07, usage: 0x35, pressed: true) == .down(UInt16(kVK_ANSI_Grave)))
    }

    @Test("Tap key down that arrives first is matched too")
    func learnsWhenTapFirst() {
        let fallback = SecureInputKeySoundFallback()
        var clock: CFTimeInterval = 50
        fallback.now = { clock }
        fallback.isSecureInputActive = { false }
        fallback.noteTapKeyDown(77)
        clock += 0.01
        _ = fallback.handle(device: "kb", usagePage: 0x07, usage: 0x70, pressed: true)
        #expect(fallback.learnedKeyCode(device: "kb", usage: 0x70) == 77)
    }

    @Test("Overlapping or late presses are not learned")
    func ambiguousNotLearned() {
        let fallback = SecureInputKeySoundFallback()
        var clock: CFTimeInterval = 10
        fallback.now = { clock }
        fallback.isSecureInputActive = { false }
        _ = fallback.handle(device: "kb", usagePage: 0x07, usage: 0x04, pressed: true)
        _ = fallback.handle(device: "kb", usagePage: 0x07, usage: 0x05, pressed: true)
        fallback.noteTapKeyDown(0)
        #expect(fallback.learnedKeyCode(device: "kb", usage: 0x04) == nil)
        #expect(fallback.learnedKeyCode(device: "kb", usage: 0x05) == nil)
        clock += 1
        _ = fallback.handle(device: "kb", usagePage: 0x07, usage: 0x06, pressed: true)
        clock += 0.5
        fallback.noteTapKeyDown(8)
        #expect(fallback.learnedKeyCode(device: "kb", usage: 0x06) == nil)
    }

    @Test("Learned key codes survive a restart")
    func learnedPersisted() throws {
        let suite = "keyli.tests.secureInput.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = SecureInputKeySoundFallback(defaults: defaults)
        first.now = { 1 }
        first.isSecureInputActive = { false }
        _ = first.handle(device: "kb", usagePage: 0x07, usage: 0x64, pressed: true)
        first.noteTapKeyDown(50)
        let second = SecureInputKeySoundFallback(defaults: defaults)
        #expect(second.learnedKeyCode(device: "kb", usage: 0x64) == 50)
        #expect(SecureInputKeySoundFallback.decode(["kb": ["4": 5000, "x": 1]]).isEmpty)
    }

    @Test("Second key down for the same key right after the first is a duplicate")
    func duplicateDownWindow() {
        #expect(KeySoundEngine.isDuplicateDown(wasHeld: true, lastDown: 10.0, now: 10.01))
        #expect(!KeySoundEngine.isDuplicateDown(wasHeld: true, lastDown: 10.0, now: 10.5))
        #expect(!KeySoundEngine.isDuplicateDown(wasHeld: false, lastDown: 10.0, now: 10.01))
        #expect(!KeySoundEngine.isDuplicateDown(wasHeld: true, lastDown: nil, now: 10.01))
    }
}
