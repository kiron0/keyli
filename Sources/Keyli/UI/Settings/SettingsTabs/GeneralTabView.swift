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
        Form {
            Section {
                Toggle("Launch Keyli at login", isOn: Binding(
                    get: { configStore.config.launchAtLogin },
                    set: { val in
                        let succeeded = LaunchAtLoginService.shared.setEnabled(val)
                        configStore.config.launchAtLogin = LaunchAtLoginService.shared.isEnabled
                        if !succeeded {
                            uiState.showLoginItemError = true
                        }
                    }
                ))

                Toggle("Show Keyli in menu bar", isOn: $configStore.config.showMenuBarIcon)
            } footer: {
                if !configStore.config.showMenuBarIcon {
                    Text("With the menu bar icon hidden, open Keyli again from Finder or Spotlight to reach the keyboard and these settings.")
                }
            }

            Section("Floating Keyboard") {
                Toggle("Show floating keyboard", isOn: $configStore.config.isFloatingVisible)

                Toggle("Keep on top of other windows", isOn: $configStore.config.isFloatingPinned)

                SettingsSliderRow(
                    "Opacity",
                    value: $configStore.config.floatingOpacity,
                    in: 0.4...1.0,
                    step: 0.05,
                    valueText: "\(Int((configStore.config.floatingOpacity * 100).rounded()))%"
                )
            }

            Section {
                Button("Reset All Settings…", role: .destructive) {
                    uiState.showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
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
