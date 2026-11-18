import AppKit

public final class WordSuggestions: ObservableObject {
    public static let shared = WordSuggestions()

    @Published public private(set) var currentWord = ""
    @Published public private(set) var suggestions: [String] = []
    @Published public private(set) var isPredicting = false

    public private(set) var context: String?
    public var pendingSwipeSpace = false

    private let lexicon: PersonalLexicon
    private let configProvider: () -> KeyliConfig

    public static let resetKeyCodes: Set<UInt16> = [36, 76, 48, 53, 123, 124, 125, 126, 115, 119, 116, 121, 117]

    public init(lexicon: PersonalLexicon = .shared, config: @escaping () -> KeyliConfig = { ConfigStore.shared.config }) {
        self.lexicon = lexicon
        self.configProvider = config
    }

    public static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’"
    }

    private var config: KeyliConfig {
        configProvider()
    }

    private var learns: Bool {
        config.wordSuggestionsEnabled && config.learnWordsFromTyping
    }

    public func didType(_ text: String) {
        guard config.wordSuggestionsEnabled else { return }
        pendingSwipeSpace = false
        var word = currentWord
        for character in text {
            if Self.isWordCharacter(character) {
                word.append(character)
            } else {
                if !word.isEmpty {
                    commit(word)
                }
                if !character.isWhitespace {
                    context = nil
                }
                word = ""
            }
        }
        update(word)
    }

    public func didPressKey(_ keyCode: UInt16) {
        guard config.wordSuggestionsEnabled else { return }
        pendingSwipeSpace = false
        if keyCode == 51 {
            if currentWord.isEmpty {
                context = nil
            }
            update(String(currentWord.dropLast()))
        } else if Self.resetKeyCodes.contains(keyCode) {
            context = nil
            update("")
        }
    }

    public enum PhysicalInput: Equatable {
        case text(String)
        case key(UInt16)
        case reset
        case ignore
    }

    public static func classifyPhysical(keyCode: UInt16, characters: String?, command: Bool, control: Bool) -> PhysicalInput {
        if command || control {
            return .reset
        }
        if keyCode == 51 || resetKeyCodes.contains(keyCode) {
            return .key(keyCode)
        }
        guard let characters, !characters.isEmpty,
              characters.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else {
            return .ignore
        }
        return .text(characters)
    }

    public func didTypePhysically(_ input: PhysicalInput) {
        guard learns else { return }
        switch input {
        case .text(let text):
            didType(text)
        case .key(let keyCode):
            didPressKey(keyCode)
        case .reset:
            reset()
        case .ignore:
            break
        }
    }

    public func reset() {
        context = nil
        pendingSwipeSpace = false
        if !currentWord.isEmpty || !suggestions.isEmpty {
            update("")
        }
    }

    public func showAlternatives(for typed: String, alternatives: [String]) {
        pendingSwipeSpace = true
        guard config.wordSuggestionsEnabled else { return }
        currentWord = typed
        isPredicting = false
        var seen: Set<String> = [typed.lowercased()]
        let shaped = alternatives
            .map { Self.matchCase($0, to: typed) }
            .filter { seen.insert($0.lowercased()).inserted }
        suggestions = Array(shaped.prefix(3))
        pendingSwipeSpace = true
    }

    private func commit(_ word: String) {
        if learns {
            lexicon.learn(word: word, after: context)
        }
        context = word
    }

    private func update(_ word: String) {
        currentWord = word
        var next: [String] = []
        var predicting = false
        if word.count >= 2 {
            next = Self.completions(for: word, personal: lexicon.completions(for: word, limit: 3))
        } else if word.isEmpty, let context, learns, config.predictNextWord {
            next = lexicon.nextWords(after: context)
            predicting = !next.isEmpty
        }
        if next != suggestions {
            suggestions = next
        }
        if predicting != isPredicting {
            isPredicting = predicting
        }
    }

    public static func systemCandidates(for word: String) -> [String] {
        let range = NSRange(location: 0, length: (word as NSString).length)
        return NSSpellChecker.shared.completions(forPartialWordRange: range, in: word, language: nil, inSpellDocumentWithTag: 0) ?? []
    }

    public static func completions(
        for word: String,
        limit: Int = 3,
        personal: [String] = [],
        candidates: (String) -> [String] = WordSuggestions.systemCandidates(for:)
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for candidate in personal + candidates(word) where candidate.lowercased() != word.lowercased() {
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
        pendingSwipeSpace = false
        commit(suggestion)
        update("")
    }
}
