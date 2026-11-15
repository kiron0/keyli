import AppKit

public final class WordSuggestions: ObservableObject {
    public static let shared = WordSuggestions()

    @Published public private(set) var currentWord = ""
    @Published public private(set) var suggestions: [String] = []

    public static let resetKeyCodes: Set<UInt16> = [36, 76, 48, 53, 123, 124, 125, 126, 115, 119, 116, 121, 117]

    public static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’"
    }

    public func didType(_ text: String) {
        guard ConfigStore.shared.config.wordSuggestionsEnabled else { return }
        var word = currentWord
        for character in text {
            if Self.isWordCharacter(character) {
                word.append(character)
            } else {
                word = ""
            }
        }
        update(word)
    }

    public func didPressKey(_ keyCode: UInt16) {
        guard ConfigStore.shared.config.wordSuggestionsEnabled else { return }
        if keyCode == 51 {
            update(String(currentWord.dropLast()))
        } else if Self.resetKeyCodes.contains(keyCode) {
            update("")
        }
    }

    public func reset() {
        if !currentWord.isEmpty || !suggestions.isEmpty {
            update("")
        }
    }

    private func update(_ word: String) {
        currentWord = word
        let next = word.count >= 2 ? Self.completions(for: word) : []
        if next != suggestions {
            suggestions = next
        }
    }

    public static func systemCandidates(for word: String) -> [String] {
        let range = NSRange(location: 0, length: (word as NSString).length)
        return NSSpellChecker.shared.completions(forPartialWordRange: range, in: word, language: nil, inSpellDocumentWithTag: 0) ?? []
    }

    public static func completions(
        for word: String,
        limit: Int = 3,
        candidates: (String) -> [String] = WordSuggestions.systemCandidates(for:)
    ) -> [String] {
        let raw = candidates(word)
        var seen = Set<String>()
        var result: [String] = []
        for candidate in raw where candidate.lowercased() != word.lowercased() {
            let shaped = matchCase(candidate, to: word)
            if seen.insert(shaped.lowercased()).inserted {
                result.append(shaped)
            }
            if result.count == limit { break }
        }
        return result
    }

    public static func matchCase(_ candidate: String, to typed: String) -> String {
        guard let first = typed.first else { return candidate }
        if typed.count > 1, typed == typed.uppercased(), typed != typed.lowercased() {
            return candidate.uppercased()
        }
        if first.isUppercase {
            return candidate.prefix(1).uppercased() + candidate.dropFirst()
        }
        return candidate
    }

    public static func insertion(for suggestion: String, typed: String) -> (deleteCount: Int, text: String) {
        if suggestion.lowercased().hasPrefix(typed.lowercased()), suggestion.hasPrefix(typed) {
            return (0, String(suggestion.dropFirst(typed.count)) + " ")
        }
        return (typed.count, suggestion + " ")
    }

    public func accept(_ suggestion: String) {
        let plan = Self.insertion(for: suggestion, typed: currentWord)
        let dispatcher = KeyboardInputDispatcher.shared
        let plain = KeyboardState()
        for _ in 0..<plan.deleteCount {
            dispatcher.sendKeycode(51, state: plain)
        }
        dispatcher.typeText(plan.text, state: plain)
        KeySoundEngine.shared.tap(49)
        update("")
    }
}
