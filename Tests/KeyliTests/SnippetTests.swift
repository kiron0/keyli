import Testing
import Foundation
@testable import Keyli

@Suite("Snippet Keys")
struct SnippetTests {
    @Test func shortcutSnippetsMapToModifiers() throws {
        let state = try #require(SnippetRunner.modifierState(for: ["⌘", "⇧", "T"]))
        #expect(state.isCommandActive && state.isShiftActive)
        #expect(!state.isOptionActive && !state.isControlActive)
        #expect(SnippetRunner.modifierState(for: ["⌘"]) == nil)
        #expect(ShortcutManager.keysToCarbon(keys: ["⌘", "⇧", "T"])?.keyCode == 17)
    }

    @Test func snippetsPersistInConfig() throws {
        var config = KeyliConfig()
        config.snippetBarEnabled = true
        config.snippets = [Snippet(title: "Sig", kind: .text, text: "Best, Kiron"), Snippet(title: "Tab", kind: .shortcut, keys: ["⌘", "⇧", "T"])]
        let decoded = try JSONDecoder().decode(KeyliConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded.snippets == config.snippets)
        #expect(decoded.snippetBarEnabled)
        #expect(try JSONDecoder().decode(KeyliConfig.self, from: Data("{}".utf8)).snippets.isEmpty)
    }
}

@Suite("Snippets Window")
struct SnippetsWindowTests {
    @Test func searchMatchesTitleTextAndKeys() {
        let snippets = [Snippet(title: "Signature", kind: .text, text: "Best, Kiron"), Snippet(title: "Reopen", kind: .shortcut, keys: ["⌘", "⇧", "T"])]
        #expect(SnippetFilter.matching(snippets, query: "").count == 2)
        #expect(SnippetFilter.matching(snippets, query: "kiron").map(\.title) == ["Signature"])
        #expect(SnippetFilter.matching(snippets, query: "⌘").map(\.title) == ["Reopen"])
        #expect(SnippetFilter.matching(snippets, query: "zzz").isEmpty)
    }

    @Test func opensBesideTheKeyboardOnScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1600, height: 1000)
        let right = SnippetsPanelController.initialFrame(keyboard: NSRect(x: 100, y: 200, width: 700, height: 300), screen: screen)
        #expect(right.minX == 812 && right.maxY == 500)
        let left = SnippetsPanelController.initialFrame(keyboard: NSRect(x: 900, y: 200, width: 690, height: 300), screen: screen)
        #expect(left.maxX == 888)
        #expect(SnippetsPanelController.initialFrame(keyboard: nil, screen: screen).midX == 800)
    }
}
