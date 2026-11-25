import Testing
import Foundation
import AppKit
import Carbon
@testable import Keyli

@Suite("Physical Keyboard Lock", .serialized)
struct PhysicalKeyboardLockTests {
    @Test func filterDropsPhysicalTypingAndAuxMediaWhilePassingSyntheticAndOtherSystemEvents() {
        var filter = PhysicalKeyboardLockService.FilterState()

        #expect(filter.decision(
            type: .keyDown, userData: 0, keyCode: 0, flags: [], isAutorepeat: false,
            systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .drop)

        #expect(filter.decision(
            type: .keyUp, userData: 0, keyCode: 0, flags: [], isAutorepeat: false,
            systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .drop)

        #expect(filter.decision(
            type: .flagsChanged, userData: 0, keyCode: 56, flags: .maskShift, isAutorepeat: false,
            systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .drop)

        #expect(filter.decision(
            type: CGEventType(rawValue: PhysicalKeyMap.systemDefinedEventType)!,
            userData: 0, keyCode: 0, flags: [], isAutorepeat: false,
            systemDefinedSubtype: PhysicalKeyMap.auxControlButtonsSubtype, unlockShortcut: nil
        ) == .drop)

        #expect(filter.decision(
            type: CGEventType(rawValue: PhysicalKeyMap.systemDefinedEventType)!,
            userData: 0, keyCode: 0, flags: [], isAutorepeat: false,
            systemDefinedSubtype: 7, unlockShortcut: nil
        ) == .passThrough)

        #expect(filter.decision(
            type: .keyDown, userData: KeyliConstants.syntheticEventUserData, keyCode: 0, flags: [],
            isAutorepeat: false, systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .passThrough)

        #expect(filter.decision(
            type: CGEventType(rawValue: PhysicalKeyMap.systemDefinedEventType)!,
            userData: KeyliConstants.syntheticEventUserData, keyCode: 0, flags: [],
            isAutorepeat: false, systemDefinedSubtype: PhysicalKeyMap.auxControlButtonsSubtype, unlockShortcut: nil
        ) == .passThrough)
    }

    @Test func filterLetsPreLockKeysAndModifiersReleaseOnceWithoutLeakingNewPresses() {
        var filter = PhysicalKeyboardLockService.FilterState(
            pendingReleaseKeyCodes: [37],
            pendingModifierFlags: [.maskControl, .maskAlternate, .maskAlphaShift]
        )

        #expect(filter.decision(
            type: .keyUp, userData: 0, keyCode: 37, flags: [], isAutorepeat: false,
            systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .passThrough)
        #expect(filter.decision(
            type: .keyUp, userData: 0, keyCode: 37, flags: [], isAutorepeat: false,
            systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .drop)

        #expect(filter.decision(
            type: .flagsChanged, userData: 0, keyCode: 58, flags: [.maskControl, .maskShift],
            isAutorepeat: false, systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .drop)

        #expect(filter.decision(
            type: .flagsChanged, userData: 0, keyCode: 58, flags: .maskControl,
            isAutorepeat: false, systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .passThrough)

        #expect(filter.decision(
            type: .flagsChanged, userData: 0, keyCode: 59, flags: [],
            isAutorepeat: false, systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .passThrough)

        // Caps Lock (alphaShift) was stripped from tracked pre-lock flags, so pressing/toggling it is blocked.
        #expect(filter.decision(
            type: .flagsChanged, userData: 0, keyCode: 57, flags: .maskAlphaShift,
            isAutorepeat: false, systemDefinedSubtype: nil, unlockShortcut: nil
        ) == .drop)
    }

    @Test func filterRecognizesUnlockShortcutOnNonRepeatKeyDownOnly() {
        var filter = PhysicalKeyboardLockService.FilterState()
        let shortcut = ShortcutManager.keysToCarbon(keys: ["^", "⌥", "L"])!
        let flags: CGEventFlags = [.maskControl, .maskAlternate]

        #expect(filter.decision(
            type: .keyDown, userData: 0, keyCode: UInt16(shortcut.keyCode), flags: flags,
            isAutorepeat: true, systemDefinedSubtype: nil, unlockShortcut: shortcut
        ) == .drop)

        #expect(filter.decision(
            type: .keyDown, userData: 0, keyCode: UInt16(shortcut.keyCode), flags: [.maskControl],
            isAutorepeat: false, systemDefinedSubtype: nil, unlockShortcut: shortcut
        ) == .drop)

        #expect(filter.decision(
            type: .keyDown, userData: 0, keyCode: UInt16(shortcut.keyCode), flags: flags,
            isAutorepeat: false, systemDefinedSubtype: nil, unlockShortcut: shortcut
        ) == .unlockAndDrop)
    }

    @Test func serviceLifecycleHandlesLockUnlockFailureAndRearm() {
        var enabled = false
        var invalidated = 0
        var lockStartCount = 0
        var deniedCount = 0
        var shouldFailCreate = false
        var shouldFailEnable = false

        let service = PhysicalKeyboardLockService(
            observeWake: false,
            createTap: { _ in
                if shouldFailCreate { return nil }
                return PhysicalKeyboardLockService.TapHandle(
                    enable: { enabled = shouldFailEnable ? false : $0 },
                    invalidate: { invalidated += 1 },
                    isEnabled: { enabled }
                )
            },
            onLockStart: { lockStartCount += 1 },
            onPermissionDenied: { deniedCount += 1 }
        )

        shouldFailCreate = true
        service.toggleWithPermissionCheck()
        #expect(!service.isLocked)
        #expect(deniedCount == 1)

        shouldFailCreate = false
        shouldFailEnable = true
        #expect(!service.lock())
        #expect(!service.isLocked)
        #expect(invalidated == 1)

        shouldFailEnable = false
        #expect(service.lock())
        #expect(service.isLocked)
        #expect(enabled)
        #expect(lockStartCount == 1)

        service.rearm()
        #expect(service.isLocked)
        #expect(invalidated == 2)
        #expect(lockStartCount == 2)

        shouldFailCreate = true
        service.rearm()
        #expect(!service.isLocked)
        #expect(invalidated == 3)

        shouldFailCreate = false
        #expect(service.lock())
        service.unlock()
        #expect(!service.isLocked)
        #expect(!enabled)
        #expect(invalidated == 4)
    }

    @Test @MainActor func serviceTapCallbackUnlocksOnConfiguredShortcut() async throws {
        var tapHandler: ((CGEventType, CGEvent) -> Unmanaged<CGEvent>?)?
        var enabled = false
        var invalidated = 0
        let shortcut = ShortcutManager.keysToCarbon(keys: ["^", "⌥", "L"])!

        let service = PhysicalKeyboardLockService(
            observeWake: false,
            createTap: { handler in
                tapHandler = handler
                return PhysicalKeyboardLockService.TapHandle(
                    enable: { enabled = $0 },
                    invalidate: { invalidated += 1 },
                    isEnabled: { enabled }
                )
            },
            unlockShortcutProvider: { shortcut }
        )

        #expect(service.lock())
        #expect(service.isLocked)
        let handler = try #require(tapHandler)

        let normalKey = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        #expect(handler(.keyDown, normalKey) == nil)
        #expect(service.isLocked)

        let unlockKey = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(shortcut.keyCode), keyDown: true)!
        unlockKey.flags = [.maskControl, .maskAlternate]
        #expect(handler(.keyDown, unlockKey) == nil)
        #expect(!enabled)

        try await Task.sleep(for: .milliseconds(50))
        #expect(!service.isLocked)
        #expect(invalidated == 1)
    }

    @Test func menuItemAndShortcutIntegrationMatchLockState() {
        let suite = "keyli.lock.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let manager = ShortcutManager(defaults: defaults, registers: false)
        #expect(manager.setKeys(["^", "⌥", "L"], for: .togglePhysicalKeyboardLock))

        let unlocked = StatusItemController.physicalLockMenuItem(isLocked: false, manager: manager)
        #expect(unlocked.title == "Lock Physical Keyboard")
        #expect(unlocked.keyEquivalent == "l")
        #expect(unlocked.keyEquivalentModifierMask == [.control, .option])

        let locked = StatusItemController.physicalLockMenuItem(isLocked: true, manager: manager)
        #expect(locked.title == "Unlock Physical Keyboard")
        #expect(locked.keyEquivalent == "l")
        #expect(locked.keyEquivalentModifierMask == [.control, .option])

        let shortcutItems = StatusItemController.shortcutMenuItems(
            excluding: StatusItemController.actionsShownElsewhere,
            manager: manager,
            config: KeyliConfig()
        )
        #expect(!shortcutItems.contains { $0.title == ShortcutAction.togglePhysicalKeyboardLock.title })

        #expect(StatusItemController.shouldShowStatusItem(showInConfig: false, isPhysicalLocked: true))
        #expect(!StatusItemController.shouldShowStatusItem(showInConfig: false, isPhysicalLocked: false))
    }
}
