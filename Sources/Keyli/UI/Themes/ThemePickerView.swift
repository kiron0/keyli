import SwiftUI

public struct ThemeSwatchView: View {
    public let theme: KeyboardTheme
    public var size: CGSize

    public init(theme: KeyboardTheme, size: CGSize = CGSize(width: 64, height: 40)) {
        self.theme = theme
        self.size = size
    }

    public var body: some View {
        let keyWidth = size.width * 0.2
        let keyHeight = size.height * 0.28
        let radius = max(1.5, CGFloat(theme.cornerRadius) * 0.35)

        ZStack {
            RoundedRectangle(cornerRadius: size.height * 0.2, style: .continuous)
                .fill(Color(hex: theme.backgroundColorHex))

            VStack(spacing: size.height * 0.08) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: size.width * 0.05) {
                        ForEach(0..<3, id: \.self) { column in
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    row == 1 && column == 2
                                        ? Color(hex: theme.accentColorHex)
                                        : Color(hex: theme.keycapBaseColorHex)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                                        .strokeBorder(Color(hex: theme.borderColorHex).opacity(theme.borderOpacity), lineWidth: 0.5)
                                )
                                .frame(width: keyWidth, height: keyHeight)
                        }
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: size.height * 0.2, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }
}

public struct ThemeCardView: View {
    public let theme: KeyboardTheme
    public let isSelected: Bool
    public var onSelect: () -> Void

    public init(theme: KeyboardTheme, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.theme = theme
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                // Miniature color preview
                ThemeSwatchView(theme: theme)
                    .padding(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                Text(theme.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .frame(width: 76)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public struct ThemePickerView: View {
    @ObservedObject public var themeManager: ThemeManager = .shared

    public init() {}

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(themeManager.availableThemes) { theme in
                    ThemeCardView(
                        theme: themeManager.resolved(theme),
                        isSelected: themeManager.currentTheme.id == theme.id,
                        onSelect: {
                            themeManager.selectTheme(theme)
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }
}
