import SwiftUI
import AppKit

public struct TypingTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Modifiers", symbol: "command")

            SettingsToggle(
                "Release modifier keys after the next key",
                detail: "Shift, Control, Option, Command and fn switch off after one key press. Double-click or hold Shift, Control, Option or Command to lock it, like holding it down; click it again to unlock. With Hover to Type, switch scanning or VoiceOver, choose it twice to lock. When this is off, every modifier stays on until you click it again.",
                isOn: $configStore.config.modifierStickyMode
            )

            SettingsSectionHeader(title: "Keys", symbol: "keyboard")

            SettingsToggle(
                "Repeat keys while held",
                detail: "Uses the key repeat speed from System Settings › Keyboard.",
                isOn: $configStore.config.keyRepeatEnabled
            )

            SettingsToggle(
                "Hold a letter for accents",
                detail: "Hold e, a, n and other keys to pick é, à, ñ and more. Drag to a character and release, or click one. Keys with accents don't repeat.",
                isOn: $configStore.config.accentPopupEnabled
            )

            SettingsToggle(
                "Swipe to type words",
                detail: "Press a letter and drag through the rest of a word without letting go. Keyli types the closest English word and offers others as suggestions. Swiping again adds the space for you.",
                isOn: $configStore.config.swipeTypingEnabled
            )

            SettingsToggle(
                "Show app shortcuts on keys",
                detail: "When ⌘ or ⌃ is on, keys show what they do in the app you're typing in, read from its menus.",
                isOn: $configStore.config.showAppShortcuts
            )

            SettingsSliderRow(
                "Key press duration",
                value: Binding(
                    get: { Double(configStore.config.syntheticTypingDelayMs) },
                    set: { configStore.config.syntheticTypingDelayMs = Int($0) }
                ),
                in: 0...20,
                step: 1,
                valueText: "\(configStore.config.syntheticTypingDelayMs) ms"
            )
            .help("How long Keyli holds each key down. Increase it if an app misses keys.")

            SettingsSectionHeader(title: "Suggestions", symbol: "text.bubble")

            SettingsToggle(
                "Show word suggestions",
                detail: "Suggestions appear in the keyboard's title bar for the word you're typing with Keyli. Click one to finish it.",
                isOn: $configStore.config.wordSuggestionsEnabled
            )

            if configStore.config.wordSuggestionsEnabled {
                SettingsToggle(
                    "Learn words you type",
                    detail: "Remembers the words you use and their order, on Keyli and on your Mac's keyboard, so suggestions fit how you write. Stays on this Mac. Password fields are never read. Typing on your Mac's keyboard needs Input Monitoring.",
                    isOn: $configStore.config.learnWordsFromTyping
                )

                if configStore.config.learnWordsFromTyping {
                    SettingsToggle(
                        "Predict the next word",
                        detail: "After a space, suggests words you often type next.",
                        isOn: $configStore.config.predictNextWord
                    )
                }

                PersonalDictionaryEditor()
            }

            SettingsSectionHeader(title: "Clipboard History", symbol: "doc.on.clipboard")

            SettingsToggle(
                "Keep clipboard history",
                detail: "Keeps the last \(ClipboardHistory.maxItems) text items you copy so you can paste them again from ⋯ › Clipboard History. Held in memory only and cleared when Keyli quits. Copies from password managers are skipped.",
                isOn: $configStore.config.clipboardHistoryEnabled
            )

            SettingsSectionHeader(title: "Snippet Keys", symbol: "text.quote")

            SettingsInlineNote(
                symbol: "text.quote",
                title: "Snippets window",
                detail: "Choose ⋯ › Snippets… on the keyboard, or press your shortcut, to open a floating window. Click a snippet to type the phrase or send the shortcut."
            )
            .padding(.leading, 33)

            SnippetEditor()

            SettingsSectionHeader(title: "Hover to Type", symbol: "cursorarrow.rays")

            SettingsToggle(
                "Press a key by resting the pointer on it",
                detail: "Useful when clicking is hard. A bar fills on the key, then it's pressed once. Move to another key to press again.",
                isOn: $configStore.config.dwellEnabled
            )

            if configStore.config.dwellEnabled {
                SettingsSliderRow(
                    "Hover time",
                    value: $configStore.config.dwellDuration,
                    in: 0.4...2.5,
                    step: 0.1,
                    valueText: String(format: "%.1f s", configStore.config.dwellDuration)
                )
            }

            SettingsSectionHeader(title: "Switch Scanning", symbol: "dot.viewfinder")

            SettingsToggle(
                "Scan the keys for a switch",
                detail: "A highlight steps through the rows, then through the keys in the chosen row. Use your switch once to pick the row and again to press the key.",
                isOn: $configStore.config.scanningEnabled
            )

            if configStore.config.scanningEnabled {
                SettingsSliderRow(
                    "Time per step",
                    value: $configStore.config.scanInterval,
                    in: 0.4...3.0,
                    step: 0.1,
                    valueText: String(format: "%.1f s", configStore.config.scanInterval)
                )

                SettingsToggle(
                    "Click anywhere on the keyboard to select",
                    detail: "Any click on the keyboard acts as your switch. Turn this off to use only the switch shortcut.",
                    isOn: $configStore.config.scanSelectByClick
                )

                SettingsRow {
                    let binding = ShortcutManager.shared.binding(for: .scanSelect)
                    Text(binding.isEnabled && !binding.keys.isEmpty
                         ? "Switch shortcut: \(binding.keys.joined(separator: " "))"
                         : "If your switch sends a key, set it as the switch shortcut, such as F13.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                    Button("Shortcuts…") {
                        SettingsWindowController.shared.showSettings(tab: .shortcuts)
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                }
            }

            SettingsInlineNote(
                symbol: "accessibility",
                title: "VoiceOver",
                detail: "Every key reads its name, what it does and whether a modifier is on. On a letter, open the VoiceOver actions menu (VO-Command-Space) to type its accents."
            )
            .padding(.leading, 33)

            SettingsSectionHeader(title: "Tips", symbol: "lightbulb")

            SettingsInlineNote(
                symbol: "fn",
                title: "The fn key",
                detail: "Tap fn to do what your Globe key does in System Settings › Keyboard, such as switching input source. Hold fn to latch it, then press an arrow for Home, End, Page Up or Page Down, delete for Forward Delete, or F1–F12."
            )
            .padding(.leading, 33)
        }
    }
}
