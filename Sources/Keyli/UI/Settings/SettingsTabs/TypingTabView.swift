import SwiftUI

public struct TypingTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @ObservedObject public var permissionsManager: PermissionsManager = .shared

    public init() {}

    public var body: some View {
        Form {
            Section("Typing") {
                Toggle("Release modifier keys after the next key", isOn: $configStore.config.modifierStickyMode)
                    .help("Automatically unlatches modifier keys after a character is dispatched.")

                Toggle("Repeat keys while held", isOn: $configStore.config.keyRepeatEnabled)

                Toggle("Play sound on key press", isOn: $configStore.config.playKeyClickSound)

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
            }

            Section {
                Toggle("Highlight keys pressed on the physical keyboard", isOn: $configStore.config.isPhysicalMonitoringEnabled)

                if configStore.config.isPhysicalMonitoringEnabled && !permissionsManager.hasInputMonitoringPermission {
                    LabeledContent {
                        Button("Open Settings…") {
                            permissionsManager.openInputMonitoringPreferences()
                        }
                    } label: {
                        Label("Input Monitoring is off for Keyli", systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                    }
                }
            } header: {
                Text("Physical Keyboard")
            } footer: {
                Text("Requires Input Monitoring. Keyli only highlights keys while a keyboard is visible and never records or stores what you type.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            permissionsManager.checkPermissions()
        }
    }
}
