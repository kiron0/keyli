import Testing
import Foundation
import AppKit
import Carbon
@testable import Keyli

@Suite("Global Shortcuts")
struct ShortcutTests {
    func freshManager() -> (ShortcutManager, UserDefaults) {
        let suite = "keyli.shortcuts.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (ShortcutManager(defaults: defaults, registers: false), defaults)
    }

    @Test func defaultsShowKeyboardShortcut() {
        let (manager, _) = freshManager()
        #expect(manager.binding(for: .toggleKeyboard) == ShortcutBinding(isEnabled: true, keys: ["^", "⌥", "K"]))
        #expect(manager.binding(for: .openSettings) == ShortcutBinding(isEnabled: false, keys: []))
    }

    @Test func recordsPersistsAndRejectsConflicts() {
        let (manager, defaults) = freshManager()
        #expect(manager.setKeys(["⌘", "⇧", "F5"], for: .openSettings))
        #expect(manager.binding(for: .openSettings).isEnabled)
        #expect(!manager.setKeys(["⌘", "⇧", "F5"], for: .nextTheme))
        #expect(manager.shortcutError != nil)

        let reloaded = ShortcutManager(defaults: defaults, registers: false)
        #expect(reloaded.binding(for: .openSettings).keys == ["⌘", "⇧", "F5"])

        manager.setKeys([], for: .openSettings)
        #expect(manager.binding(for: .openSettings).keys.isEmpty)
        manager.resetToDefaults()
        #expect(manager.bindings == ShortcutManager.defaultBindings)
    }

    @Test func requiresModifierExceptFunctionKeys() {
        #expect(ShortcutManager.validate(["K"]) != nil)
        #expect(ShortcutManager.validate(["⇧", "K"]) != nil)
        #expect(ShortcutManager.validate(["F13"]) == nil)
        #expect(ShortcutManager.validate(["^", "←"]) == nil)
        #expect(ShortcutManager.validate(["⌘", "Ω"]) != nil)
    }

    @Test func convertsEventsToCarbon() {
        let keys = ShortcutManager.keys(keyCode: 40, flags: [.control, .option])
        #expect(keys == ["^", "⌥", "K"])
        let parsed = ShortcutManager.keysToCarbon(keys: keys)
        #expect(parsed?.keyCode == 40)
        #expect(parsed?.modifiers == UInt32(controlKey | optionKey))
        #expect(ShortcutManager.keys(keyCode: 999, flags: []).isEmpty)
    }

    @Test func everyActionHasUniqueHotKeyId() {
        let ids = ShortcutAction.allCases.map(\.hotKeyId)
        #expect(Set(ids).count == ids.count)
    }

    @Test func recognizesEmojiMenuItemShortcutInAnyLanguage() {
        #expect(InputSourceService.isEmojiMenuShortcut(character: "E", modifiers: 24))
        #expect(InputSourceService.isEmojiMenuShortcut(character: " ", modifiers: 4))
        #expect(!InputSourceService.isEmojiMenuShortcut(character: "E", modifiers: 0))
        #expect(!InputSourceService.isEmojiMenuShortcut(character: "🎤", modifiers: 8))
        #expect(!InputSourceService.isEmojiMenuShortcut(character: " ", modifiers: 12))
    }

