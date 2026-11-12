import SwiftUI

public struct TypingTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @ObservedObject public var permissionsManager: PermissionsManager = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Modifiers", symbol: "command")

            SettingsToggle(
                "Release modifier keys after the next key",
                detail: "Shift, Control, Option and Command switch off after one key press.",
                isOn: $configStore.config.modifierStickyMode
            )

            SettingsSectionHeader(title: "Keys", symbol: "keyboard")

            SettingsToggle("Repeat keys while held", isOn: $configStore.config.keyRepeatEnabled)

            SettingsToggle("Play sound on key press", isOn: $configStore.config.playKeyClickSound)

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

            SettingsSectionHeader(title: "Physical Keyboard", symbol: "dot.radiowaves.left.and.right")

            SettingsToggle(
                "Highlight keys pressed on the physical keyboard",
                detail: "Runs only while a keyboard is visible. Keyli never records or stores what you type.",
                isOn: $configStore.config.isPhysicalMonitoringEnabled
            )

            if configStore.config.isPhysicalMonitoringEnabled && !permissionsManager.hasInputMonitoringPermission {
                SettingsRow {
                    Label("Input Monitoring is off for Keyli.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.orange)

                    Button("Fix in Permissions") {
                        SettingsWindowController.shared.navigation.select(.permissions)
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                }
            }
        }
        .onAppear {
            permissionsManager.checkPermissions()
        }
    }
}
