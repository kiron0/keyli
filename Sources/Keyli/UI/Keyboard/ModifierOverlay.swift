import SwiftUI

public struct ModifierOverlay: View {
    @ObservedObject public var state: KeyboardState
    public let theme: KeyboardTheme

    public init(state: KeyboardState, theme: KeyboardTheme) {
        self.state = state
        self.theme = theme
    }

    public var body: some View {
        let text = theme.chromeTextColor

        HStack(spacing: 8) {
            if let issue = state.dispatchIssue {
                issueView(issue, text: text)
            } else {
                targetView(text: text)
            }

            Spacer(minLength: 8)

            if !state.lockedModifiers.isEmpty {
                let locked = ModifierLatch.lockable.filter { state.lockedModifiers.contains($0) }
                Button {
                    state.releaseAllModifiers()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text(locked.map(ModifierLatch.symbol).joined())
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(text)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Capsule().fill(Color(hex: theme.accentColorHex).opacity(0.3)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Locked: \(locked.map(ModifierLatch.name).joined(separator: ", ")). Click to unlock.")
                .accessibilityLabel("Locked \(locked.map(ModifierLatch.name).joined(separator: ", ")). Unlock")
            }

            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 10))
                Text(state.currentLayout.inputSourceName ?? "US")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(text.opacity(0.6))
        }
        .frame(height: 20)
        .animation(.easeInOut(duration: 0.15), value: state.dispatchIssue)
    }

    @ViewBuilder
    private func targetView(text: Color) -> some View {
        HStack(spacing: 5) {
            if let icon = state.targetAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 11))
            }
            Text(state.targetAppName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(text.opacity(0.6))
        .help("Keys are typed into this app")
    }

    @ViewBuilder
    private func issueView(_ issue: KeyDispatchIssue, text: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.orange)

            switch issue {
            case .missingPermission:
                Text("Keyli needs Accessibility access to type.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(text)
                Button("Allow…") {
                    PermissionsManager.shared.requestAccessibility()
                }
                .controlSize(.small)
            case .secureInput:
                Text("Secure input is active. Typing is paused.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(text)
            case .noTarget:
                Text("Click into another app, then type here.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(text)
            }
        }
        .lineLimit(1)
    }
}
