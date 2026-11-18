import SwiftUI
import AppKit

public struct DwellTracker {
    public private(set) var keyId: String?
    public private(set) var startedAt: TimeInterval = 0
    public private(set) var firedKeyId: String?

    public init() {}

    public mutating func hover(_ id: String?, at now: TimeInterval) {
        guard id != keyId else { return }
        keyId = id
        startedAt = now
        if id != firedKeyId {
            firedKeyId = nil
        }
    }

    public func progress(at now: TimeInterval, duration: TimeInterval) -> Double {
        guard keyId != nil, keyId != firedKeyId, duration > 0 else { return 0 }
        return min(1, max(0, (now - startedAt) / duration))
    }

    public mutating func tick(at now: TimeInterval, duration: TimeInterval) -> String? {
        guard let keyId, keyId != firedKeyId, progress(at: now, duration: duration) >= 1 else { return nil }
        firedKeyId = keyId
        return keyId
    }
}

final class KeyboardInteractionState: ObservableObject {
    @Published var dwellKeyId: String?
    @Published var dwellProgress: Double = 0
    var dwell = DwellTracker()
    private var dwellTimer: Timer?

    func updateDwell(hovered id: String?, enabled: Bool, duration: TimeInterval, fire: @escaping (String) -> Void) {
        guard enabled else {
            stopDwell()
            return
        }
        dwell.hover(id, at: ProcessInfo.processInfo.systemUptime)
        dwellKeyId = id
        dwellProgress = 0
        guard id != nil, dwellTimer == nil else {
            if id == nil { stopDwell() }
            return
        }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let progress = self.dwell.progress(at: now, duration: duration)
            if abs(progress - self.dwellProgress) > 0.01 || (progress == 0 && self.dwellProgress != 0) {
                self.dwellProgress = progress
            }
            if let fired = self.dwell.tick(at: now, duration: duration) {
                self.dwellProgress = 0
                fire(fired)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        dwellTimer = timer
    }

    func stopDwell() {
        dwellTimer?.invalidate()
        dwellTimer = nil
        dwell = DwellTracker()
        if dwellKeyId != nil { dwellKeyId = nil }
        if dwellProgress != 0 { dwellProgress = 0 }
    }

    @Published var hoveredKeyId: String?
    @Published var pressedKeyId: String?
    var pressBegan: Date?
    var pressStart: CGPoint?

    @Published var swipePoints: [CGPoint] = []
    var swipeLetters: [Character] = []
    var swipeCenters: [Character: CGPoint] = [:]
    var swipeKeySize: CGFloat = 0
    var isSwiping = false
    var swipeNeedsSpace = false
    var swipeFirstTyped: String?

    func resetSwipe() {
        isSwiping = false
        swipeLetters = []
        swipeCenters = [:]
        if !swipePoints.isEmpty { swipePoints = [] }
    }

    @Published var accentPopup: AccentPopup?
    var consumedPressStart: CGPoint?
    private var accentTimer: Timer?

    func scheduleAccentPopup(_ action: @escaping () -> Void) {
        cancelAccentTimer()
        let delay = max(0.35, NSEvent.keyRepeatDelay)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.accentTimer = nil
            action()
        }
        RunLoop.main.add(timer, forMode: .common)
        accentTimer = timer
    }

    func cancelAccentTimer() {
        accentTimer?.invalidate()
        accentTimer = nil
    }

    private var modifierHoldTimer: Timer?

    func scheduleModifierHold(_ action: @escaping () -> Void) {
        cancelModifierHold()
        let timer = Timer(timeInterval: ModifierLatch.holdToLock, repeats: false) { [weak self] _ in
            self?.modifierHoldTimer = nil
            action()
        }
        RunLoop.main.add(timer, forMode: .common)
        modifierHoldTimer = timer
    }

    func cancelModifierHold() {
        modifierHoldTimer?.invalidate()
        modifierHoldTimer = nil
    }

    func closeAccentPopup() {
        cancelAccentTimer()
        if accentPopup != nil { accentPopup = nil }
    }

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
        accentTimer?.invalidate()
    }
}

struct AccentPopup: Equatable {
    let keyCode: UInt16
    let variants: [String]
    let layout: AccentPopupLayout
    var highlighted: Int?
    var isHeld: Bool
}

struct AccentPopupView: View {
    let popup: AccentPopup
    let theme: KeyboardTheme

