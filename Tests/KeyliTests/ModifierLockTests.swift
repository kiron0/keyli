import Testing
import Foundation
@testable import Keyli

@Suite("Modifier locking")
struct ModifierLockTests {
    private let interval: TimeInterval = 0.5

    private func next(_ current: ModifierLevel, _ press: ModifierPress, at now: TimeInterval, last: ModifierPressRecord?, oneShot: Bool = true) -> ModifierLevel {
        ModifierLatch.next(current: current, press: press, now: now, last: last, doubleClickInterval: interval, oneShot: oneShot)
    }

    @Test func clicksFollowPhoneRules() {
        #expect(next(.off, .click, at: 10, last: nil) == .once)
        let first = ModifierPressRecord(at: 10, from: .off, to: .once)
        #expect(next(.once, .click, at: 10.3, last: first) == .locked)
        #expect(next(.once, .click, at: 11.5, last: first) == .off)
        #expect(next(.locked, .click, at: 20, last: ModifierPressRecord(at: 12, from: .once, to: .locked)) == .off)
        let release = ModifierPressRecord(at: 20, from: .locked, to: .off)
        #expect(next(.off, .click, at: 20.2, last: release) == .off)
        #expect(next(.off, .click, at: 21, last: release) == .once)
    }

    @Test func assistivePressesNeedNoTiming() {
        let first = ModifierPressRecord(at: 0, from: .off, to: .once)
        #expect(next(.off, .sequence, at: 0, last: nil) == .once)
        #expect(next(.once, .sequence, at: 60, last: first) == .locked)
        #expect(next(.locked, .sequence, at: 120, last: nil) == .off)
    }

    @Test func withoutOneShotEveryClickToggles() {
        #expect(next(.off, .click, at: 0, last: nil, oneShot: false) == .locked)
        #expect(next(.locked, .click, at: 0.1, last: nil, oneShot: false) == .off)
    }

    @Test func doubleClickLocksAndTypingKeepsIt() {
        let state = KeyboardState()
        #expect(state.pressModifier(.shift, press: .click, now: 1, doubleClickInterval: interval, oneShot: true) == .once)
        #expect(state.pressModifier(.shift, press: .click, now: 1.2, doubleClickInterval: interval, oneShot: true) == .locked)
        #expect(state.isShiftActive)
        #expect(state.lockedModifiers == [.shift])
        #expect(state.modifierSnapshot.locked == [.shift])
        state.pressModifier(.command, press: .click, now: 2, doubleClickInterval: interval, oneShot: true)
        state.isFnActive = true
        state.releaseOneShotModifiers()
        #expect(state.isShiftActive)
        #expect(!state.isCommandActive)
        #expect(!state.isFnActive)
        #expect(state.pressModifier(.shift, press: .click, now: 5, doubleClickInterval: interval, oneShot: true) == .off)
        #expect(!state.isShiftActive)
        #expect(state.lockedModifiers.isEmpty)
    }

    @Test func holdLocksAndPhysicalKeysDoNotUnlock() {
        let state = KeyboardState()
        state.pressModifier(.option, press: .click, now: 1, doubleClickInterval: interval, oneShot: true)
        state.lockModifier(.option, now: 1.5)
        #expect(state.level(of: .option) == .locked)
        state.setModifiers(shift: false, option: false, control: false, command: false, capsLock: false)
        #expect(state.isOptionActive)
        #expect(state.detachedCopy().lockedModifiers == [.option])
        state.releaseAllModifiers()
        #expect(!state.isOptionActive)
        #expect(state.lockedModifiers.isEmpty)
    }

    @Test func capsLockAndFnStayToggles() {
        let state = KeyboardState()
        #expect(state.pressModifier(.capsLock, press: .click, now: 0, doubleClickInterval: interval, oneShot: true) == .once)
        #expect(state.isCapsLockActive)
        state.lockModifier(.fn)
        #expect(state.lockedModifiers.isEmpty)
        state.toggleModifier(.capsLock)
        #expect(!state.isCapsLockActive)
    }

    @Test func togglingOffClearsALock() {
        let state = KeyboardState()
        state.lockModifier(.control)
        state.toggleModifier(.control)
        #expect(!state.isControlActive)
        #expect(state.lockedModifiers.isEmpty)
    }
}
