import SwiftUI

public struct ThemesTabView: View {
    @ObservedObject public var themeManager: ThemeManager = .shared

    public init() {}

    private let columns = [GridItem(.adaptive(minimum: 92, maximum: 110), spacing: 10)]

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Current Theme", symbol: "checkmark.circle")

            SettingsRow {
                ThemeSwatchView(theme: themeManager.resolved(themeManager.currentTheme), size: CGSize(width: 54, height: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(themeManager.currentTheme.name)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(themeManager.currentTheme.isBuiltIn ? "Built-in" : "Custom")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 8)
                Button("Open Theme Studio…") {
                    NotificationCenter.default.post(name: KeyliConstants.NotificationName.openThemeStudio, object: nil)
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
            }

            if !themeManager.customThemes.isEmpty {
                SettingsSectionHeader(title: "My Themes", symbol: "person.crop.square")
                grid(themeManager.customThemes)
            }

            SettingsSectionHeader(title: "Built-in (\(themeManager.availableThemes.filter(\.isBuiltIn).count))", symbol: "square.grid.2x2")
            grid(themeManager.availableThemes.filter(\.isBuiltIn))

            Text("macOS Native follows the system light and dark appearance.")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.secondary)
                .padding(.leading, 33)
                .padding(.top, 4)
        }
    }

    private func grid(_ themes: [KeyboardTheme]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(themes) { theme in
                ThemeCardView(
                    theme: themeManager.resolved(theme),
                    isSelected: themeManager.currentTheme.id == theme.id,
                    onSelect: { themeManager.selectTheme(theme) }
                )
            }
        }
        .padding(.leading, 29)
        .padding(.top, 4)
    }
}
