import SwiftUI

final class KeycapUIState: ObservableObject {
    @Published var isHovered: Bool = false
    @Published var isLocalPressed: Bool = false

    private var repeatTimer: Timer?

    func startRepeating(_ action: @escaping () -> Void) {
        stopRepeating()
        let delay = max(0.25, NSEvent.keyRepeatDelay)
        let interval = max(0.03, NSEvent.keyRepeatInterval)
        let timer = Timer(fire: Date().addingTimeInterval(delay), interval: interval, repeats: true) { _ in
            action()
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    deinit {
        repeatTimer?.invalidate()
    }
}

public struct KeycapView: View {
    public let key: KeyboardKey
    public let theme: KeyboardTheme
    @ObservedObject public var state: KeyboardState
    @StateObject private var uiState = KeycapUIState()

    public init(key: KeyboardKey, theme: KeyboardTheme, state: KeyboardState) {
        self.key = key
        self.theme = theme
        self.state = state
    }

    private var isPhysicallyPressed: Bool {
        state.isKeyCurrentlyPressed(keyCode: key.keyCode, keyId: key.id)
    }

    private var isModifierActive: Bool {
        guard let mod = key.modifierType else { return false }
        switch mod {
        case .shift:   return state.isShiftActive
        case .option:  return state.isOptionActive
        case .control: return state.isControlActive
        case .command: return state.isCommandActive
        case .capsLock:return state.isCapsLockActive
        case .fn:      return state.isFnActive
        }
    }

    private var isCurrentlyDown: Bool {
        uiState.isLocalPressed || isPhysicallyPressed || isModifierActive
    }

    private var fontDesign: Font.Design {
        switch theme.fontDesign {
        case "monospaced": return .monospaced
        case "rounded":    return .rounded
        case "serif":      return .serif
        default:           return .default
        }
    }

    // True when this key has distinct shift & base labels (like number/symbol keys)
    private var hasDualLabels: Bool {
        guard key.kind == .character else { return false }
        guard let shift = key.labels.shiftLabel, !shift.isEmpty else { return false }
        if shift == key.labels.defaultLabel.uppercased() { return false }
        return shift != key.labels.defaultLabel
    }

    public var body: some View {
        ZStack {
            keycapBackground
            keycapContent
        }
        .scaleEffect(isCurrentlyDown ? 0.96 : 1.0)
        .offset(y: isCurrentlyDown ? 1.5 : 0)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isCurrentlyDown)
        .animation(.easeInOut(duration: 0.08), value: uiState.isHovered)
        .onHover { hovering in uiState.isHovered = hovering }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !uiState.isLocalPressed {
                        uiState.isLocalPressed = true
                        state.virtualPressedKeyId = key.id
                        let issue = KeyboardInputDispatcher.shared.dispatchKey(key, state: state)
                        if issue == nil && isRepeatable {
                            let repeatedKey = key
                            let repeatedState = state
                            uiState.startRepeating {
                                KeyboardInputDispatcher.shared.dispatchKey(repeatedKey, state: repeatedState)
                            }
                        }
                    }
                }
                .onEnded { _ in
                    uiState.stopRepeating()
                    uiState.isLocalPressed = false
                    if state.virtualPressedKeyId == key.id { state.virtualPressedKeyId = nil }
                }
        )
        .onDisappear { uiState.stopRepeating() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isModifierActive ? .isSelected : [])
    }

    private var isRepeatable: Bool {
        guard ConfigStore.shared.config.keyRepeatEnabled else { return false }
        switch key.kind {
        case .character, .navigation:
            return true
        case .system:
            return key.id == "k_delete"
        case .modifier, .function, .spacer:
            return false
        }
    }

    private var accessibilityName: String {
        switch key.id {
        case "k_space": return "space"
        case "k_larrow": return "left arrow"
        case "k_rarrow": return "right arrow"
        case "k_uarrow": return "up arrow"
        case "k_darrow": return "down arrow"
        case "k_esc": return "escape"
        default:
            return key.displayedLabel(
                shift: state.isShiftActive,
                option: state.isOptionActive,
                capsLock: state.isCapsLockActive
            )
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var keycapBackground: some View {
        let base    = Color(hex: key.kind == .modifier ? theme.modifierKeyColorHex : theme.keycapBaseColorHex)
        let active  = Color(hex: theme.keycapActiveColorHex)
        let accent  = Color(hex: theme.accentColorHex)
        let border  = Color(hex: theme.borderColorHex).opacity(theme.borderOpacity)
        let radius  = CGFloat(theme.cornerRadius)

        let fill: Color = {
            if isCurrentlyDown {
                return isModifierActive && !isPhysicallyPressed && !uiState.isLocalPressed
                    ? accent.opacity(0.35) : active
            }
            return uiState.isHovered ? base.opacity(0.85) : base
        }()

        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let strokeColor = isCurrentlyDown ? accent : (uiState.isHovered ? accent.opacity(0.5) : border)
        let elevation = CGFloat(theme.keyElevation)

        switch theme.keycapStyle {
        case .raised:
            ZStack {
                shape
                    .fill(Color.black.opacity(0.35))
                    .offset(y: isCurrentlyDown ? 0 : max(1, elevation * 0.8))
                shape
                    .fill(fill)
                    .overlay(
                        shape.fill(
                            LinearGradient(
                                colors: [Color.white.opacity(isCurrentlyDown ? 0.0 : 0.10), Color.black.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )
                    .overlay(shape.strokeBorder(strokeColor, lineWidth: CGFloat(theme.borderWidth)))
            }
            .shadow(
                color: Color.black.opacity(isCurrentlyDown ? 0.05 : 0.3),
                radius: isCurrentlyDown ? 0.5 : elevation,
                x: 0,
                y: isCurrentlyDown ? 0.5 : elevation * 0.65
            )

        case .flat:
            shape
                .fill(fill)
                .overlay(shape.strokeBorder(strokeColor, lineWidth: CGFloat(theme.borderWidth)))

        case .glass:
            shape
                .fill(isCurrentlyDown ? fill.opacity(0.55) : fill.opacity(uiState.isHovered ? 0.26 : 0.18))
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(0.5, CGFloat(theme.borderWidth))
                    )
                )
                .overlay(shape.strokeBorder(isCurrentlyDown ? accent : Color.clear, lineWidth: CGFloat(theme.borderWidth)))

        case .chicklet:
            shape
                .fill(fill)
                .overlay(shape.strokeBorder(strokeColor, lineWidth: CGFloat(theme.borderWidth)))
                .shadow(
                    color: Color.black.opacity(isCurrentlyDown ? 0.04 : (theme.keyElevation > 0 ? 0.22 : 0)),
                    radius: isCurrentlyDown ? 0.5 : elevation * 0.8,
                    x: 0,
                    y: isCurrentlyDown ? 0.5 : elevation * 0.5
                )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var keycapContent: some View {
        let baseText   = Color(hex: theme.keycapTextColorHex)
        let showsAccentTint = isModifierActive && !isPhysicallyPressed && !uiState.isLocalPressed
        let activeText = showsAccentTint ? baseText : Color(hex: theme.activeTextColorHex)
        let textColor  = isCurrentlyDown ? activeText : baseText

        if hasDualLabels {
            // macOS Keyboard Viewer style: shift-label top-left, base-label bottom-right
            dualLabelContent(textColor: textColor)
        } else {
            singleLabelContent(textColor: textColor)
        }
    }

    /// Two labels stacked like macOS Keyboard Viewer — shift char top-left, base char bottom
    @ViewBuilder
    private func dualLabelContent(textColor: Color) -> some View {
        let baseLabel  = key.labels.defaultLabel
        let shiftLabel = key.labels.shiftLabel ?? ""
        let accent     = Color(hex: theme.accentColorHex)

        // Highlight shift label when shift is active
        let shiftColor = state.isShiftActive
            ? (isCurrentlyDown ? accent : accent.opacity(0.85))
            : textColor.opacity(0.55)
        let baseColor  = (!state.isShiftActive || isCurrentlyDown) ? textColor : textColor.opacity(0.55)

        GeometryReader { geo in
            let sz = min(geo.size.width, geo.size.height)
            let shiftSz = sz * 0.34
            let baseSz  = sz * 0.44

            ZStack(alignment: .topLeading) {
                // Shift label — top-left
                Text(shiftLabel)
                    .font(.system(size: shiftSz, weight: .semibold, design: fontDesign))
                    .foregroundColor(shiftColor)
                    .lineLimit(1)
                    .padding(.leading, geo.size.width * 0.12)
                    .padding(.top,     geo.size.height * 0.1)

                // Base label — bottom-center
                Text(baseLabel)
                    .font(.system(size: baseSz, weight: .semibold, design: fontDesign))
                    .foregroundColor(baseColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, geo.size.width * 0.12)
                    .padding(.bottom,   geo.size.height * 0.1)
            }
        }
        .padding(2)
    }

    /// Single centered label — letters, modifiers, specials
    @ViewBuilder
    private func singleLabelContent(textColor: Color) -> some View {
        GeometryReader { geo in
            let sz = min(geo.size.width, geo.size.height)

            ZStack {
                switch key.id {
                case "k_lcmd", "k_rcmd":
                    cmdKeyContent(geo: geo, sz: sz, textColor: textColor)
                case "k_lopt", "k_ropt":
                    labelWithGlyph(glyph: "⌥", sub: "option", geo: geo, sz: sz, textColor: textColor)
                case "k_lctrl":
                    labelWithGlyph(glyph: "⌃", sub: "control", geo: geo, sz: sz, textColor: textColor)
                case "k_lshift", "k_rshift":
                    shiftContent(geo: geo, sz: sz, textColor: textColor)
                case "k_caps":
                    capsContent(geo: geo, sz: sz, textColor: textColor)
                case "k_tab":
                    tabContent(geo: geo, sz: sz, textColor: textColor)
                case "k_return":
                    returnContent(geo: geo, sz: sz, textColor: textColor)
                case "k_delete":
                    deleteContent(geo: geo, sz: sz, textColor: textColor)
                case "k_fn":
                    fnContent(geo: geo, sz: sz, textColor: textColor)
                case "k_lock":
                    Image(systemName: "lock.fill")
                        .font(.system(size: sz * 0.42, weight: .semibold))
                        .foregroundColor(textColor)
                case "k_space":
                    EmptyView() // space bar blank
                default:
                    defaultContent(geo: geo, sz: sz, textColor: textColor)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Special key layouts (macOS Keyboard Viewer style)

    @ViewBuilder
    private func cmdKeyContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        let fontSize = sz * 0.55
        VStack(spacing: 0) {
            Text("⌘")
                .font(.system(size: fontSize, weight: .semibold))
            Text("command")
                .font(.system(size: sz * 0.24, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundColor(textColor)
    }

    @ViewBuilder
    private func labelWithGlyph(glyph: String, sub: String, geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        let fontSize = sz * 0.5
        VStack(spacing: 0) {
            Text(glyph)
                .font(.system(size: fontSize, weight: .semibold))
            Text(sub)
                .font(.system(size: sz * 0.22, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundColor(textColor)
    }

    @ViewBuilder
    private func shiftContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        HStack(spacing: sz * 0.1) {
            Image(systemName: "shift.fill")
                .font(.system(size: sz * 0.45, weight: .semibold))
            Text("shift")
                .font(.system(size: sz * 0.24, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(textColor)
    }

    @ViewBuilder
    private func capsContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        HStack(spacing: sz * 0.08) {
            Image(systemName: "capslock.fill")
                .font(.system(size: sz * 0.4, weight: .semibold))
            Text("caps lock")
                .font(.system(size: sz * 0.22, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundColor(textColor)
        // LED indicator dot (top-left when caps lock active)
        .overlay(alignment: .topLeading) {
            if state.isCapsLockActive {
                Circle()
                    .fill(Color(hex: theme.accentColorHex))
                    .frame(width: sz * 0.15, height: sz * 0.15)
                    .padding(sz * 0.1)
            }
        }
    }

    @ViewBuilder
    private func tabContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        HStack(spacing: sz * 0.08) {
            Text("tab")
                .font(.system(size: sz * 0.24, weight: .medium))
            Image(systemName: "arrow.right.to.line.compact")
                .font(.system(size: sz * 0.38, weight: .semibold))
        }
        .foregroundColor(textColor)
    }

    @ViewBuilder
    private func returnContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        HStack(spacing: sz * 0.08) {
            Text("return")
                .font(.system(size: sz * 0.24, weight: .medium))
            Image(systemName: "return")
                .font(.system(size: sz * 0.38, weight: .semibold))
        }
        .foregroundColor(textColor)
    }

    @ViewBuilder
    private func deleteContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        HStack(spacing: sz * 0.08) {
            Text("delete")
                .font(.system(size: sz * 0.24, weight: .medium))
            Image(systemName: "delete.left.fill")
                .font(.system(size: sz * 0.38, weight: .semibold))
        }
        .foregroundColor(textColor)
    }

    @ViewBuilder
    private func fnContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        VStack(spacing: 1) {
            Image(systemName: "globe")
                .font(.system(size: sz * 0.38, weight: .semibold))
            Text("fn")
                .font(.system(size: sz * 0.22, weight: .medium))
        }
        .foregroundColor(textColor)
    }

    @ViewBuilder
    private func defaultContent(geo: GeometryProxy, sz: Double, textColor: Color) -> some View {
        if let icon = key.symbolIcon, key.kind != .character {
            // F-keys / navigation with SF symbol
            if key.kind == .function {
                HStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: sz * 0.40, weight: .semibold))
                        .opacity(state.isFnActive ? 0.45 : 1.0)
                        .frame(maxWidth: .infinity)
                    Text(key.labels.defaultLabel)
                        .font(.system(size: sz * 0.26, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .opacity(state.isFnActive ? 1.0 : 0.55)
                        .padding(.trailing, sz * 0.18)
                }
                .foregroundColor(textColor)
            } else {
                Image(systemName: icon)
                    .font(.system(size: sz * 0.42, weight: .semibold))
                    .foregroundColor(textColor)
            }
        } else {
            // Simple label (letters, esc, etc.)
            let label = key.displayedLabel(
                shift: state.isShiftActive,
                option: state.isOptionActive,
                capsLock: state.isCapsLockActive
            )
            Text(label)
                .font(.system(
                    size: sz * (label.count > 2 ? 0.28 : 0.55),
                    weight: .semibold,
                    design: fontDesign
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(textColor)
        }
    }
}
