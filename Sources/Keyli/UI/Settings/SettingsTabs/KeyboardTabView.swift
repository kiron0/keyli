import SwiftUI

public struct KeyboardTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @ObservedObject public var permissionsManager: PermissionsManager = .shared
    @ObservedObject public var keyboardState: KeyboardState = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Floating Keyboard", symbol: "macwindow")

            SettingsToggle(
                "Show floating keyboard",
                detail: "Click the Keyli menu bar icon to show or hide it at any time.",
                isOn: $configStore.config.isFloatingVisible
            )

            SettingsToggle("Keep on top of other windows", isOn: $configStore.config.isFloatingPinned)

            SettingsSliderRow(
                "Opacity",
                value: $configStore.config.floatingOpacity,
                in: 0.4...1.0,
                step: 0.05,
                valueText: "\(Int((configStore.config.floatingOpacity * 100).rounded()))%"
            )

            SettingsSectionHeader(title: "Layout", symbol: "rectangle.grid.3x2")

            SettingsRow {
                Text("Keyboard layout")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 130, alignment: .leading)

                Picker("Keyboard layout", selection: $configStore.config.layoutGeometry) {
                    ForEach(GeometryType.allCases, id: \.rawValue) { geo in
                        Text(geo.displayName).tag(geo.rawValue)
                    }
                }
                .settingsMenu()
                .frame(width: 200)
            }

            SettingsRow {
                Text("Input source")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 130, alignment: .leading)

                Text(keyboardState.currentLayout.inputSourceName ?? "Unknown")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)

                Text("Follows the input source in the menu bar.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary.opacity(0.8))
            }

            SettingsSectionHeader(title: "Physical Keyboard", symbol: "dot.radiowaves.left.and.right")

            SettingsToggle(
                "Highlight keys pressed on the physical keyboard",
                detail: "Runs only while a keyboard is visible. Keyli never records or stores what you type.",
                isOn: $configStore.config.isPhysicalMonitoringEnabled
            )

            if permissionsManager.needsAttention(.inputMonitoring) {
                SettingsRow {
                    Label(permissionsManager.status(of: .inputMonitoring).label + ": Input Monitoring", systemImage: "exclamationmark.triangle.fill")
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
