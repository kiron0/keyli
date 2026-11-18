import Testing
import Foundation
import CoreGraphics
@testable import Keyli

@Suite("Numeric keypad")
struct NumericKeypadTests {
    @Test func addsKeypadToTheRight() {
        let manager = KeyboardLayoutManager.shared
        let plain = manager.generateLayout(geometry: .ansi, numericKeypad: false)
        let keypad = manager.generateLayout(geometry: .ansi, numericKeypad: true)
        #expect(keypad.unitWidth == plain.unitWidth + KeyboardLayoutManager.keypadGap + KeyboardLayoutManager.keypadWidth)
        #expect(keypad.id != plain.id)
        let added = keypad.keys.filter { KeyboardLayoutManager.isKeypadKey($0) }
        #expect(added.count == 22)
        #expect(Set(keypad.keys.map(\.id)).count == keypad.keys.count)
        for key in added {
            #expect(key.unitFrame.x >= plain.unitWidth)
            #expect(key.unitFrame.x + key.unitFrame.width <= keypad.unitWidth + 0.0001)
            #expect(key.unitFrame.y + key.unitFrame.height <= keypad.unitHeight + 0.0001)
        }
        #expect(added.contains { $0.keyCode == 76 && $0.kind == .system })
        #expect(added.contains { $0.keyCode == 82 && $0.unitFrame.width == 2 })
    }

    @Test func compactKeypadSkipsNavigationRow() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .compact, numericKeypad: true)
        let added = layout.keys.filter { KeyboardLayoutManager.isKeypadKey($0) }
        #expect(added.count == 18)
        #expect(added.allSatisfy { $0.unitFrame.y >= 0 })
    }

    @Test func keypadKeysDoNotOverlap() {
        let keys = KeyboardLayoutManager.keypadKeys(originX: 0, topOffset: 0, includesNavigationRow: true)
        for (i, a) in keys.enumerated() {
            for b in keys[(i + 1)...] {
                let ra = CGRect(x: a.unitFrame.x, y: a.unitFrame.y, width: a.unitFrame.width, height: a.unitFrame.height)
                let rb = CGRect(x: b.unitFrame.x, y: b.unitFrame.y, width: b.unitFrame.width, height: b.unitFrame.height)
                #expect(!ra.insetBy(dx: 0.01, dy: 0.01).intersects(rb.insetBy(dx: 0.01, dy: 0.01)))
            }
        }
    }
}

