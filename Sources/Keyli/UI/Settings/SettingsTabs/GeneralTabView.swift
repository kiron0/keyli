import SwiftUI

final class GeneralTabUIState: ObservableObject {
    @Published var showResetConfirmation: Bool = false
    @Published var showLoginItemError: Bool = false
}

public struct GeneralTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @StateObject private var uiState = GeneralTabUIState()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Startup", symbol: "power")

            SettingsToggle("Launch Keyli at login", isOn: Binding(
                get: { configStore.config.launchAtLogin },
                set: { val in
                    let succeeded = LaunchAtLoginService.shared.setEnabled(val)
                    configStore.config.launchAtLogin = LaunchAtLoginService.shared.isEnabled
                    if !succeeded {
                        uiState.showLoginItemError = true
                    }
                    PermissionsManager.shared.checkPermissions()
                }
            ))

            SettingsSectionHeader(title: "Menu Bar", symbol: "menubar.rectangle")

            SettingsToggle(
                "Show Keyli in menu bar",
                detail: configStore.config.showMenuBarIcon
                    ? nil
                    : "Open Keyli again from Finder or Spotlight to reach the keyboard and these settings.",
                isOn: $configStore.config.showMenuBarIcon
            )

            SettingsSectionHeader(title: "Floating Keyboard", symbol: "macwindow")

            SettingsToggle("Show floating keyboard", isOn: $configStore.config.isFloatingVisible)

            SettingsToggle("Keep on top of other windows", isOn: $configStore.config.isFloatingPinned)

            SettingsSliderRow(
                "Opacity",
                value: $configStore.config.floatingOpacity,
                in: 0.4...1.0,
                step: 0.05,
                valueText: "\(Int((configStore.config.floatingOpacity * 100).rounded()))%"
            )

            SettingsSectionHeader(title: "Reset", symbol: "arrow.counterclockwise")

            SettingsRow {
                Button("Reset All Settings…") {
                    uiState.showResetConfirmation = true
                }
                .buttonStyle(SettingsSecondaryButtonStyle(isDestructive: true))

                Text("Custom themes are kept.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
            }
        }
        .onAppear {
            let actual = LaunchAtLoginService.shared.isEnabled
            if configStore.config.launchAtLogin != actual {
                configStore.config.launchAtLogin = actual
            }
        }
        .confirmationDialog("Reset all Keyli settings?", isPresented: $uiState.showResetConfirmation) {
            Button("Reset", role: .destructive) {
                LaunchAtLoginService.shared.setEnabled(false)
                configStore.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Settings return to their defaults. Your custom themes are kept.")
        }
        .alert("Keyli couldn’t change the login item", isPresented: $uiState.showLoginItemError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Move Keyli to the Applications folder, then try again. You can also manage login items in System Settings › General › Login Items.")
        }
    }
}
