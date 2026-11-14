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
}
