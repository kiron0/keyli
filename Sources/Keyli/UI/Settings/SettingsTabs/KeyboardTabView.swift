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

            SettingsToggle(
                "Keep on top of other windows",
                detail: "Other windows can't cover the keyboard.",
                isOn: $configStore.config.isFloatingPinned
            )

            SettingsToggle(
                "Lock keyboard position",
                detail: "The keyboard can't be moved or resized until you unlock it.",
                isOn: $configStore.config.isFloatingPositionLocked
            )

            SettingsSliderRow(
                "Opacity",
                value: $configStore.config.floatingOpacity,
                in: 0.4...1.0,
                step: 0.05,
                valueText: "\(Int((configStore.config.floatingOpacity * 100).rounded()))%"
            )

            SettingsToggle(
                "Show automatically in text fields",
                detail: "When you click into a text field, the keyboard appears. Needs Accessibility. Password fields are skipped.",
                isOn: $configStore.config.autoShowKeyboard
            )

            if configStore.config.autoShowKeyboard {
                SettingsToggle(
                    "Hide again when leaving the text field",
                    detail: "Only when Keyli showed the keyboard by itself.",
                    isOn: $configStore.config.autoHideKeyboard
                )

                Text("Never show automatically in")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.leading, 33)

                AppListEditor(
                    bundleIds: $configStore.config.autoShowExcludedApps,
                    emptyText: "Works in every app."
                )
            }

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

            SettingsToggle(
                "Show keystrokes on screen",
                detail: "Shows the keys you press in a large overlay, for screencasts and demos. Needs Input Monitoring.",
                isOn: $configStore.config.keystrokeOverlayEnabled
            )

            if configStore.config.keystrokeOverlayEnabled {
                SettingsRow {
                    Text("Show")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 130, alignment: .leading)
                    SettingsMenuPicker(
                        "Keystrokes to show",
                        selection: $configStore.config.keystrokeOverlayMode,
                        options: KeystrokeFormatter.Mode.allCases.map { SettingsMenuOption($0.rawValue, $0.title) },
                        width: 160
                    )
                    SettingsMenuPicker(
                        "Overlay position",
                        selection: $configStore.config.keystrokeOverlayPosition,
                        options: KeystrokeOverlay.positions.map { SettingsMenuOption($0.id, $0.title) },
                        width: 140
                    )
                }
            }

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
