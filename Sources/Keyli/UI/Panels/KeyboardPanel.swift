import SwiftUI
import AppKit

struct DragHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> _DragPassthroughView {
        _DragPassthroughView()
    }
    func updateNSView(_ nsView: _DragPassthroughView, context: Context) {}
}

final class _DragPassthroughView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

public struct FloatingKeyboardContainerView: View {
    @ObservedObject public var state: KeyboardState = .shared
    @ObservedObject public var configStore: ConfigStore = .shared
    public var onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        let theme = state.currentTheme
        let textColor = Color(hex: theme.keycapTextColorHex)

        VStack(spacing: 0) {
            ZStack {
                DragHandleView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 8) {
                    KeyboardChromeButton(
                        systemImage: "xmark",
                        tint: textColor,
                        help: "Close Keyboard",
                        action: onClose
                    )

                    Spacer()

                    KeyboardChromeButton(
                        systemImage: configStore.config.isFloatingPinned ? "pin.fill" : "pin.slash",
                        tint: textColor,
                        help: configStore.config.isFloatingPinned
                            ? "Pinned: stays above other windows. Click to let other windows cover it."
                            : "Not pinned: other windows can cover the keyboard. Click to keep it on top."
                    ) {
                        configStore.config.isFloatingPinned.toggle()
                    }

                    KeyboardChromeMenu(tint: textColor) {
                        KeyboardOptionsMenuItems(showsWindowOptions: true)
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 30)

            KeyboardView(state: state, showStatusBar: true)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyboardBackdrop(theme: theme))
        .ignoresSafeArea()
    }
}
