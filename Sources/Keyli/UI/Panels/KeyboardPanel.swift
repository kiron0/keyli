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
    override func mouseDown(with event: NSEvent) {
        guard let window, window.isMovable else { return }
        window.performDrag(with: event)
    }
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

                    if configStore.config.wordSuggestionsEnabled {
                        SuggestionStrip(theme: theme)
                    }

                    Spacer(minLength: 0)

                    KeyboardChromeButton(
                        systemImage: configStore.config.isFloatingPositionLocked ? "lock.fill" : "lock.open",
                        tint: textColor,
                        help: configStore.config.isFloatingPositionLocked
                            ? "Position locked: the keyboard can't be moved or resized. Click to unlock."
                            : "Lock position: keep the keyboard where it is so it can't be moved or resized by accident."
                    ) {
                        configStore.config.isFloatingPositionLocked.toggle()
                    }

                    KeyboardChromeButton(
                        systemImage: configStore.config.isFloatingPinned ? "macwindow.on.rectangle" : "macwindow",
                        tint: textColor,
                        help: configStore.config.isFloatingPinned
                            ? "Keep on top is on: the keyboard stays above other windows. Click to let windows cover it."
                            : "Keep on top is off: other windows can cover the keyboard. Click to keep it above them."
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
