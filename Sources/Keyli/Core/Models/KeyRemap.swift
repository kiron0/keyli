import Foundation

public enum RemapAction: Codable, Equatable {
    case text(String, shifted: String?)
    case key(UInt16)
    case shortcut([String])
    case snippet(String)
    case disabled

    public var kindName: String {
        switch self {
        case .text: return "text"
        case .key: return "key"
        case .shortcut: return "shortcut"
        case .snippet: return "snippet"
        case .disabled: return "disabled"
        }
    }

    public var repeats: Bool {
        switch self {
        case .text, .key: return true
        case .shortcut, .snippet, .disabled: return false
        }
    }
}

public struct KeyRemap: Codable, Equatable, Identifiable {
    public var keyId: String
    public var action: RemapAction
    public var label: String?

    public var id: String { keyId }

    public init(keyId: String, action: RemapAction, label: String? = nil) {
        self.keyId = keyId
        self.action = action
        self.label = label
    }
}

public enum RemapPreset: String, CaseIterable, Identifiable {
    case dvorak
    case colemak

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dvorak: return "Dvorak"
        case .colemak: return "Colemak"
        }
    }

    fileprivate var characters: [UInt16: String] {
        switch self {
        case .dvorak:
            return [
                27: "[", 24: "]",
                12: "'", 13: ",", 14: ".", 15: "p", 17: "y", 16: "f", 32: "g", 34: "c", 31: "r", 35: "l", 33: "/", 30: "=",
                0: "a", 1: "o", 2: "e", 3: "u", 5: "i", 4: "d", 38: "h", 40: "t", 37: "n", 41: "s", 39: "-",
                6: ";", 7: "q", 8: "j", 9: "k", 11: "x", 45: "b", 46: "m", 43: "w", 47: "v", 44: "z"
            ]
        case .colemak:
            return [
                14: "f", 15: "p", 17: "g", 16: "j", 32: "l", 34: "u", 31: "y", 35: ";",
                1: "r", 2: "s", 3: "t", 5: "d", 38: "n", 40: "e", 37: "i", 41: "o",
                45: "k"
            ]
        }
    }

    public var remaps: [KeyRemap] {
        characters
            .sorted { $0.key < $1.key }
            .map { KeyRemap(keyId: "k_\($0.key)", action: .text($0.value, shifted: nil)) }
    }

    public static var allKeyIds: Set<String> {
        Set(allCases.flatMap { $0.characters.keys }.map { "k_\($0)" })
    }
}

public enum KeyRemapper {
    public static let pressableKeys: [(code: UInt16, name: String)] = [
        (53, "Escape"), (48, "Tab"), (36, "Return"), (49, "Space"), (51, "Delete"), (117, "Forward Delete"),
        (115, "Home"), (119, "End"), (116, "Page Up"), (121, "Page Down"),
        (123, "Left Arrow"), (124, "Right Arrow"), (126, "Up Arrow"), (125, "Down Arrow"),
        (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"), (96, "F5"), (97, "F6"), (98, "F7"), (100, "F8"),
        (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12"), (105, "F13"), (107, "F14"), (113, "F15"),
        (106, "F16"), (64, "F17"), (79, "F18"), (80, "F19"), (90, "F20")
    ]

    public static func isRemappable(_ key: KeyboardKey) -> Bool {
        key.modifierType == nil && key.kind != .modifier && key.kind != .spacer
    }

    public static func shifted(_ text: String) -> String? {
        guard text.count == 1, let character = text.first else { return nil }
        let symbols: [Character: String] = [
            "'": "\"", ",": "<", ".": ">", "/": "?", ";": ":", "-": "_", "=": "+",
            "[": "{", "]": "}", "`": "~", "\\": "|",
            "1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&", "8": "*", "9": "(", "0": ")"
        ]
        if let symbol = symbols[character] { return symbol }
        let upper = text.uppercased()
        return upper != text ? upper : nil
    }

    public static func keyName(for code: UInt16) -> String {
        pressableKeys.first { $0.code == code }?.name ?? ShortcutManager.keyName(for: code) ?? "Key \(code)"
    }

    public static func label(for remap: KeyRemap, snippets: [Snippet]) -> String {
        if let label = remap.label, !label.isEmpty { return label }
        switch remap.action {
        case .text(let text, _):
            return text
        case .key(let code):
            return keyName(for: code).lowercased()
        case .shortcut(let keys):
            return keys.joined()
        case .snippet(let id):
            return snippets.first { $0.id == id }?.title ?? "snippet"
        case .disabled:
            return ""
        }
    }

    public static func apply(_ remaps: [KeyRemap], to keys: [KeyboardKey], snippets: [Snippet]) -> [KeyboardKey] {
        guard !remaps.isEmpty else { return keys }
        var byId: [String: KeyRemap] = [:]
        for remap in remaps { byId[remap.keyId] = remap }
        var codeForCharacter: [String: UInt16] = [:]
        for key in keys where key.kind == .character && !KeyboardLayoutManager.isKeypadKey(key) {
            let label = key.labels.defaultLabel.lowercased()
            if label.count == 1, codeForCharacter[label] == nil {
                codeForCharacter[label] = key.keyCode
            }
        }
        return keys.map { key in
            guard let remap = byId[key.id], isRemappable(key) else { return key }
            var mapped = key
            mapped.remap = remap.action
            mapped.symbolIcon = nil
            mapped.systemAction = nil
            let title = label(for: remap, snippets: snippets)
            switch remap.action {
            case .text(let text, let shifted):
                mapped.kind = .character
                let shiftLabel = remap.label?.isEmpty == false ? nil : (shifted ?? Self.shifted(text))
                mapped.labels = KeyLabels(defaultLabel: title, shiftLabel: shiftLabel)
                mapped.shortcutKeyCode = text.count == 1 ? codeForCharacter[text.lowercased()] : nil
            case .key:
                mapped.kind = .navigation
                mapped.labels = KeyLabels(defaultLabel: title)
            case .shortcut, .snippet, .disabled:
                mapped.kind = .system
                mapped.labels = KeyLabels(defaultLabel: title)
            }
            return mapped
        }
    }

    public static func applying(_ preset: RemapPreset, to remaps: [KeyRemap]) -> [KeyRemap] {
        let presetIds = RemapPreset.allKeyIds
        var result = remaps.filter { !presetIds.contains($0.keyId) }
        result += preset.remaps
        return result
    }

    public static func removingPresets(from remaps: [KeyRemap]) -> [KeyRemap] {
        let presetIds = RemapPreset.allKeyIds
        let presetRemaps = Set(RemapPreset.allCases.flatMap { $0.remaps }.map { "\($0.keyId)|\($0.action)" })
        return remaps.filter { !(presetIds.contains($0.keyId) && $0.label == nil && presetRemaps.contains("\($0.keyId)|\($0.action)")) }
    }

    public static func activePreset(in remaps: [KeyRemap]) -> RemapPreset? {
        let set = Set(remaps.map { "\($0.keyId)|\($0.action)" })
        return RemapPreset.allCases.first { preset in
            preset.remaps.allSatisfy { set.contains("\($0.keyId)|\($0.action)") }
        }
    }
}
