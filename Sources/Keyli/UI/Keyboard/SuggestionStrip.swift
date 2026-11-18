import SwiftUI
import Carbon

public enum SnippetRunner {
    public static func modifierState(for keys: [String]) -> KeyboardState? {
        guard let parsed = ShortcutManager.keysToCarbon(keys: keys) else { return nil }
        let state = KeyboardState()
        state.isCommandActive = parsed.modifiers & UInt32(cmdKey) != 0
        state.isOptionActive = parsed.modifiers & UInt32(optionKey) != 0
        state.isControlActive = parsed.modifiers & UInt32(controlKey) != 0
        state.isShiftActive = parsed.modifiers & UInt32(shiftKey) != 0
        return state
    }

    public static func run(_ snippet: Snippet) {
        let dispatcher = KeyboardInputDispatcher.shared
        switch snippet.kind {
        case .text:
            guard !snippet.text.isEmpty else { return }
            dispatcher.typeText(snippet.text, state: KeyboardState())
            WordSuggestions.shared.reset()
        case .shortcut:
            guard let parsed = ShortcutManager.keysToCarbon(keys: snippet.keys), let state = modifierState(for: snippet.keys) else { return }
            dispatcher.sendKeycode(UInt16(parsed.keyCode), state: state)
        }
        KeySoundEngine.shared.tap(36)
    }
}

public struct SuggestionStrip: View {
    @ObservedObject private var words: WordSuggestions = .shared
    public let theme: KeyboardTheme

    public init(theme: KeyboardTheme) {
        self.theme = theme
    }

    public var body: some View {
        let text = theme.chromeTextColor
        HStack(spacing: 5) {
            if words.suggestions.isEmpty {
                Text(words.currentWord.isEmpty ? "Suggestions appear as you type" : words.currentWord)
                    .font(.system(size: 11))
                    .foregroundStyle(text.opacity(0.45))
                    .lineLimit(1)
            } else {
                ForEach(Array(words.suggestions.enumerated()), id: \.offset) { index, word in
                    Button {
                        words.accept(word)
                    } label: {
                        Text(word)
                            .font(.system(size: 11.5, weight: index == 0 ? .semibold : .medium))
                            .foregroundStyle(text)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .frame(height: 20)
                            .background(text.opacity(0.12), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suggestion \(word)")
                }
            }
        }
        .frame(maxWidth: 380, alignment: .leading)
        .clipped()
    }
}
