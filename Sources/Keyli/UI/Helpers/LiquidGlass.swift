import SwiftUI
import AppKit

public struct LiquidGlassBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State
    public var isDark: Bool?

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isDark: Bool? = nil
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.isDark = isDark
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        apply(to: view)
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        if let isDark = isDark {
            view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        } else {
            view.appearance = nil
        }
    }
}

public struct KeyboardBackdrop: View {
    public let theme: KeyboardTheme
    public var cornerRadius: CGFloat

    public init(theme: KeyboardTheme, cornerRadius: CGFloat = 16) {
        self.theme = theme
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = theme.isDarkBackground

        ZStack {
            if theme.backgroundBlur {
                LiquidGlassBackground(
                    material: isDark ? .hudWindow : .popover,
                    blendingMode: .behindWindow,
                    isDark: isDark
                )
            }
            Color(hex: theme.backgroundColorHex)
                .opacity(theme.backgroundOpacity)
        }
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                (isDark ? Color.white : Color.black).opacity(isDark ? 0.14 : 0.10),
                lineWidth: 0.5
            )
        )
    }
}
