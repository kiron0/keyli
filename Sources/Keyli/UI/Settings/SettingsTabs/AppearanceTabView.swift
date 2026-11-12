import SwiftUI

public struct AppearanceTabView: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @ObservedObject public var themeManager: ThemeManager = .shared
    @ObservedObject public var keyboardState: KeyboardState = .shared

    public init() {}

    public var body: some View {
        Form {
            Section("Keyboard") {
                Picker("Layout", selection: $configStore.config.layoutGeometry) {
                    ForEach(GeometryType.allCases, id: \.rawValue) { geo in
                        Text(geo.displayName).tag(geo.rawValue)
                    }
                }

                LabeledContent("Input source", value: keyboardState.currentLayout.inputSourceName ?? "Unknown")
            }

            Section {
                ThemePickerView()

                LabeledContent("Selected theme") {
                    Button("Open Theme Studio…") {
                        NotificationCenter.default.post(name: KeyliConstants.NotificationName.openThemeStudio, object: nil)
                    }
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("macOS Native follows the system light and dark appearance.")
            }
        }
        .formStyle(.grouped)
    }
}