@Suite("Personal words")
struct PersonalLexiconTests {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("keyli-words-\(UUID().uuidString).json")
    }

    @Test func learnedWordsNeedTwoUses() {
        let lexicon = PersonalLexicon(fileURL: nil)
        lexicon.learn(word: "Keyboarding", after: nil)
        #expect(lexicon.completions(for: "keyb").isEmpty)
        lexicon.learn(word: "keyboarding", after: nil)
        #expect(lexicon.completions(for: "keyb") == ["keyboarding"])
    }

    @Test func customWordsComeFirstAndKeepCase() {
        let lexicon = PersonalLexicon(fileURL: nil)
        #expect(lexicon.addCustomWord("Keyli"))
        #expect(!lexicon.addCustomWord("keyli"))
        #expect(!lexicon.addCustomWord("1"))
        lexicon.learn(word: "keynote", after: nil)
        lexicon.learn(word: "keynote", after: nil)
        #expect(lexicon.completions(for: "Key") == ["Keyli", "keynote"])
        lexicon.removeCustomWord("Keyli")
        #expect(lexicon.data.customWords.isEmpty)
    }

    @Test func predictsNextWordsFromPairs() {
        let lexicon = PersonalLexicon(fileURL: nil)
        for _ in 0..<3 { lexicon.learn(word: "morning", after: "good") }
        lexicon.learn(word: "night", after: "good")
        lexicon.learn(word: "night", after: "good")
        #expect(lexicon.nextWords(after: "Good") == ["morning", "night"])
        lexicon.forgetLearnedWords()
        #expect(lexicon.nextWords(after: "good").isEmpty)
        #expect(lexicon.learnedWordCount == 0)
    }

    @Test func rejectsNonWords() {
        #expect(PersonalLexicon.normalized("a") == nil)
        #expect(PersonalLexicon.normalized("abc123") == nil)
        #expect(PersonalLexicon.normalized("Don't") == "don't")
    }

    @Test func savesAndLoads() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let lexicon = PersonalLexicon(fileURL: url)
        lexicon.addCustomWord("Kiron")
        lexicon.learn(word: "hello", after: nil)
        lexicon.flush()
        let reloaded = PersonalLexicon(fileURL: url)
        #expect(reloaded.data == lexicon.data)
    }

    @Test @MainActor func suggestionsLearnAndPredict() {
        var config = KeyliConfig()
        config.wordSuggestionsEnabled = true
        config.learnWordsFromTyping = true
        let lexicon = PersonalLexicon(fileURL: nil)
        let words = WordSuggestions(lexicon: lexicon) { config }
        words.didType("good morning ")
        words.didType("good morning ")
        words.didType("good ")
        #expect(words.isPredicting)
        #expect(words.suggestions.first == "morning")
        words.didType(". ")
        #expect(words.suggestions.isEmpty)
        config.predictNextWord = false
        words.didType("good ")
        #expect(words.suggestions.isEmpty)
    }

    @Test @MainActor func nothingIsLearnedWhenOff() {
        var config = KeyliConfig()
        config.wordSuggestionsEnabled = true
        let lexicon = PersonalLexicon(fileURL: nil)
        let words = WordSuggestions(lexicon: lexicon) { config }
        words.didType("hello world hello world ")
        #expect(lexicon.learnedWordCount == 0)
        words.didTypePhysically(.text("abc "))
        #expect(words.currentWord.isEmpty)
    }

    @Test func classifiesPhysicalKeys() {
        #expect(WordSuggestions.classifyPhysical(keyCode: 0, characters: "a", command: false, control: false) == .text("a"))
        #expect(WordSuggestions.classifyPhysical(keyCode: 0, characters: "a", command: true, control: false) == .reset)
        #expect(WordSuggestions.classifyPhysical(keyCode: 51, characters: "\u{8}", command: false, control: false) == .key(51))
        #expect(WordSuggestions.classifyPhysical(keyCode: 36, characters: "\r", command: false, control: false) == .key(36))
        #expect(WordSuggestions.classifyPhysical(keyCode: 122, characters: "\u{10}", command: false, control: false) == .ignore)
    }

    @Test func personalCompletionsLeadSystemOnes() {
        let results = WordSuggestions.completions(for: "Kir", personal: ["Kiron"]) { _ in ["kirk", "kirby"] }
        #expect(results == ["Kiron", "Kirk", "Kirby"])
    }
}

@Suite("App shortcuts on keys")
struct MenuShortcutTests {
    private func key(_ id: String, _ code: UInt16, _ label: String, kind: KeyKind = .character) -> KeyboardKey {
        KeyboardKey(id: id, keyCode: code, kind: kind, unitFrame: KeyUnitFrame(x: 0, y: 0), labels: KeyLabels(defaultLabel: label))
    }

    @Test func readsAccessibilityModifierMask() {
        #expect(ShortcutModifiers.fromAccessibilityMask(0) == [.command])
        #expect(ShortcutModifiers.fromAccessibilityMask(1) == [.shift, .command])
        #expect(ShortcutModifiers.fromAccessibilityMask(2 | 4) == [.option, .control, .command])
        #expect(ShortcutModifiers.fromAccessibilityMask(8 | 4) == [.control])
    }

    @Test func mapsShortcutsToKeysForActiveModifiers() {
        let keys = [key("k_1", 1, "s"), key("k_123", 123, "◀", kind: .navigation), key("k_13", 13, "w")]
        let shortcuts = [
            MenuShortcut(title: "Save…", character: "S", modifiers: [.command]),
            MenuShortcut(title: "Save As…", character: "S", modifiers: [.shift, .command]),
            MenuShortcut(title: "Previous Tab", keyCode: 123, modifiers: [.command]),
            MenuShortcut(title: "Close Window", character: "W", modifiers: [.command])
        ]
        let command = MenuShortcutService.hints(for: keys, modifiers: [.command], shortcuts: shortcuts)
        #expect(command == ["k_1": "Save", "k_123": "Previous Tab", "k_13": "Close Window"])
        let shifted = MenuShortcutService.hints(for: keys, modifiers: [.shift, .command], shortcuts: shortcuts)
        #expect(shifted == ["k_1": "Save As"])
        #expect(MenuShortcutService.hints(for: keys, modifiers: [.shift], shortcuts: shortcuts).isEmpty)
    }

