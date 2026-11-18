import Testing
import Foundation
@testable import Keyli

@Suite("Key remapping")
struct KeyRemapTests {
    private func ansi(remaps: [KeyRemap], snippets: [Snippet] = []) -> KeyboardLayout {
        KeyboardLayoutManager.shared.generateLayout(geometry: .ansi, numericKeypad: false, remaps: remaps, snippets: snippets)
    }

    private func key(_ layout: KeyboardLayout, _ id: String) -> KeyboardKey? {
        layout.keys.first { $0.id == id }
    }

    @Test func dvorakMovesLettersAndKeepsShortcutsOnTheirLetters() throws {
        let layout = ansi(remaps: RemapPreset.dvorak.remaps)
        let e = try #require(key(layout, "k_14"))
        #expect(e.labels.defaultLabel == ".")
        #expect(e.labels.shiftLabel == ">")
        #expect(e.kind == .character)
        let p = try #require(key(layout, "k_15"))
        #expect(p.labels.defaultLabel == "p")
        #expect(p.shortcutKeyCode == 35)
        #expect(key(layout, "k_0")?.labels.defaultLabel == "a")
    }

    @Test func modifiersCannotBeRemapped() {
        let layout = ansi(remaps: [KeyRemap(keyId: "k_lshift", action: .text("x", shifted: nil))])
        #expect(layout.keys.first { $0.id == "k_lshift" }?.remap == nil)
    }

    @Test func remapsDecideWhatAKeySends() {
        var mapped = KeyboardKey(id: "k_0", keyCode: 0, unitFrame: KeyUnitFrame(x: 0, y: 0), labels: KeyLabels(defaultLabel: "a"))
        mapped.shortcutKeyCode = 9
        let plain = KeyboardState()
        #expect(KeyboardInputDispatcher.remapAction(.text("é", shifted: nil), key: mapped, state: plain) == .text("é", keyCode: 0))
        let shifted = KeyboardState()
        shifted.isShiftActive = true
        #expect(KeyboardInputDispatcher.remapAction(.text("é", shifted: nil), key: mapped, state: shifted) == .text("É", keyCode: 0))
        #expect(KeyboardInputDispatcher.remapAction(.text("1", shifted: "€"), key: mapped, state: shifted) == .text("€", keyCode: 0))
        let caps = KeyboardState()
        caps.isCapsLockActive = true
        #expect(KeyboardInputDispatcher.remapAction(.text("q", shifted: nil), key: mapped, state: caps) == .text("Q", keyCode: 0))
        let command = KeyboardState()
        command.isCommandActive = true
        #expect(KeyboardInputDispatcher.remapAction(.text("v", shifted: nil), key: mapped, state: command) == .keyCode(9))
        #expect(KeyboardInputDispatcher.remapAction(.key(53), key: mapped, state: plain) == .keyCode(53))
        #expect(KeyboardInputDispatcher.remapAction(.shortcut(["⌘", "T"]), key: mapped, state: plain) == .shortcut(["⌘", "T"]))
        #expect(KeyboardInputDispatcher.remapAction(.shortcut([]), key: mapped, state: plain) == KeyDispatchAction.none)
        #expect(KeyboardInputDispatcher.remapAction(.snippet("abc"), key: mapped, state: plain) == .snippet("abc"))
        #expect(KeyboardInputDispatcher.remapAction(.disabled, key: mapped, state: plain) == KeyDispatchAction.none)
    }

    @Test func dispatcherUsesTheRemap() throws {
        let layout = ansi(remaps: [KeyRemap(keyId: "k_122", action: .shortcut(["⌘", "⇧", "T"]))])
        let f1 = try #require(key(layout, "k_122"))
        #expect(f1.systemAction == nil)
        #expect(f1.labels.defaultLabel == "⌘⇧T")
        #expect(KeyboardInputDispatcher.shared.action(for: f1, state: KeyboardState()) == .shortcut(["⌘", "⇧", "T"]))
        #expect(KeyboardInputDispatcher.needsTargetApp(.shortcut(["⌘", "T"])))
    }

    @Test func labelsDescribeTheAction() {
        let snippets = [Snippet(id: "s1", title: "Sign-off", kind: .text, text: "Best")]
        #expect(KeyRemapper.label(for: KeyRemap(keyId: "k", action: .key(115)), snippets: []) == "home")
        #expect(KeyRemapper.label(for: KeyRemap(keyId: "k", action: .snippet("s1")), snippets: snippets) == "Sign-off")
        #expect(KeyRemapper.label(for: KeyRemap(keyId: "k", action: .disabled, label: "off"), snippets: []) == "off")
    }

    @Test func presetsSwapCleanlyAndKeepOtherRemaps() {
        let custom = KeyRemap(keyId: "k_space", action: .text("_", shifted: nil))
        var remaps = KeyRemapper.applying(.dvorak, to: [custom])
        #expect(KeyRemapper.activePreset(in: remaps) == .dvorak)
        remaps = KeyRemapper.applying(.colemak, to: remaps)
        #expect(KeyRemapper.activePreset(in: remaps) == .colemak)
        #expect(!remaps.contains { $0.keyId == "k_12" })
        #expect(remaps.contains(custom))
        remaps = KeyRemapper.removingPresets(from: remaps)
        #expect(remaps == [custom])
    }

    @Test func remapsSurviveEncoding() throws {
        let remaps = [
            KeyRemap(keyId: "a", action: .text("é", shifted: "É"), label: "e acute"),
            KeyRemap(keyId: "b", action: .key(53)),
            KeyRemap(keyId: "c", action: .shortcut(["⌘", "K"])),
            KeyRemap(keyId: "d", action: .snippet("x")),
            KeyRemap(keyId: "e", action: .disabled)
        ]
        let decoded = try JSONDecoder().decode([KeyRemap].self, from: JSONEncoder().encode(remaps))
        #expect(decoded == remaps)
        #expect(!RemapAction.shortcut([]).repeats)
        #expect(RemapAction.text("a", shifted: nil).repeats)
    }
}

@Suite("Remap settings defaults")
struct RemapSettingsDefaultsTests {
    @Test func newSettingsHaveSafeDefaults() throws {
        let decoded = try JSONDecoder().decode(KeyliConfig.self, from: Data("{}".utf8))
        #expect(decoded.keyRemaps.isEmpty)
        #expect(SettingsTab.remap.category == .keyboard)
    }

    @Test func oldConfigsWithScanningSettingsStillDecode() throws {
        let old = #"{"scanningEnabled": true, "scanInterval": 2.0, "scanSelectByClick": false}"#
        let decoded = try JSONDecoder().decode(KeyliConfig.self, from: Data(old.utf8))
        #expect(decoded.keyRemaps.isEmpty)
        #expect(!ShortcutAction.allCases.map(\.rawValue).contains("scanSelect"))
    }
}
