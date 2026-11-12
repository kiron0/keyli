import SwiftUI

public struct ThemeSwatchView: View, Equatable {
    public let theme: KeyboardTheme
    public var size: CGSize

    public init(theme: KeyboardTheme, size: CGSize = CGSize(width: 64, height: 40)) {
        self.theme = theme
        self.size = size
    }

    public var body: some View {
        let background = Color(hex: theme.backgroundColorHex)
        let keyColor = Color(hex: theme.keycapBaseColorHex)
        let accent = Color(hex: theme.accentColorHex)
        let border = Color(hex: theme.borderColorHex).opacity(theme.borderOpacity)
        let outerRadius = size.height * 0.2
        let keyRadius = max(1.5, CGFloat(theme.cornerRadius) * 0.35 * size.height / 40)

        Canvas { context, canvasSize in
            let outer = Path(roundedRect: CGRect(origin: .zero, size: canvasSize), cornerRadius: outerRadius, style: .continuous)
            context.fill(outer, with: .color(background))

            let keyWidth = canvasSize.width * 0.2
            let keyHeight = canvasSize.height * 0.28
            let hGap = canvasSize.width * 0.05
            let vGap = canvasSize.height * 0.08
            let totalW = keyWidth * 3 + hGap * 2
            let totalH = keyHeight * 2 + vGap
            let originX = (canvasSize.width - totalW) / 2
            let originY = (canvasSize.height - totalH) / 2

            for row in 0..<2 {
                for column in 0..<3 {
                    let rect = CGRect(
                        x: originX + CGFloat(column) * (keyWidth + hGap),
                        y: originY + CGFloat(row) * (keyHeight + vGap),
                        width: keyWidth,
                        height: keyHeight
                    )
                    let key = Path(roundedRect: rect, cornerRadius: keyRadius, style: .continuous)
                    context.fill(key, with: .color(row == 1 && column == 2 ? accent : keyColor))
                    context.stroke(key, with: .color(border), lineWidth: 0.5)
                }
            }

            context.stroke(outer, with: .color(Color.primary.opacity(0.12)), lineWidth: 0.5)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
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