    @Test func shortensLongTitles() {
        #expect(MenuShortcutService.shortTitle("Open Recent…") == "Open Recent")
        #expect(MenuShortcutService.shortTitle("Show Developer Tools in a Window", limit: 12).count <= 12)
    }
}

@Suite("Clipboard history")
struct ClipboardHistoryTests {
    @Test func skipsPasswordManagerCopies() {
        #expect(!ClipboardHistory.shouldRecord(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        #expect(ClipboardHistory.shouldRecord(types: ["public.utf8-plain-text"]))
    }

    @Test func movesRepeatsToTopAndCaps() {
        var items: [ClipboardItem] = []
        for i in 0..<5 {
            items = ClipboardHistory.inserting("item \(i)", into: items, limit: 3)
        }
        #expect(items.map(\.text) == ["item 4", "item 3", "item 2"])
        items = ClipboardHistory.inserting("item 2", into: items, limit: 3)
        #expect(items.map(\.text) == ["item 2", "item 4", "item 3"])
        #expect(ClipboardHistory.inserting("   \n", into: items) == items)
    }

    @Test func searchesCaseInsensitively() {
        let items = [ClipboardItem(text: "Hello World"), ClipboardItem(text: "Other")]
        #expect(ClipboardHistory.matching(items, query: "hello").map(\.text) == ["Hello World"])
        #expect(ClipboardHistory.matching(items, query: " ").count == 2)
    }
}

@Suite("Swipe typing")
struct SwipeDecoderTests {
    private func centers() -> [Character: CGPoint] {
        var map: [Character: CGPoint] = [:]
        for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            let offset: CGFloat = [0, 0.25, 0.75][row]
            for (i, letter) in letters.enumerated() {
                map[letter] = CGPoint(x: CGFloat(i) + offset, y: CGFloat(row))
            }
        }
        return map
    }

    @Test func collapsesRepeats() {
        #expect(SwipeDecoder.collapse(Array("hhellloo")) == Array("helo"))
    }

    @Test func fitsNeedsMatchingEndsAndOrder() {
        let path = Array("hgfdertyuiklo")
        #expect(SwipeDecoder.fits("hello", path: path))
        #expect(SwipeDecoder.fits("hero", path: path))
        #expect(!SwipeDecoder.fits("hole", path: path))
        #expect(!SwipeDecoder.fits("halo", path: path))
    }

    @Test func ranksTheWordWhoseShapeMatches() {
        let map = centers()
        let points = ["h", "e", "l", "o"].compactMap { map[Character($0)] }
        let ranked = SwipeDecoder.rank(
            path: Array("hgfdertyuiklo"),
            points: points,
            centers: map,
            keySize: 1,
            candidates: ["hero", "hello", "helio", "halo"],
            prior: SwipeDecoder.commonBonus
        )
        #expect(ranked.first == "hello")
        #expect(!ranked.contains("halo"))
    }

    @Test func decodesCommonWordsAgainstTheFullDictionary() {
        let map = centers()
        let index = SwipeDictionary.buildIndex()
        func swipe(_ word: String) -> String? {
            let letters = SwipeDecoder.collapse(Array(word))
            var points: [CGPoint] = []
            var path: [Character] = []
            for (a, b) in zip(letters, letters.dropFirst()) {
                guard let start = map[a], let end = map[b] else { return nil }
                for step in 0..<8 {
                    let t = CGFloat(step) / 8
                    let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                    points.append(point)
                    if let nearest = map.min(by: { hypot($0.value.x - point.x, $0.value.y - point.y) < hypot($1.value.x - point.x, $1.value.y - point.y) })?.key,
                       path.last != nearest {
                        path.append(nearest)
                    }
                }
            }
            if let last = letters.last, let end = map[last] {
                points.append(end)
                if path.last != last { path.append(last) }
            }
            guard let first = path.first, let last = path.last else { return nil }
            return SwipeDecoder.rank(
                path: path,
                points: points,
                centers: map,
                keySize: 1,
                candidates: index[SwipeDictionary.key(first: first, last: last)] ?? [],
                prior: SwipeDecoder.commonBonus
            ).first
        }
        for word in ["hello", "thanks", "people", "because", "keyboard", "today", "about", "world"] {
            #expect(swipe(word) == word, "swiping \(word)")
        }
    }

    @Test func resamplesEvenly() {
        let points = SwipeDecoder.resample([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)], count: 3)
        #expect(points == [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: 10, y: 0)])
    }

    @Test func dictionaryIndexIncludesCommonWords() {
        let index = SwipeDictionary.buildIndex()
        #expect(index["ho"]?.contains("hello") == true)
        #expect(index.values.allSatisfy { $0.allSatisfy { $0.allSatisfy { $0 >= "a" && $0 <= "z" } } })
    }
}

