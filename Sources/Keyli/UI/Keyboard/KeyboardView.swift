import SwiftUI
import AppKit

final class KeyboardInteractionState: ObservableObject {
    @Published var hoveredKeyId: String?
    @Published var pressedKeyId: String?
    var pressBegan: Date?
    var pressStart: CGPoint?

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

public struct KeyboardGeometry {
    public let layout: KeyboardLayout
    public let size: CGSize
    public let spacing: CGFloat

    public init(layout: KeyboardLayout, size: CGSize, spacing: CGFloat) {
        self.layout = layout
        self.size = size
        self.spacing = spacing
    }

    public func frame(for key: KeyboardKey) -> CGRect {
        let unitW = CGFloat(layout.unitWidth)
        let unitH = CGFloat(layout.unitHeight)
        let x = (CGFloat(key.unitFrame.x) / unitW) * size.width
        let y = (CGFloat(key.unitFrame.y) / unitH) * size.height
        let cellW = (CGFloat(key.unitFrame.width) / unitW) * size.width
        let cellH = (CGFloat(key.unitFrame.height) / unitH) * size.height
        let w = max(8, cellW - spacing)
        let h = max(8, cellH - spacing)
        return CGRect(x: x + (cellW - w) / 2, y: y + (cellH - h) / 2, width: w, height: h)
    }

    public func key(at point: CGPoint) -> KeyboardKey? {
        layout.keys.first { frame(for: $0).contains(point) }
    }
}

public struct KeyboardView: View {
    @ObservedObject public var state: KeyboardState
    @ObservedObject private var presses: KeyPressState
    @StateObject private var interaction = KeyboardInteractionState()
    public var showStatusBar: Bool
    public var isInteractive: Bool

    public init(state: KeyboardState = .shared, showStatusBar: Bool = false, isInteractive: Bool = true) {
        self.state = state
        self.presses = state.presses
        self.showStatusBar = showStatusBar
        self.isInteractive = isInteractive
    }

