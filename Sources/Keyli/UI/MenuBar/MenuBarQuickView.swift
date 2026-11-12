import SwiftUI

public struct MenuBarQuickView: View {
    @ObservedObject public var state: KeyboardState = .shared
    public var onDetach: () -> Void

    public init(onDetach: @escaping () -> Void) {
        self.onDetach = onDetach
    }

    public var body: some View {
        let theme = state.currentTheme
        let textColor = Color(hex: theme.keycapTextColorHex)

        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Text("Keyboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textColor.opacity(0.75))

                Spacer()

                // Detach to Floating Window Button
                KeyboardChromeButton(
                    systemImage: "macwindow.on.rectangle",
                    tint: textColor,
                    help: "Open Floating Keyboard",
                    action: onDetach
                )

                KeyboardChromeMenu(tint: textColor) {
                    KeyboardOptionsMenuItems(showsWindowOptions: false)
                    Divider()
                    Button("Quit Keyli") {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 30)

            // Keyboard Renderer
            KeyboardView(state: state, showStatusBar: true)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyboardBackdrop(theme: theme))
        .ignoresSafeArea()
    }
}
