import Foundation

public struct LexiconData: Codable, Equatable {
    public var words: [String: Int] = [:]
    public var pairs: [String: [String: Int]] = [:]
    public var customWords: [String] = []

    public init(words: [String: Int] = [:], pairs: [String: [String: Int]] = [:], customWords: [String] = []) {
        self.words = words
        self.pairs = pairs
        self.customWords = customWords
    }
}

public final class PersonalLexicon: ObservableObject {
    public static let shared = PersonalLexicon()

    public static let maxWords = 5000
    public static let maxPairsPerWord = 12
    public static let minimumLearnedCount = 2

    @Published public private(set) var data: LexiconData

    private let fileURL: URL?
    private var saveItem: DispatchWorkItem?

    public static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Keyli/Words.json")
    }

    public init(fileURL: URL? = PersonalLexicon.defaultURL) {
        self.fileURL = fileURL
        if let fileURL, let stored = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(LexiconData.self, from: stored) {
            data = decoded
        } else {
            data = LexiconData()
        }
    }

    public var learnedWordCount: Int {
        data.words.count
    }

    public static func normalized(_ word: String) -> String? {
        let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
        guard (2...32).contains(trimmed.count),
              trimmed.allSatisfy({ WordSuggestions.isWordCharacter($0) }),
              trimmed.contains(where: { $0.isLetter }) else { return nil }
        return trimmed.lowercased()
    }

    public func learn(word: String, after previous: String?) {
        guard let key = Self.normalized(word) else { return }
        data.words[key, default: 0] += 1
        if let previous, let previousKey = Self.normalized(previous) {
            var next = data.pairs[previousKey] ?? [:]
            next[key, default: 0] += 1
            if next.count > Self.maxPairsPerWord {
                let kept = next.sorted { $0.value > $1.value }.prefix(Self.maxPairsPerWord)
                next = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
            }
            data.pairs[previousKey] = next
        }
        pruneIfNeeded()
        scheduleSave()
    }

    @discardableResult
    public func addCustomWord(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.normalized(trimmed) != nil,
              !data.customWords.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return false }
        data.customWords.append(trimmed)
        data.customWords.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        scheduleSave()
        return true
    }

    public func removeCustomWord(_ word: String) {
        data.customWords.removeAll { $0 == word }
        scheduleSave()
    }

    public func mergeCustomWords(_ words: [String]) {
        for word in words {
            addCustomWord(word)
        }
    }

    public func forgetLearnedWords() {
        data.words.removeAll()
        data.pairs.removeAll()
        scheduleSave()
    }

    public func completions(for prefix: String, limit: Int = 3) -> [String] {
        let lowered = prefix.lowercased()
        guard !lowered.isEmpty else { return [] }
        var result: [String] = []
        var seen = Set<String>()
        for word in data.customWords where word.lowercased().hasPrefix(lowered) && word.lowercased() != lowered {
            if seen.insert(word.lowercased()).inserted { result.append(word) }
        }
        let learned = data.words
            .filter { $0.value >= Self.minimumLearnedCount && $0.key.hasPrefix(lowered) && $0.key != lowered }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        for (word, _) in learned where seen.insert(word).inserted {
            result.append(word)
        }
        return Array(result.prefix(limit))
    }

    public func nextWords(after word: String, limit: Int = 3) -> [String] {
        guard let key = Self.normalized(word), let next = data.pairs[key] else { return [] }
        return next
            .filter { $0.value >= Self.minimumLearnedCount }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    public func frequency(of word: String) -> Int {
        guard let key = Self.normalized(word) else { return 0 }
        if data.customWords.contains(where: { $0.lowercased() == key }) { return 1000 }
        return data.words[key] ?? 0
    }

    public func flush() {
        saveItem?.cancel()
        saveItem = nil
        save()
    }

    private func pruneIfNeeded() {
        guard data.words.count > Self.maxWords else { return }
        let target = Self.maxWords * 9 / 10
        let removed = data.words.sorted { $0.value < $1.value }.prefix(data.words.count - target).map { $0.key }
        for word in removed {
            data.words[word] = nil
            data.pairs[word] = nil
        }
        let removedSet = Set(removed)
        for (key, next) in data.pairs {
            let filtered = next.filter { !removedSet.contains($0.key) }
            data.pairs[key] = filtered.isEmpty ? nil : filtered
        }
    }

    private func scheduleSave() {
        guard fileURL != nil else { return }
        saveItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.save()
        }
        saveItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    private func save() {
        guard let fileURL else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }
}