@Suite("Settings backup")
struct SettingsBackupTests {
    private func sampleConfig() -> KeyliConfig {
        var config = KeyliConfig()
        config.themeId = "kiln"
        config.floatingWindowX = 120
        config.launchAtLogin = true
        config.settingsSyncFolder = "/tmp/sync"
        config.showNumericKeypad = true
        return config
    }

    @Test func portableDropsMachineSettings() {
        let portable = SettingsBackup.portable(sampleConfig())
        #expect(portable.floatingWindowX == nil)
        #expect(portable.launchAtLogin == false)
        #expect(portable.settingsSyncFolder == nil)
        #expect(portable.themeId == "kiln")
        #expect(portable.showNumericKeypad)
    }

    @Test func mergeKeepsLocalMachineSettings() {
        var local = KeyliConfig()
        local.floatingWindowX = 40
        local.launchAtLogin = true
        local.settingsSyncFolder = "/Users/me/Sync"
        let merged = SettingsBackup.merged(SettingsBackup.portable(sampleConfig()), keepingLocal: local)
        #expect(merged.floatingWindowX == 40)
        #expect(merged.launchAtLogin)
        #expect(merged.settingsSyncFolder == "/Users/me/Sync")
        #expect(merged.themeId == "kiln")
    }

    @Test func roundTripsAndIgnoresTimestampInPayload() throws {
        let first = KeyliBackup(
            appVersion: "1.0.2",
            createdAt: Date(timeIntervalSince1970: 1_000),
            config: SettingsBackup.portable(sampleConfig()),
            shortcuts: ["toggleKeyboard": ShortcutBinding(isEnabled: true, keys: ["^", "⌥", "K"])],
            customThemes: [],
            personalWords: ["Keyli"]
        )
        let decoded = try SettingsBackup.decode(SettingsBackup.encode(first))
        #expect(decoded == first)
        var later = first
        later.createdAt = Date(timeIntervalSince1970: 9_000)
        later.appVersion = "1.0.3"
        #expect(SettingsBackup.payload(first) == SettingsBackup.payload(later))
        later.personalWords.append("Kiron")
        #expect(SettingsBackup.payload(first) != SettingsBackup.payload(later))
    }

    @Test func rejectsBadOrNewerFiles() throws {
        #expect(throws: SettingsBackupError.unreadable) {
            try SettingsBackup.decode(Data("nope".utf8))
        }
        var future = KeyliBackup(appVersion: "9", createdAt: Date(), config: KeyliConfig(), shortcuts: [:], customThemes: [], personalWords: [])
        future.format = KeyliBackup.currentFormat + 1
        let data = try SettingsBackup.encode(future)
        #expect(throws: SettingsBackupError.newerFormat) {
            try SettingsBackup.decode(data)
        }
    }

    @Test func newSettingsDecodeWithDefaults() throws {
        let decoded = try JSONDecoder().decode(KeyliConfig.self, from: Data("{}".utf8))
        #expect(decoded.showNumericKeypad == false)
        #expect(decoded.learnWordsFromTyping == false)
        #expect(decoded.predictNextWord)
        #expect(decoded.showAppShortcuts)
        #expect(decoded.clipboardHistoryEnabled == false)
        #expect(decoded.swipeTypingEnabled == false)
        #expect(decoded.settingsSyncFolder == nil)
        #expect(ShortcutAction.toggleClipboard.group == .typing)
    }
}
