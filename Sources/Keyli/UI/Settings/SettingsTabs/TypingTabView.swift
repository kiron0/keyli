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
                detail: "Shift, Control, Option, Command and fn switch off after one key press.",
                isOn: $configStore.config.modifierStickyMode
            )

            SettingsSectionHeader(title: "Keys", symbol: "keyboard")

            SettingsToggle(
                "Repeat keys while held",
                detail: "Uses the key repeat speed from System Settings › Keyboard.",
                isOn: $configStore.config.keyRepeatEnabled
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
