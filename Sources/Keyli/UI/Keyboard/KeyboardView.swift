import SwiftUI

public struct KeyboardView: View {
    @ObservedObject public var state: KeyboardState
    public var showStatusBar: Bool

    public init(state: KeyboardState = .shared, showStatusBar: Bool = false) {
        self.state = state
        self.showStatusBar = showStatusBar
    }

    public var body: some View {
        let theme  = state.currentTheme
        let layout = state.currentLayout

        VStack(spacing: 6) {
            GeometryReader { geo in
                let spacing = CGFloat(theme.keySpacing)
                let totalW  = geo.size.width
                let totalH  = geo.size.height
                let unitW   = CGFloat(layout.unitWidth)
                let unitH   = CGFloat(layout.unitHeight)

                ZStack(alignment: .topLeading) {
                    ForEach(layout.keys) { key in
                        let x = (CGFloat(key.unitFrame.x) / unitW) * totalW
                        let y = (CGFloat(key.unitFrame.y) / unitH) * totalH
                        let cellW = (CGFloat(key.unitFrame.width)  / unitW) * totalW
                        let cellH = (CGFloat(key.unitFrame.height) / unitH) * totalH
                        let w = max(8, cellW - spacing)
                        let h = max(8, cellH - spacing)

                        KeycapView(key: key, theme: theme, state: state)
                            .frame(width: w, height: h)
                            .position(x: x + cellW / 2, y: y + cellH / 2)
                    }
                }
            }
            .aspectRatio(KeyliConstants.keyboardAspect(layout), contentMode: .fit)

            if showStatusBar {
                ModifierOverlay(state: state, theme: theme)
            }
        }
    }
}