    var body: some View {
        let frame = popup.layout.frame
        let radius = CGFloat(theme.cornerRadius)
        let text = Color(hex: theme.keycapTextColorHex)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: radius + popup.layout.padding, style: .continuous)
                .fill(Color(hex: theme.keycapBaseColorHex))
                .overlay(
                    RoundedRectangle(cornerRadius: radius + popup.layout.padding, style: .continuous)
                        .strokeBorder(text.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
            ForEach(Array(popup.variants.enumerated()), id: \.offset) { index, variant in
                let cell = popup.layout.optionFrame(at: index)
                let isHighlighted = popup.highlighted == index
                Text(variant)
                    .font(.system(size: cell.height * 0.5, weight: .semibold))
                    .foregroundStyle(isHighlighted ? Color(hex: theme.activeTextColorHex) : text)
                    .frame(width: cell.width, height: cell.height)
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(isHighlighted ? Color(hex: theme.keycapActiveColorHex) : Color.clear)
                    )
                    .offset(x: cell.minX, y: cell.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
        layout.keys.first { key in
            let rect = frame(for: key)
            if rect.contains(point) { return true }
            guard let extensionRect = KeyboardRenderer.extensionRect(for: key, in: rect) else { return false }
            return extensionRect.contains(point)
        }
    }
}

public struct KeyboardView: View {
    @ObservedObject public var state: KeyboardState
    @ObservedObject private var presses: KeyPressState
    @StateObject private var interaction = KeyboardInteractionState()
    @ObservedObject private var menuShortcuts = MenuShortcutService.shared
    @ObservedObject private var configStore = ConfigStore.shared
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
        let modifiers = state.modifierSnapshot
        let hints = isInteractive && configStore.config.showAppShortcuts
            ? MenuShortcutService.hints(for: layout.keys, modifiers: ShortcutModifiers(snapshot: modifiers), shortcuts: menuShortcuts.shortcuts)
            : [:]

        VStack(spacing: 6) {
            GeometryReader { geo in
                let geometry = KeyboardGeometry(layout: layout, size: geo.size, spacing: CGFloat(theme.keySpacing))
                let renderer = KeyboardRenderer(
                    theme: theme,
                    modifiers: modifiers,
                    physicalKeyCodes: presses.physicalKeyCodes,
                    virtualKeyId: presses.virtualKeyId,
                    localPressedKeyId: interaction.pressedKeyId,
                    hoveredKeyId: isInteractive ? interaction.hoveredKeyId : nil,
                    dwellKeyId: interaction.dwellKeyId,
                    dwellProgress: interaction.dwellProgress,
                    shortcutHints: hints
                )
                let swipePoints = interaction.swipePoints
                let trailColor = Color(hex: theme.accentColorHex).opacity(0.55)

                Canvas { context, size in
                    for key in layout.keys {
                        renderer.draw(key: key, in: geometry.frame(for: key), context: context)
                    }
                    if swipePoints.count > 1 {
                        var trail = Path()
                        trail.addLines(swipePoints)
                        context.stroke(trail, with: .color(trailColor), style: StrokeStyle(lineWidth: max(4, size.height * 0.025), lineCap: .round, lineJoin: .round))
                    }
                }
                .overlay {
                    if let popup = interaction.accentPopup {
                        AccentPopupView(popup: popup, theme: theme)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            pressChanged(value, geometry: geometry)
                        }
                        .onEnded { _ in
                            pressEnded()
                        }
                )
                .onContinuousHover(coordinateSpace: .local) { phase in
                    guard isInteractive else { return }
                    switch phase {
                    case .active(let point):
                        if var popup = interaction.accentPopup, !popup.isHeld {
                            let index = popup.layout.index(at: point)
                            if popup.highlighted != index {
                                popup.highlighted = index
                                interaction.accentPopup = popup
                            }
                        }
                        let id = geometry.key(at: point)?.id
                        if interaction.hoveredKeyId != id {
                            interaction.hoveredKeyId = id
                            updateDwell(id)
                        }
                    case .ended:
                        if interaction.hoveredKeyId != nil {
                            interaction.hoveredKeyId = nil
                        }
                        interaction.stopDwell()
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
                                .accessibilityLabel(accessibilityName(for: key, hint: hints[key.id]))
                                .accessibilityValue(accessibilityValue(for: key))
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAddTraits(isModifierOn(key) ? .isSelected : [])
                                .accessibilityAction {
                                    if isInteractive {
                                        KeyTap.perform(key, state: state)
                                    }
                                }
                                .accessibilityActions {
                                    ForEach(accessibilityVariants(for: key), id: \.self) { variant in
                                        Button("Type \(variant)") {
                                            if isInteractive {
                                                KeySoundEngine.shared.tap(key.keyCode)
                                                KeyboardInputDispatcher.shared.dispatchText(variant, state: state)
                                            }
                                        }
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
            interaction.stopDwell()
            interaction.stopRepeating()
            interaction.closeAccentPopup()
            interaction.resetSwipe()
            KeySoundEngine.shared.releaseAll(source: .onScreen)
        }
        .onChange(of: state.currentLayout.id) { _, _ in
            interaction.closeAccentPopup()
        }
        .onChange(of: modifiers) { _, current in
            guard isInteractive, configStore.config.showAppShortcuts, current.command || current.control else { return }
            MenuShortcutService.shared.refresh(for: FocusManager.shared.targetApplication)
        }
        .onAppear {
            if configStore.config.swipeTypingEnabled {
                SwipeDictionary.shared.preload()
            }
        }
    }

    private func isModifierOn(_ key: KeyboardKey) -> Bool {
        guard let modifier = key.modifierType else { return false }
        let snapshot = state.modifierSnapshot
        switch modifier {
        case .shift: return snapshot.shift
        case .option: return snapshot.option
        case .control: return snapshot.control
        case .command: return snapshot.command
        case .capsLock: return snapshot.capsLock
        case .fn: return snapshot.fn
        }
    }

    private func accessibilityValue(for key: KeyboardKey) -> String {
        guard let modifier = key.modifierType else { return "" }
        guard ModifierLatch.isLockable(modifier) else {
            return isModifierOn(key) ? "on" : "off"
        }
        switch state.level(of: modifier) {
        case .off: return "off"
        case .once: return "on for the next key"
        case .locked: return "locked"
        }
    }

    private func accessibilityVariants(for key: KeyboardKey) -> [String] {
        guard isInteractive else { return [] }
        return accentVariants(for: typedText(for: key), key: key)
    }

    static func systemActionName(_ action: KeySystemAction) -> String {
        switch action {
        case .brightnessDown: return "brightness down"
        case .brightnessUp: return "brightness up"
        case .missionControl: return "Mission Control"
        case .spotlight: return "Spotlight"
        case .previousTrack: return "previous track"
        case .playPause: return "play or pause"
        case .nextTrack: return "next track"
        case .mute: return "mute"
        case .volumeDown: return "volume down"
        case .volumeUp: return "volume up"
        case .lockScreen: return "lock screen"
        }
    }

    static func swipeLetter(_ key: KeyboardKey) -> Character? {
        guard key.kind == .character, !KeyboardLayoutManager.isKeypadKey(key),
              key.labels.defaultLabel.count == 1,
              let letter = key.labels.defaultLabel.lowercased().first,
              letter >= "a", letter <= "z" else { return nil }
        return letter
    }

    private func trackSwipe(_ value: DragGesture.Value, geometry: KeyboardGeometry) {
        guard isInteractive, configStore.config.swipeTypingEnabled, interaction.accentPopup == nil,
              let startId = interaction.pressedKeyId,
              let startKey = state.currentLayout.keys.first(where: { $0.id == startId }),
              let startLetter = Self.swipeLetter(startKey) else { return }
        if !interaction.isSwiping {
            let frame = geometry.frame(for: startKey)
            let moved = hypot(value.location.x - value.startLocation.x, value.location.y - value.startLocation.y)
            guard moved > frame.width * 0.6,
                  let over = geometry.key(at: value.location), over.id != startId,
                  Self.swipeLetter(over) != nil else { return }
            interaction.isSwiping = true
            interaction.stopRepeating()
            interaction.cancelAccentTimer()
            interaction.swipeLetters = [startLetter]
            interaction.swipePoints = [CGPoint(x: frame.midX, y: frame.midY)]
            interaction.swipeKeySize = frame.width
            var centers: [Character: CGPoint] = [:]
            for key in state.currentLayout.keys {
                if let letter = Self.swipeLetter(key) {
                    let rect = geometry.frame(for: key)
                    centers[letter] = CGPoint(x: rect.midX, y: rect.midY)
                }
            }
            interaction.swipeCenters = centers
            if state.virtualPressedKeyId == startId {
                state.virtualPressedKeyId = nil
            }
            if interaction.swipeNeedsSpace, let typed = interaction.swipeFirstTyped {
                KeyboardInputDispatcher.shared.replacePreviousCharacter(with: " " + typed, state: state)
            }
            SwipeDictionary.shared.preload()
        }
        if let last = interaction.swipePoints.last, hypot(value.location.x - last.x, value.location.y - last.y) >= 3 {
            interaction.swipePoints.append(value.location)
        }
        if let over = geometry.key(at: value.location), let letter = Self.swipeLetter(over), interaction.swipeLetters.last != letter {
            interaction.swipeLetters.append(letter)
        }
    }

    private func finishSwipe() {
        let letters = interaction.swipeLetters
        var points = interaction.swipePoints
        let centers = interaction.swipeCenters
        let keySize = interaction.swipeKeySize
        let typedFirst = interaction.swipeFirstTyped ?? ""
        interaction.resetSwipe()
        let path = SwipeDecoder.collapse(letters)
        guard path.count >= 2, let first = path.first, let last = path.last else { return }
        if let end = centers[last], let tail = points.last, hypot(end.x - tail.x, end.y - tail.y) > keySize * 0.3 {
            points.append(end)
        }
        let lexicon = PersonalLexicon.shared
        var candidates = SwipeDictionary.shared.words(first: first, last: last)
        candidates += lexicon.data.customWords.filter { $0.lowercased().first == first && $0.lowercased().last == last }
        candidates += lexicon.data.words
            .filter { $0.value >= PersonalLexicon.minimumLearnedCount && $0.key.first == first && $0.key.last == last }
            .map { $0.key }
        let ranked = SwipeDecoder.rank(
            path: path,
            points: points,
            centers: centers,
            keySize: keySize,
            candidates: candidates
        ) { word in
            SwipeDecoder.commonBonus(word) + min(0.4, 0.12 * log2(CGFloat(lexicon.frequency(of: word)) + 1))
        }
        guard let best = ranked.first else { return }
        var rest = String(best.dropFirst())
        if state.isCapsLockActive || state.isShiftActive { rest = rest.uppercased() }
        guard !rest.isEmpty else { return }
        KeyboardInputDispatcher.shared.typeText(rest, state: KeyboardState())
        KeySoundEngine.shared.tap(49)
        WordSuggestions.shared.showAlternatives(for: typedFirst + rest, alternatives: Array(ranked.dropFirst()))
    }

    private func pressChanged(_ value: DragGesture.Value, geometry: KeyboardGeometry) {
        if let consumed = interaction.consumedPressStart {
            if consumed == value.startLocation { return }
            interaction.consumedPressStart = nil
        }
        if var popup = interaction.accentPopup {
            if popup.isHeld, interaction.pressStart == value.startLocation {
                let index = popup.layout.index(at: value.location)
                if popup.highlighted != index {
                    popup.highlighted = index
                    interaction.accentPopup = popup
                }
                return
            }
            interaction.closeAccentPopup()
            if let index = popup.layout.index(at: value.startLocation) {
                interaction.consumedPressStart = value.startLocation
                commitAccent(popup, index: index)
                return
            }
        }
        if interaction.pressedKeyId != nil, interaction.pressStart == value.startLocation {
            trackSwipe(value, geometry: geometry)
            return
        }
        if interaction.pressedKeyId != nil, interaction.pressStart != value.startLocation {
            end()
        }
        if interaction.pressedKeyId == nil, let key = geometry.key(at: value.startLocation) {
            interaction.pressStart = value.startLocation
            begin(key, frame: geometry.frame(for: key), bounds: CGRect(origin: .zero, size: geometry.size))
        }
    }

    private func pressEnded() {
        interaction.consumedPressStart = nil
        if interaction.isSwiping {
            finishSwipe()
        }
        if var popup = interaction.accentPopup, popup.isHeld {
            if let index = popup.highlighted {
                interaction.closeAccentPopup()
                commitAccent(popup, index: index)
            } else {
                popup.isHeld = false
                interaction.accentPopup = popup
            }
        }
        end()
    }

    private func commitAccent(_ popup: AccentPopup, index: Int) {
        guard isInteractive, popup.variants.indices.contains(index) else { return }
        KeySoundEngine.shared.tap(popup.keyCode)
        KeyboardInputDispatcher.shared.replacePreviousCharacter(with: popup.variants[index], state: state)
    }

    private func typedText(for key: KeyboardKey) -> String? {
        guard case .text(let typed, _) = KeyboardInputDispatcher.shared.action(for: key, state: state) else { return nil }
        return typed
    }

    private func accentVariants(for typed: String?, key: KeyboardKey) -> [String] {
        guard ConfigStore.shared.config.accentPopupEnabled, !KeyboardLayoutManager.isKeypadKey(key), let typed else { return [] }
        return AccentVariants.variants(for: typed)
    }

    private func begin(_ key: KeyboardKey, frame: CGRect, bounds: CGRect) {
        interaction.pressedKeyId = key.id
        interaction.pressBegan = Date()
        guard isInteractive else { return }
        KeySoundEngine.shared.keyDown(key.keyCode, source: .onScreen)
        if key.modifierType == .fn {
            return
        }
        state.virtualPressedKeyId = key.id
        if let modifier = key.modifierType, ModifierLatch.isLockable(modifier) {
            let level = state.pressModifier(modifier, press: .click)
            if level == .once && configStore.config.modifierStickyMode {
                let state = self.state
                interaction.scheduleModifierHold { [weak interaction] in
                    guard let interaction, interaction.pressedKeyId == key.id,
                          NSEvent.pressedMouseButtons & 1 != 0,
                          state.level(of: modifier) == .once else { return }
                    state.lockModifier(modifier)
                }
            }
            return
        }
        let repeatState = state.detachedCopy()
        let typed = typedText(for: key)
        let variants = accentVariants(for: typed, key: key)
        interaction.swipeFirstTyped = typed
        interaction.swipeNeedsSpace = WordSuggestions.shared.pendingSwipeSpace
        let issue = KeyboardInputDispatcher.shared.dispatchKey(key, state: state)
        if issue == nil && !variants.isEmpty {
            interaction.scheduleAccentPopup { [weak interaction] in
                guard let interaction, interaction.pressedKeyId == key.id, NSEvent.pressedMouseButtons & 1 != 0 else { return }
                interaction.accentPopup = AccentPopup(
                    keyCode: key.keyCode,
                    variants: variants,
                    layout: AccentPopupLayout(count: variants.count, anchor: frame, bounds: bounds),
                    highlighted: nil,
                    isHeld: true
                )
            }
        } else if issue == nil && isRepeatable(key) {
            interaction.startRepeating { [weak interaction] in
                guard NSEvent.pressedMouseButtons & 1 != 0 else {
                    interaction?.stopRepeating()
                    return
                }
                KeyboardInputDispatcher.shared.dispatchKey(key, state: repeatState.detachedCopy())
            }
        }
    }

    private func end() {
        interaction.stopRepeating()
        interaction.cancelAccentTimer()
        interaction.cancelModifierHold()
        if interaction.isSwiping {
            interaction.resetSwipe()
        }
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

    private func updateDwell(_ id: String?) {
        let config = ConfigStore.shared.config
        let state = self.state
        interaction.updateDwell(hovered: id, enabled: isInteractive && config.dwellEnabled, duration: config.dwellDuration) { firedId in
            guard let key = state.currentLayout.keys.first(where: { $0.id == firedId }) else { return }
            KeyTap.perform(key, state: state)
        }
    }

    private func isRepeatable(_ key: KeyboardKey) -> Bool {
        guard ConfigStore.shared.config.keyRepeatEnabled else { return false }
        if let remap = key.remap {
            return remap.repeats
        }
        switch key.kind {
        case .character, .navigation:
            return true
        case .system:
            return key.id == "k_delete"
        case .modifier, .function, .spacer:
            return false
        }
    }

    private func accessibilityName(for key: KeyboardKey, hint: String?) -> String {
        let name = accessibilityName(for: key)
        guard let hint else { return name }
        return "\(name), \(hint)"
    }

    private func accessibilityName(for key: KeyboardKey) -> String {
        if let remap = key.remap {
            switch remap {
            case .disabled:
                return "turned off key"
            case .key(let code):
                return key.labels.defaultLabel.isEmpty ? KeyRemapper.keyName(for: code) : key.labels.defaultLabel
            case .shortcut(let keys):
                return "shortcut \(keys.joined(separator: " "))"
            case .snippet:
                return "snippet \(key.labels.defaultLabel)"
            case .text:
                let modifiers = state.modifierSnapshot
                return key.displayedLabel(shift: modifiers.shift, option: modifiers.option, capsLock: modifiers.capsLock)
            }
        }
        if KeyboardLayoutManager.isKeypadKey(key), key.kind == .character || key.keyCode == 71 || key.keyCode == 76 {
            return "keypad \(key.labels.defaultLabel)"
        }
        if let action = key.systemAction {
            let label = key.labels.defaultLabel
            return label.isEmpty || key.id == "k_lock" ? Self.systemActionName(action) : "\(label), \(Self.systemActionName(action))"
        }
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
    var dwellKeyId: String? = nil
    var dwellProgress: Double = 0
    var shortcutHints: [String: String] = [:]

    private let keycapColor: Color
    private let modifierColor: Color
    private let activeColor: Color
    private let accentColor: Color
    private let borderColor: Color
    private let textColor: Color
    private let activeTextColor: Color
    private let keycapIsDark: Bool
    private let tintedKeycapTextColor: Color
    private let tintedModifierTextColor: Color
    private let modifierIsDark: Bool

    init(
        theme: KeyboardTheme,
        modifiers: KeyModifierSnapshot,
        physicalKeyCodes: Set<UInt16>,
        virtualKeyId: String?,
        localPressedKeyId: String?,
        hoveredKeyId: String?
,
        dwellKeyId: String? = nil,
        dwellProgress: Double = 0,
        shortcutHints: [String: String] = [:]
    ) {
        self.shortcutHints = shortcutHints
        self.theme = theme
        self.modifiers = modifiers
        self.physicalKeyCodes = physicalKeyCodes
        self.virtualKeyId = virtualKeyId
        self.localPressedKeyId = localPressedKeyId
        self.hoveredKeyId = hoveredKeyId
        self.dwellKeyId = dwellKeyId
        self.dwellProgress = dwellProgress
        self.keycapColor = Color(hex: theme.keycapBaseColorHex)
        self.modifierColor = Color(hex: theme.modifierKeyColorHex)
        self.activeColor = Color(hex: theme.keycapActiveColorHex)
        self.accentColor = Color(hex: theme.accentColorHex)
        self.borderColor = Color(hex: theme.borderColorHex).opacity(theme.borderOpacity)
        self.textColor = Color(hex: theme.keycapTextColorHex)
        self.activeTextColor = Color(hex: theme.activeTextColorHex)
        self.tintedKeycapTextColor = Self.tintedTextColor(theme: theme, baseHex: theme.keycapBaseColorHex)
        self.tintedModifierTextColor = Self.tintedTextColor(theme: theme, baseHex: theme.modifierKeyColorHex)
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

    static func extensionWidth(for key: KeyboardKey, in rect: CGRect) -> CGFloat {
        guard let ext = key.topLeftExtension, ext > 0, key.unitFrame.width > 0 else { return 0 }
        return rect.width / CGFloat(key.unitFrame.width) * CGFloat(ext)
    }

    static func topPartHeight(for key: KeyboardKey, in rect: CGRect) -> CGFloat {
        rect.height * CGFloat(1.0 / max(1.0, key.unitFrame.height))
    }

    static func extensionRect(for key: KeyboardKey, in rect: CGRect) -> CGRect? {
        let width = extensionWidth(for: key, in: rect)
        guard width > 0 else { return nil }
        return CGRect(x: rect.minX - width, y: rect.minY, width: width, height: topPartHeight(for: key, in: rect))
    }

    static func labelRect(for key: KeyboardKey, in rect: CGRect) -> CGRect {
        let width = extensionWidth(for: key, in: rect)
        guard width > 0 else { return rect }
        return CGRect(x: rect.minX - width, y: rect.minY, width: rect.width + width, height: topPartHeight(for: key, in: rect))
    }

    static func shape(for key: KeyboardKey, in rect: CGRect, radius: CGFloat) -> Path {
        let body = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        let width = extensionWidth(for: key, in: rect)
        guard width > 0 else { return body }
        let top = Path(roundedRect: labelRect(for: key, in: rect), cornerRadius: radius, style: .continuous)
        return Path(body.cgPath.union(top.cgPath))
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

        let labelColor = isDown ? (showsAccentTint ? (key.kind == .modifier ? tintedModifierTextColor : tintedKeycapTextColor) : activeTextColor) : textColor
        if let hint = shortcutHints[key.id] {
            drawLabel(key: key, rect: rect.offsetBy(dx: 0, dy: -rect.height * 0.13), isDown: isDown, textColor: labelColor, context: context)
            let sz = min(rect.width, rect.height)
            let (resolved, _) = fitted(
                hint,
                size: sz * 0.17,
                weight: .semibold,
                color: isDown ? labelColor : accentColor,
                maxWidth: rect.width * 0.9,
                minScale: 0.5,
                context: context
            )
            context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.maxY - sz * 0.08), anchor: .bottom)
        } else {
            drawLabel(key: key, rect: rect, isDown: isDown, textColor: labelColor, context: context)
        }

        if let modifier = key.modifierType, modifier != .capsLock, modifiers.locked.contains(modifier) {
            let u = rect.height / CGFloat(max(0.25, key.unitFrame.height))
            let trailing = key.id == "k_rcmd" || key.id == "k_ropt" || key.id == "k_rctrl"
            let x = trailing ? rect.maxX - u * 0.13 - u * 0.085 : rect.minX + u * 0.13
            Self.drawLED(at: CGPoint(x: x, y: rect.minY + u * 0.11), diameter: u * 0.085, on: true, offColor: textColor, context: context)
        }

        if dwellKeyId == key.id, dwellProgress > 0 {
            let inset = rect.insetBy(dx: rect.width * 0.12, dy: 0)
            let track = CGRect(x: inset.minX, y: rect.maxY - max(3, rect.height * 0.07) - 3, width: inset.width, height: max(3, rect.height * 0.07))
            context.fill(Path(roundedRect: track, cornerRadius: track.height / 2), with: .color(accentColor.opacity(0.25)))
            let filled = CGRect(x: track.minX, y: track.minY, width: track.width * CGFloat(dwellProgress), height: track.height)
            context.fill(Path(roundedRect: filled, cornerRadius: track.height / 2), with: .color(accentColor))
        }
    }

    static func tintedTextColor(theme: KeyboardTheme, baseHex: String) -> Color {
        let isGlass = theme.keycapStyle == .glass
        let under = isGlass ? theme.backgroundColorHex : baseHex
        let amount = isGlass ? 0.2 : 0.35
        guard let a = KeyboardTheme.rgbComponents(hex: under), let b = KeyboardTheme.rgbComponents(hex: theme.accentColorHex) else {
            return Color(hex: theme.keycapTextColorHex)
        }
        func channel(_ x: Double, _ y: Double) -> Int { Int(((x * (1 - amount) + y * amount) * 255).rounded()) }
        let blended = String(format: "#%02X%02X%02X", channel(a.red, b.red), channel(a.green, b.green), channel(a.blue, b.blue))
        return Color(hex: SnippetsAppearance.readableColor(theme.keycapTextColorHex, on: blended))
    }

    static let ledColor = Color(red: 0.2, green: 0.86, blue: 0.36)

    static func drawLED(at origin: CGPoint, diameter: CGFloat, on: Bool, offColor: Color, context: GraphicsContext) {
        let led = CGRect(x: origin.x, y: origin.y, width: diameter, height: diameter)
        guard on else {
            context.fill(Path(ellipseIn: led), with: .color(offColor.opacity(0.22)))
            return
        }
        let glowRadius = diameter * 2.2
        let glow = CGRect(x: led.midX - glowRadius, y: led.midY - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [ledColor.opacity(0.55), ledColor.opacity(0)]),
            center: CGPoint(x: led.midX, y: led.midY),
            startRadius: diameter * 0.3,
            endRadius: glowRadius
        ))
        context.fill(Path(ellipseIn: led), with: .color(ledColor))
        context.fill(Path(ellipseIn: led.insetBy(dx: diameter * 0.3, dy: diameter * 0.3)), with: .color(Color.white.opacity(0.7)))
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

        let shape = Self.shape(for: key, in: rect, radius: radius)

        func fillKey(_ color: Color) {
            if showsAccentTint {
                context.fill(shape, with: .color(base))
            }
            context.fill(shape, with: .color(color))
        }

        func strokeBorder(_ shading: GraphicsContext.Shading, width: CGFloat) {
            guard width > 0 else { return }
            let inset = rect.insetBy(dx: width / 2, dy: width / 2)
            let path = Self.shape(for: key, in: inset, radius: max(0, radius - width / 2))
            context.stroke(path, with: shading, lineWidth: width)
        }

        switch theme.keycapStyle {
        case .raised:
            let plate = Self.shape(for: key, in: rect.offsetBy(dx: 0, dy: isDown ? 0 : max(1, elevation * 0.8)), radius: radius)
            context.fill(plate, with: .color(Color.black.opacity(0.35)))
            fillKey(fill)
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(isDown ? 0 : 0.10), Color.black.opacity(0.10)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ))
            strokeBorder(.color(strokeColor), width: lineWidth)

        case .flat:
            fillKey(fill)
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
            fillKey(isDown ? fill : restFill)
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
                let plate = Self.shape(for: key, in: rect.offsetBy(dx: 0, dy: isDown ? 0.5 : max(0.5, elevation * 0.6)), radius: radius)
                context.fill(plate, with: .color(Color.black.opacity(isDown ? 0.06 : 0.22)))
            }
            fillKey(fill)
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

    private func hasDualLabels(_ key: KeyboardKey) -> Bool {
        guard key.kind == .character else { return false }
        guard let shift = key.labels.shiftLabel, !shift.isEmpty else { return false }
        if shift == key.labels.defaultLabel.uppercased() { return false }
        return shift != key.labels.defaultLabel
    }

    private enum LegendCorner {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }

    private func drawLegend(_ resolved: GraphicsContext.ResolvedText, corner: LegendCorner, in rect: CGRect, padX: CGFloat, padY: CGFloat, context: GraphicsContext) {
        switch corner {
        case .topLeading:
            context.draw(resolved, at: CGPoint(x: rect.minX + padX, y: rect.minY + padY), anchor: .topLeading)
        case .topTrailing:
            context.draw(resolved, at: CGPoint(x: rect.maxX - padX, y: rect.minY + padY), anchor: .topTrailing)
        case .bottomLeading:
            context.draw(resolved, at: CGPoint(x: rect.minX + padX, y: rect.maxY - padY), anchor: .bottomLeading)
        case .bottomTrailing:
            context.draw(resolved, at: CGPoint(x: rect.maxX - padX, y: rect.maxY - padY), anchor: .bottomTrailing)
        }
    }

    private func drawLabel(key: KeyboardKey, rect keyRect: CGRect, isDown: Bool, textColor: Color, context: GraphicsContext) {
        let rect = Self.labelRect(for: key, in: keyRect)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let u = keyRect.height / CGFloat(max(0.25, key.unitFrame.height))
        let padX = u * 0.13
        let padY = u * 0.11
        let wordSize = u * 0.165
        let modSymbolSize = u * 0.2
        let wordMaxWidth = max(1, rect.width - padX * 2)

        func word(_ string: String) -> GraphicsContext.ResolvedText {
            fitted(string, size: wordSize, weight: .regular, color: textColor, maxWidth: wordMaxWidth, minScale: 0.6, context: context).0
        }

        func glyph(_ string: String) -> GraphicsContext.ResolvedText {
            context.resolve(text(string, size: modSymbolSize, weight: .regular, color: textColor))
        }

        if hasDualLabels(key) {
            let accent = accentColor
            let shiftColor = modifiers.shift ? (isDown ? accent : accent.opacity(0.85)) : textColor.opacity(0.7)
            let baseColor = (!modifiers.shift || isDown) ? textColor : textColor.opacity(0.55)

            let top = context.resolve(text(key.labels.shiftLabel ?? "", size: u * 0.19, weight: .regular, design: fontDesign, color: shiftColor))
            context.draw(top, at: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.32), anchor: .center)

            let bottom = context.resolve(text(key.labels.defaultLabel, size: u * 0.22, weight: .regular, design: fontDesign, color: baseColor))
            context.draw(bottom, at: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.67), anchor: .center)
            return
        }

        switch key.id {
        case "k_lcmd", "k_lopt", "k_lctrl":
            let symbol = key.id == "k_lcmd" ? "⌘" : (key.id == "k_lopt" ? "⌥" : "⌃")
            drawLegend(glyph(symbol), corner: .topTrailing, in: rect, padX: padX, padY: padY, context: context)
            drawLegend(word(key.labels.defaultLabel), corner: .bottomTrailing, in: rect, padX: padX, padY: padY, context: context)

        case "k_rcmd", "k_ropt", "k_rctrl":
            let symbol = key.id == "k_rcmd" ? "⌘" : (key.id == "k_ropt" ? "⌥" : "⌃")
            drawLegend(glyph(symbol), corner: .topLeading, in: rect, padX: padX, padY: padY, context: context)
            drawLegend(word(key.labels.defaultLabel), corner: .bottomLeading, in: rect, padX: padX, padY: padY, context: context)

        case "k_fn":
            drawLegend(word("fn"), corner: .topTrailing, in: rect, padX: padX, padY: padY, context: context)
            drawLegend(context.resolve(symbol("globe", size: modSymbolSize, weight: .regular, color: textColor)), corner: .bottomLeading, in: rect, padX: padX, padY: padY, context: context)

        case "k_caps":
            Self.drawLED(at: CGPoint(x: rect.minX + padX, y: rect.minY + padY), diameter: u * 0.085, on: modifiers.capsLock, offColor: textColor, context: context)
            drawLegend(word("caps lock"), corner: .bottomLeading, in: rect, padX: padX, padY: padY, context: context)

        case "k_esc", "k_tab", "k_lshift":
            drawLegend(word(key.labels.defaultLabel), corner: .bottomLeading, in: rect, padX: padX, padY: padY, context: context)

        case "k_delete", "k_return", "k_rshift":
            drawLegend(word(key.labels.defaultLabel), corner: .bottomTrailing, in: rect, padX: padX, padY: padY, context: context)

        case "k_lock":
            context.draw(context.resolve(symbol("lock.fill", size: u * 0.22, weight: .regular, color: textColor)), at: center, anchor: .center)

        case "k_space":
            break

        default:
            if let icon = key.symbolIcon, key.kind != .character {
                if key.kind == .function {
                    let iconText = context.resolve(symbol(icon, size: u * 0.2, weight: .regular, color: textColor.opacity(modifiers.fn ? 0.45 : 1.0)))
                    context.draw(iconText, at: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.4), anchor: .center)
                    let label = context.resolve(text(key.labels.defaultLabel, size: u * 0.12, weight: .medium, color: textColor.opacity(modifiers.fn ? 1.0 : 0.7)))
                    context.draw(label, at: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.76), anchor: .center)
                } else if key.kind == .navigation {
                    context.draw(context.resolve(symbol(icon, size: u * 0.17, weight: .regular, color: textColor)), at: center, anchor: .center)
                } else {
                    context.draw(context.resolve(symbol(icon, size: u * 0.24, weight: .regular, color: textColor)), at: center, anchor: .center)
                }
            } else {
                let displayed = key.displayedLabel(shift: modifiers.shift, option: modifiers.option, capsLock: modifiers.capsLock)
                let isLetter = displayed.count == 1 && displayed.first?.isLetter == true && !modifiers.option
                let label = isLetter ? displayed.uppercased() : displayed
                let (resolved, _) = fitted(
                    label,
                    size: label.count > 2 ? wordSize * 1.15 : u * 0.27,
                    weight: .medium,
                    design: fontDesign,
                    color: textColor,
                    maxWidth: rect.width * 0.85,
                    minScale: 0.5,
                    context: context
                )
                context.draw(resolved, at: center, anchor: .center)
            }
        }
    }
}