    public var body: some View {
        let theme = state.currentTheme
        let layout = state.currentLayout

        VStack(spacing: 6) {
            GeometryReader { geo in
                let geometry = KeyboardGeometry(layout: layout, size: geo.size, spacing: CGFloat(theme.keySpacing))
                let renderer = KeyboardRenderer(
                    theme: theme,
                    modifiers: state.modifierSnapshot,
                    physicalKeyCodes: presses.physicalKeyCodes,
                    virtualKeyId: presses.virtualKeyId,
                    localPressedKeyId: interaction.pressedKeyId,
                    hoveredKeyId: isInteractive ? interaction.hoveredKeyId : nil
                )

                Canvas { context, _ in
                    for key in layout.keys {
                        renderer.draw(key: key, in: geometry.frame(for: key), context: context)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if interaction.pressedKeyId != nil, interaction.pressStart != value.startLocation {
                                end()
                            }
                            if interaction.pressedKeyId == nil, let key = geometry.key(at: value.startLocation) {
                                interaction.pressStart = value.startLocation
                                begin(key)
                            }
                        }
                        .onEnded { _ in
                            end()
                        }
                )
                .onContinuousHover(coordinateSpace: .local) { phase in
                    guard isInteractive else { return }
                    switch phase {
                    case .active(let point):
                        let id = geometry.key(at: point)?.id
                        if interaction.hoveredKeyId != id {
                            interaction.hoveredKeyId = id
                        }
                    case .ended:
                        if interaction.hoveredKeyId != nil {
                            interaction.hoveredKeyId = nil
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Keyboard")
                .accessibilityChildren {
                    ZStack(alignment: .topLeading) {
                        ForEach(layout.keys) { key in
                            let frame = geometry.frame(for: key)
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                                .accessibilityLabel(accessibilityName(for: key))
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction {
                                    if isInteractive {
                                        KeySoundEngine.shared.tap(key.keyCode)
                                        KeyboardInputDispatcher.shared.dispatchKey(key, state: state)
                                    }
                                }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .aspectRatio(KeyliConstants.keyboardAspect(layout), contentMode: .fit)

            if showStatusBar {
                ModifierOverlay(state: state, theme: theme)
            }
        }
        .onDisappear {
            interaction.stopRepeating()
            KeySoundEngine.shared.releaseAll(source: .onScreen)
        }
    }

    private func begin(_ key: KeyboardKey) {
        interaction.pressedKeyId = key.id
        interaction.pressBegan = Date()
        guard isInteractive else { return }
        KeySoundEngine.shared.keyDown(key.keyCode, source: .onScreen)
        if key.modifierType == .fn {
            return
        }
        state.virtualPressedKeyId = key.id
        let repeatState = state.detachedCopy()
        let issue = KeyboardInputDispatcher.shared.dispatchKey(key, state: state)
        if issue == nil && isRepeatable(key) {
            interaction.startRepeating { [weak interaction] in
                guard NSEvent.pressedMouseButtons & 1 != 0 else {
                    interaction?.stopRepeating()
                    return
                }
                KeyboardInputDispatcher.shared.dispatchKey(key, state: repeatState)
            }
        }
    }

    private func end() {
        interaction.stopRepeating()
        let pressedKey = isInteractive ? interaction.pressedKeyId.flatMap { id in state.currentLayout.keys.first { $0.id == id } } : nil
        if let pressedKey {
            KeySoundEngine.shared.keyUp(pressedKey.keyCode, source: .onScreen)
        }
        if let key = pressedKey, key.modifierType == .fn {
            let held = Date().timeIntervalSince(interaction.pressBegan ?? Date())
            if held >= KeyboardView.fnLatchHoldDuration || state.isFnActive {
                state.toggleModifier(.fn)
            } else {
                KeyboardInputDispatcher.shared.handleGlobeTap(state: state)
            }
        }
        if let id = interaction.pressedKeyId, state.virtualPressedKeyId == id {
            state.virtualPressedKeyId = nil
        }
        interaction.pressedKeyId = nil
        interaction.pressStart = nil
    }

    static let fnLatchHoldDuration: TimeInterval = 0.4

    private func isRepeatable(_ key: KeyboardKey) -> Bool {
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

    private func accessibilityName(for key: KeyboardKey) -> String {
        switch key.id {
        case "k_space": return "space"
        case "k_larrow": return "left arrow"
        case "k_rarrow": return "right arrow"
        case "k_uarrow": return "up arrow"
        case "k_darrow": return "down arrow"
        case "k_esc": return "escape"
        case "k_lock": return "lock screen"
        default:
            let modifiers = state.modifierSnapshot
            return key.displayedLabel(shift: modifiers.shift, option: modifiers.option, capsLock: modifiers.capsLock)
        }
    }
}

struct KeyboardRenderer {
    let theme: KeyboardTheme
    let modifiers: KeyModifierSnapshot
    let physicalKeyCodes: Set<UInt16>
    let virtualKeyId: String?
    let localPressedKeyId: String?
    let hoveredKeyId: String?

    private let keycapColor: Color
    private let modifierColor: Color
    private let activeColor: Color
    private let accentColor: Color
    private let borderColor: Color
    private let textColor: Color
    private let activeTextColor: Color
    private let keycapIsDark: Bool
    private let modifierIsDark: Bool

    init(
        theme: KeyboardTheme,
        modifiers: KeyModifierSnapshot,
        physicalKeyCodes: Set<UInt16>,
        virtualKeyId: String?,
        localPressedKeyId: String?,
        hoveredKeyId: String?
    ) {
        self.theme = theme
        self.modifiers = modifiers
        self.physicalKeyCodes = physicalKeyCodes
        self.virtualKeyId = virtualKeyId
        self.localPressedKeyId = localPressedKeyId
        self.hoveredKeyId = hoveredKeyId
        self.keycapColor = Color(hex: theme.keycapBaseColorHex)
        self.modifierColor = Color(hex: theme.modifierKeyColorHex)
        self.activeColor = Color(hex: theme.keycapActiveColorHex)
        self.accentColor = Color(hex: theme.accentColorHex)
        self.borderColor = Color(hex: theme.borderColorHex).opacity(theme.borderOpacity)
        self.textColor = Color(hex: theme.keycapTextColorHex)
        self.activeTextColor = Color(hex: theme.activeTextColorHex)
        self.keycapIsDark = theme.keycapStyle == .fluent && KeyboardTheme.relativeLuminance(hex: theme.keycapBaseColorHex) < 0.4
        self.modifierIsDark = theme.keycapStyle == .fluent && KeyboardTheme.relativeLuminance(hex: theme.modifierKeyColorHex) < 0.4
    }

    private var fontDesign: Font.Design {
        switch theme.fontDesign {
        case "monospaced": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return .default
        }
    }

    private func isModifierActive(_ key: KeyboardKey) -> Bool {
        guard let mod = key.modifierType else { return false }
        switch mod {
        case .shift: return modifiers.shift
        case .option: return modifiers.option
        case .control: return modifiers.control
        case .command: return modifiers.command
        case .capsLock: return modifiers.capsLock
        case .fn: return modifiers.fn
        }
    }

    func draw(key: KeyboardKey, in baseRect: CGRect, context: GraphicsContext) {
        let isLocalPressed = localPressedKeyId == key.id
        let isPhysicallyPressed = virtualKeyId == key.id || physicalKeyCodes.contains(key.keyCode)
        let modifierActive = isModifierActive(key)
        let isDown = isLocalPressed || isPhysicallyPressed || modifierActive
        let isHovered = hoveredKeyId == key.id
        let showsAccentTint = modifierActive && !isPhysicallyPressed && !isLocalPressed

        var rect = baseRect
        if isDown {
            rect = rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.02).offsetBy(dx: 0, dy: 1.5)
        }

        drawBackground(key: key, rect: rect, isDown: isDown, isHovered: isHovered, showsAccentTint: showsAccentTint, context: context)

        let labelColor = isDown ? (showsAccentTint ? textColor : activeTextColor) : textColor
        drawLabel(key: key, rect: rect, isDown: isDown, textColor: labelColor, context: context)
    }

    private func drawBackground(key: KeyboardKey, rect: CGRect, isDown: Bool, isHovered: Bool, showsAccentTint: Bool, context: GraphicsContext) {
        let base = key.kind == .modifier ? modifierColor : keycapColor
        let active = activeColor
        let accent = accentColor
        let border = borderColor
        let radius = min(CGFloat(theme.cornerRadius), min(rect.width, rect.height) / 2)
        let lineWidth = CGFloat(theme.borderWidth)
        let elevation = CGFloat(theme.keyElevation)

        let fill: Color = isDown ? (showsAccentTint ? accent.opacity(0.35) : active) : (isHovered ? base.opacity(0.85) : base)
        let strokeColor = isDown ? accent : (isHovered ? accent.opacity(0.5) : border)

        let shape = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)

        func strokeBorder(_ shading: GraphicsContext.Shading, width: CGFloat) {
            guard width > 0 else { return }
            let inset = rect.insetBy(dx: width / 2, dy: width / 2)
            let path = Path(roundedRect: inset, cornerRadius: max(0, radius - width / 2), style: .continuous)
            context.stroke(path, with: shading, lineWidth: width)
        }

        switch theme.keycapStyle {
        case .raised:
            let plate = Path(roundedRect: rect.offsetBy(dx: 0, dy: isDown ? 0 : max(1, elevation * 0.8)), cornerRadius: radius, style: .continuous)
            context.fill(plate, with: .color(Color.black.opacity(0.35)))
            context.fill(shape, with: .color(fill))
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(isDown ? 0 : 0.10), Color.black.opacity(0.10)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ))
            strokeBorder(.color(strokeColor), width: lineWidth)

        case .flat:
            context.fill(shape, with: .color(fill))
            strokeBorder(.color(strokeColor), width: lineWidth)

        case .glass:
            context.fill(shape, with: .color(isDown ? fill.opacity(0.55) : fill.opacity(isHovered ? 0.26 : 0.18)))
            strokeBorder(.linearGradient(
                Gradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ), width: max(0.5, lineWidth))
            if isDown {
                strokeBorder(.color(accent), width: lineWidth)
            }

        case .fluent:
            let isDarkSurface = key.kind == .modifier ? modifierIsDark : keycapIsDark
            let restFill: Color = isHovered
                ? (isDarkSurface ? base.opacity(0.82) : base.opacity(0.7))
                : base
            context.fill(shape, with: .color(isDown ? fill : restFill))
            let borderTop = borderColor
            let borderBottom = isDarkSurface ? Color.white.opacity(theme.borderOpacity * 0.55) : Color.black.opacity(min(1, theme.borderOpacity * 2.6))
            strokeBorder(.linearGradient(
                Gradient(stops: [
                    .init(color: borderTop, location: 0),
                    .init(color: borderTop, location: 0.9),
                    .init(color: borderBottom, location: 1)
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ), width: max(1, lineWidth))

        case .chicklet:
            if elevation > 0 {
                let plate = Path(roundedRect: rect.offsetBy(dx: 0, dy: isDown ? 0.5 : max(0.5, elevation * 0.6)), cornerRadius: radius, style: .continuous)
                context.fill(plate, with: .color(Color.black.opacity(isDown ? 0.06 : 0.22)))
            }
            context.fill(shape, with: .color(fill))
            strokeBorder(.color(strokeColor), width: lineWidth)
        }
    }

    private func text(_ string: String, size: CGFloat, weight: Font.Weight, design: Font.Design = .default, color: Color) -> Text {
        Text(string)
            .font(.system(size: max(1, size), weight: weight, design: design))
            .foregroundColor(color)
    }

    private func symbol(_ name: String, size: CGFloat, weight: Font.Weight, color: Color) -> Text {
        Text(Image(systemName: name))
            .font(.system(size: max(1, size), weight: weight))
            .foregroundColor(color)
    }

    private func fitted(
        _ string: String,
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design = .default,
        color: Color,
        maxWidth: CGFloat,
        minScale: CGFloat,
        context: GraphicsContext
    ) -> (GraphicsContext.ResolvedText, CGSize) {
        var resolved = context.resolve(text(string, size: size, weight: weight, design: design, color: color))
        var measured = resolved.measure(in: CGSize(width: 10_000, height: 10_000))
        if measured.width > maxWidth, measured.width > 0 {
            let scale = max(minScale, maxWidth / measured.width)
            resolved = context.resolve(text(string, size: size * scale, weight: weight, design: design, color: color))
            measured = resolved.measure(in: CGSize(width: 10_000, height: 10_000))
        }
        return (resolved, measured)
    }

    private func drawRow(_ items: [(GraphicsContext.ResolvedText, CGSize)], spacing: CGFloat, center: CGPoint, context: GraphicsContext) {
        let total = items.map { $0.1.width }.reduce(0, +) + spacing * CGFloat(max(0, items.count - 1))
        var x = center.x - total / 2
        for (resolved, size) in items {
            context.draw(resolved, at: CGPoint(x: x + size.width / 2, y: center.y), anchor: .center)
            x += size.width + spacing
        }
    }

    private func drawColumn(_ items: [(GraphicsContext.ResolvedText, CGSize)], spacing: CGFloat, center: CGPoint, context: GraphicsContext) {
        let total = items.map { $0.1.height }.reduce(0, +) + spacing * CGFloat(max(0, items.count - 1))
        var y = center.y - total / 2
        for (resolved, size) in items {
            context.draw(resolved, at: CGPoint(x: center.x, y: y + size.height / 2), anchor: .center)
            y += size.height + spacing
        }
    }

    private func measured(_ text: Text, context: GraphicsContext) -> (GraphicsContext.ResolvedText, CGSize) {
        let resolved = context.resolve(text)
        return (resolved, resolved.measure(in: CGSize(width: 10_000, height: 10_000)))
    }

    private func hasDualLabels(_ key: KeyboardKey) -> Bool {
        guard key.kind == .character else { return false }
        guard let shift = key.labels.shiftLabel, !shift.isEmpty else { return false }
        if shift == key.labels.defaultLabel.uppercased() { return false }
        return shift != key.labels.defaultLabel
    }

    private func drawLabel(key: KeyboardKey, rect: CGRect, isDown: Bool, textColor: Color, context: GraphicsContext) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxWidth = rect.width * 0.9

        if hasDualLabels(key) {
            let inner = rect.insetBy(dx: 2, dy: 2)
            let sz = min(inner.width, inner.height)
            let accent = accentColor
            let shiftColor = modifiers.shift ? (isDown ? accent : accent.opacity(0.85)) : textColor.opacity(0.55)
            let baseColor = (!modifiers.shift || isDown) ? textColor : textColor.opacity(0.55)

            let top = context.resolve(text(key.labels.shiftLabel ?? "", size: sz * 0.34, weight: .semibold, design: fontDesign, color: shiftColor))
            context.draw(top, at: CGPoint(x: inner.minX + inner.width * 0.12, y: inner.minY + inner.height * 0.1), anchor: .topLeading)

            let bottom = context.resolve(text(key.labels.defaultLabel, size: sz * 0.44, weight: .semibold, design: fontDesign, color: baseColor))
            context.draw(bottom, at: CGPoint(x: inner.maxX - inner.width * 0.12, y: inner.maxY - inner.height * 0.1), anchor: .bottomTrailing)
            return
        }

        let sz = min(rect.width, rect.height)

        switch key.id {
        case "k_lcmd", "k_rcmd":
            drawColumn([
                measured(text("⌘", size: sz * 0.55, weight: .semibold, color: textColor), context: context),
                fitted("command", size: sz * 0.24, weight: .medium, color: textColor, maxWidth: maxWidth, minScale: 0.6, context: context)
            ], spacing: 0, center: center, context: context)

        case "k_lopt", "k_ropt":
            drawColumn([
                measured(text("⌥", size: sz * 0.5, weight: .semibold, color: textColor), context: context),
                fitted("option", size: sz * 0.22, weight: .medium, color: textColor, maxWidth: maxWidth, minScale: 0.6, context: context)
            ], spacing: 0, center: center, context: context)

        case "k_lctrl":
            drawColumn([
                measured(text("⌃", size: sz * 0.5, weight: .semibold, color: textColor), context: context),
                fitted("control", size: sz * 0.22, weight: .medium, color: textColor, maxWidth: maxWidth, minScale: 0.6, context: context)
            ], spacing: 0, center: center, context: context)

        case "k_lshift", "k_rshift":
            drawRow([
                measured(symbol("shift.fill", size: sz * 0.45, weight: .semibold, color: textColor), context: context),
                measured(text("shift", size: sz * 0.24, weight: .medium, color: textColor), context: context)
            ], spacing: sz * 0.1, center: center, context: context)

        case "k_caps":
            drawRow([
                measured(symbol("capslock.fill", size: sz * 0.4, weight: .semibold, color: textColor), context: context),
                fitted("caps lock", size: sz * 0.22, weight: .medium, color: textColor, maxWidth: maxWidth * 0.7, minScale: 0.6, context: context)
            ], spacing: sz * 0.08, center: center, context: context)
            if modifiers.capsLock {
                let dot = sz * 0.15
                let led = CGRect(x: rect.minX + sz * 0.15, y: rect.minY + sz * 0.15, width: dot, height: dot)
                context.fill(Path(ellipseIn: led), with: .color(accentColor))
            }

        case "k_tab":
            drawRow([
                measured(text("tab", size: sz * 0.24, weight: .medium, color: textColor), context: context),
                measured(symbol("arrow.right.to.line.compact", size: sz * 0.38, weight: .semibold, color: textColor), context: context)
            ], spacing: sz * 0.08, center: center, context: context)

        case "k_return":
            drawRow([
                measured(text("return", size: sz * 0.24, weight: .medium, color: textColor), context: context),
                measured(symbol("return", size: sz * 0.38, weight: .semibold, color: textColor), context: context)
            ], spacing: sz * 0.08, center: center, context: context)

        case "k_delete":
            drawRow([
                measured(text("delete", size: sz * 0.24, weight: .medium, color: textColor), context: context),
                measured(symbol("delete.left.fill", size: sz * 0.38, weight: .semibold, color: textColor), context: context)
            ], spacing: sz * 0.08, center: center, context: context)

        case "k_fn":
            drawColumn([
                measured(symbol("globe", size: sz * 0.38, weight: .semibold, color: textColor), context: context),
                measured(text("fn", size: sz * 0.22, weight: .medium, color: textColor), context: context)
            ], spacing: 1, center: center, context: context)

        case "k_lock":
            context.draw(context.resolve(symbol("lock.fill", size: sz * 0.42, weight: .semibold, color: textColor)), at: center, anchor: .center)

        case "k_space":
            break

        default:
            if let icon = key.symbolIcon, key.kind != .character {
                if key.kind == .function {
                    let label = context.resolve(text(key.labels.defaultLabel, size: sz * 0.26, weight: .medium, color: textColor.opacity(modifiers.fn ? 1.0 : 0.55)))
                    let labelSize = label.measure(in: CGSize(width: 10_000, height: 10_000))
                    let trailing = sz * 0.18
                    context.draw(label, at: CGPoint(x: rect.maxX - trailing, y: center.y), anchor: .trailing)
                    let iconAreaWidth = max(0, rect.width - labelSize.width - trailing)
                    let iconText = context.resolve(symbol(icon, size: sz * 0.40, weight: .semibold, color: textColor.opacity(modifiers.fn ? 0.45 : 1.0)))
                    context.draw(iconText, at: CGPoint(x: rect.minX + iconAreaWidth / 2, y: center.y), anchor: .center)
                } else {
                    context.draw(context.resolve(symbol(icon, size: sz * 0.42, weight: .semibold, color: textColor)), at: center, anchor: .center)
                }
            } else {
                let label = key.displayedLabel(shift: modifiers.shift, option: modifiers.option, capsLock: modifiers.capsLock)
                let (resolved, _) = fitted(
                    label,
                    size: sz * (label.count > 2 ? 0.28 : 0.55),
                    weight: .semibold,
                    design: fontDesign,
                    color: textColor,
                    maxWidth: maxWidth,
                    minScale: 0.5,
                    context: context
                )
                context.draw(resolved, at: center, anchor: .center)
            }
        }
    }
}
