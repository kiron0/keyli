import SwiftUI

public struct AppearanceTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @ObservedObject public var themeManager: ThemeManager = .shared
    @ObservedObject public var keyboardState: KeyboardState = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Layout", symbol: "keyboard")

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
            }

            SettingsSectionHeader(title: "Theme", symbol: "paintpalette")

            ThemePickerView()
                .padding(.leading, 29)
                .padding(.top, 2)

            SettingsRow {
                Button("Open Theme Studio…") {
                    NotificationCenter.default.post(name: KeyliConstants.NotificationName.openThemeStudio, object: nil)
                }
                .buttonStyle(SettingsPrimaryButtonStyle())

                Text("macOS Native follows the system light and dark appearance.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.top, 4)
        }
    }
}
