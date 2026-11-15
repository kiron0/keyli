import Testing
import Foundation
@testable import Keyli

@Suite("Word Suggestions", .serialized)
struct WordSuggestionTests {
    @Test func completesCommonWords() {
        let results = WordSuggestions.completions(for: "Keyb") { _ in
            ["keyb", "keyboard", "Keyboard", "keyboards", "keyboarding", "keyboardist"]
        }
        #expect(results == ["Keyboard", "Keyboards", "Keyboarding"])
    }

    @Test func systemCompletionsKeepInvariants() {
        let results = WordSuggestions.completions(for: "keyb")
        #expect(results.count <= 3)
        #expect(!results.contains { $0.lowercased() == "keyb" })
        #expect(Set(results.map { $0.lowercased() }).count == results.count)
    }

    @Test func matchesTypedCase() {
        #expect(WordSuggestions.matchCase("keyboard", to: "Key") == "Keyboard")
        #expect(WordSuggestions.matchCase("keyboard", to: "KEY") == "KEYBOARD")
        #expect(WordSuggestions.matchCase("keyboard", to: "key") == "keyboard")
    }

    @Test func insertsOnlyTheMissingPart() {
        #expect(WordSuggestions.insertion(for: "Keyboard", typed: "Key") == (0, "board "))
        #expect(WordSuggestions.insertion(for: "their", typed: "thier") == (5, "their "))
    }

    @Test @MainActor func tracksTheWordBeingTyped() {
        let store = ConfigStore.shared
        let saved = store.config
        defer { store.config = saved; WordSuggestions.shared.reset() }
        store.config.wordSuggestionsEnabled = true
        let words = WordSuggestions.shared
        words.reset()
        words.didType("h"); words.didType("e"); words.didType("l")
        #expect(words.currentWord == "hel")
        #expect(!words.suggestions.isEmpty)
        words.didPressKey(51)
        #expect(words.currentWord == "he")
        words.didType(" ")
        #expect(words.currentWord.isEmpty)
        #expect(words.suggestions.isEmpty)
        words.didType("don'")
        #expect(words.currentWord == "don'")
        words.didPressKey(36)
        #expect(words.currentWord.isEmpty)
        store.config.wordSuggestionsEnabled = false
        words.didType("abc")
        #expect(words.currentWord.isEmpty)
    }

    @Test @MainActor func suggestionsNeverChangeKeyboardHeight() {
        let store = ConfigStore.shared
        let saved = store.config
        defer { store.config = saved }
        store.config.wordSuggestionsEnabled = true
        store.config.snippetBarEnabled = true
        store.config.snippets = [Snippet(title: "Hi", kind: .text, text: "Hello")]
        #expect(KeyliConstants.keyboardChromeHeight == KeyliConstants.baseChromeHeight)
    }
}