    @Test func positionLockDefaultsOffAndDecodesFromOlderConfigs() throws {
        #expect(KeyliConfig().isFloatingPositionLocked == false)
        let old = try JSONDecoder().decode(KeyliConfig.self, from: Data(#"{"isFloatingPinned": false}"#.utf8))
        #expect(old.isFloatingPositionLocked == false)
        #expect(old.isFloatingPinned == false)
        #expect(ShortcutAction.togglePositionLock.group == .window)
    }

    @Test func newActionsHaveGroupsTitlesAndUniqueText() {
        let added: [ShortcutAction: ShortcutAction.Group] = [
            .toggleNumericKeypad: .window,
            .previousInputSource: .typing, .clearClipboardHistory: .typing,
            .toggleWordSuggestions: .typing, .toggleStickyModifiers: .typing,
            .togglePhysicalTypingSounds: .sounds, .previousSoundPack: .sounds,
            .keySoundVolumeUp: .sounds, .keySoundVolumeDown: .sounds,
            .previousTheme: .app, .openSetupAssistant: .app,
            .openKeyboardSettings: .app, .toggleMenuBarIcon: .app
        ]
        for (action, group) in added {
            #expect(action.group == group)
        }
        let titles = ShortcutAction.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
        #expect(ShortcutAction.allCases.allSatisfy { NSImage(systemSymbolName: $0.symbol, accessibilityDescription: nil) != nil })
    }

    @Test func toggleActionsReportTheirState() {
        var config = KeyliConfig()
        config.showNumericKeypad = true
        config.showMenuBarIcon = false
        #expect(ShortcutAction.toggleNumericKeypad.isOn(config) == true)
        #expect(ShortcutAction.toggleMenuBarIcon.isOn(config) == false)
        #expect(ShortcutAction.nextTheme.isOn(config) == nil)
    }

    @Test func cyclingWrapsBothWays() {
        let items = ["a", "b", "c"]
        #expect(ShortcutManager.cycled(items, current: 2, forward: true) == "a")
        #expect(ShortcutManager.cycled(items, current: 0, forward: false) == "c")
        #expect(ShortcutManager.cycled(items, current: nil, forward: true) == "a")
        #expect(ShortcutManager.cycled(items, current: nil, forward: false) == "c")
        #expect(ShortcutManager.cycled([String](), current: nil, forward: true) == nil)
    }

    @Test func volumeStepsByTenPercentWithinRange() {
        #expect(ShortcutManager.steppedVolume(0.6, up: true) == 0.7)
        #expect(ShortcutManager.steppedVolume(0.6, up: false) == 0.5)
        #expect(ShortcutManager.steppedVolume(0.96, up: true) == 1)
        #expect(ShortcutManager.steppedVolume(0.02, up: false) == 0)
    }

    @Test func menuKeyEquivalentsMatchRecordedKeys() {
        let letter = ShortcutManager.menuKeyEquivalent(for: ["^", "⌥", "K"])
        #expect(letter?.key == "k")
        #expect(letter?.modifiers == [.control, .option])
        let function = ShortcutManager.menuKeyEquivalent(for: ["⌘", "⇧", "F5"])
        #expect(function?.key == String(Character(Unicode.Scalar(NSF5FunctionKey)!)))
        #expect(function?.modifiers == [.command, .shift])
        #expect(ShortcutManager.menuKeyEquivalent(for: ["⌘", "Space"])?.key == " ")
        #expect(ShortcutManager.menuKeyEquivalent(for: ["⌥", "←"])?.key == String(Character(Unicode.Scalar(NSLeftArrowFunctionKey)!)))
        #expect(ShortcutManager.menuKeyEquivalent(for: ["⌘"]) == nil)
    }

    @Test func menuListsOnlyEnabledShortcuts() {
        let (manager, _) = freshManager()
        #expect(manager.actionsWithShortcuts == [.toggleKeyboard])
        #expect(manager.setKeys(["^", "⌥", "N"], for: .toggleNumericKeypad))
        #expect(manager.actionsWithShortcuts.contains(.toggleNumericKeypad))
        let items = StatusItemController.shortcutMenuItems(
            excluding: StatusItemController.actionsShownElsewhere,
            manager: manager,
            config: KeyliConfig()
        )
        #expect(items.map(\.title) == [ShortcutAction.toggleNumericKeypad.title])
        #expect(items.first?.keyEquivalent == "n")
        #expect(items.first?.keyEquivalentModifierMask == [.control, .option])
        #expect(items.first?.state == .off)
        manager.setEnabled(false, for: .toggleNumericKeypad)
        #expect(!manager.actionsWithShortcuts.contains(.toggleNumericKeypad))
    }
}
