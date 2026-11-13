import SwiftUI

public struct KeyboardTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @ObservedObject public var permissionsManager: PermissionsManager = .shared
    @ObservedObject public var keyboardState: KeyboardState = .shared
    @ObservedObject private var inputSources: InputSourceService = .shared

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

                SettingsMenuPicker(
                    "Keyboard layout",
                    selection: $configStore.config.layoutGeometry,
                    options: GeometryType.allCases.map { SettingsMenuOption($0.rawValue, $0.displayName) }
                )
            }

            SettingsRow {
                Text("Input source")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 130, alignment: .leading)

                SettingsMenuPicker(
                    "Input source",
                    selection: Binding(
                        get: { inputSources.currentId },
                        set: { inputSources.select(id: $0) }
                    ),
                    options: inputSourceOptions
                )

                Button("Edit…") {
                    inputSources.openInputSourceSettings()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .help("Add or remove input sources in System Settings › Keyboard.")
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
            inputSources.refresh()
        }
    }

    private var inputSourceOptions: [SettingsMenuOption<String>] {
        var options = inputSources.sources.map { SettingsMenuOption($0.id, $0.name) }
        if !inputSources.sources.contains(where: { $0.id == inputSources.currentId }) {
            options.append(SettingsMenuOption(inputSources.currentId, keyboardState.currentLayout.inputSourceName ?? "Current"))
        }
        return options
    }
}
