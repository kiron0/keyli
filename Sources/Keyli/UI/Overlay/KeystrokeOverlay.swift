import AppKit
import SwiftUI
import CoreGraphics

public enum KeystrokeFormatter {
    public enum Mode: String, CaseIterable, Identifiable {
        case shortcuts
        case all

        public var id: String { rawValue }
        public var title: String { self == .shortcuts ? "Shortcuts only" : "Every key" }
    }

    static let specialNames: [UInt16: String] = [
        53: "esc", 36: "↩", 76: "⌤", 48: "⇥", 49: "space", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟", 57: "⇪"
    ]

    static let functionKeys: Set<UInt16> = ShortcutManager.functionKeyCodes

    public static func modifierSymbols(_ flags: CGEventFlags) -> [String] {
        var symbols: [String] = []
        if flags.contains(.maskControl) { symbols.append("⌃") }
        if flags.contains(.maskAlternate) { symbols.append("⌥") }
        if flags.contains(.maskShift) { symbols.append("⇧") }
        if flags.contains(.maskCommand) { symbols.append("⌘") }
        return symbols
    }

    public static func keyName(_ keyCode: UInt16, character: String?, composed: Bool = false) -> String {
        if let special = specialNames[keyCode] { return special }
        if let name = ShortcutManager.keyName(for: keyCode), name.count > 1 || composed { return name.uppercased() }
        if !composed, let character, !character.isEmpty, character != " " { return character.uppercased() }
        if let name = ShortcutManager.keyName(for: keyCode) { return name.uppercased() }
        let label = CharacterTranslator.shared.translateKeycode(keyCode).defaultLabel
        return label.isEmpty ? "?" : label.uppercased()
    }

    public static func isShortcut(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) { return true }
        return functionKeys.contains(keyCode) || keyCode == 53
    }

    public static func keycaps(keyCode: UInt16, flags: CGEventFlags, character: String?, mode: Mode) -> [String]? {
        let shortcut = isShortcut(keyCode: keyCode, flags: flags)
        guard mode == .all || shortcut else { return nil }
        let composed = flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate)
        return modifierSymbols(flags) + [keyName(keyCode, character: character, composed: composed)]
    }
}

final class KeystrokeOverlayModel: ObservableObject {
    @Published var keycaps: [String] = []
    @Published var typed: String = ""
    @Published var isVisible = false
}

struct KeystrokeOverlayView: View {
    @ObservedObject var model: KeystrokeOverlayModel
    @ObservedObject var configStore: ConfigStore = .shared

    var alignment: Alignment {
        let position = configStore.config.keystrokeOverlayPosition
        let top = position.hasPrefix("top")
        if position.hasSuffix("left") { return top ? .topLeading : .bottomLeading }
        if position.hasSuffix("right") { return top ? .topTrailing : .bottomTrailing }
        return top ? .top : .bottom
    }

    var body: some View {
        HStack(spacing: 8) {
            if !model.typed.isEmpty {
                Text(model.typed)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.head)
            } else {
                ForEach(Array(model.keycaps.enumerated()), id: \.offset) { _, cap in
                    Text(cap)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(minWidth: 48, minHeight: 52)
                        .padding(.horizontal, cap.count > 1 ? 10 : 0)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
        .opacity(model.isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.18), value: model.isVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .accessibilityHidden(true)
    }
}

public final class KeystrokeOverlay {
    public static let shared = KeystrokeOverlay()

    private let model = KeystrokeOverlayModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var lastTypedAt: Date = .distantPast
    static let displayDuration: TimeInterval = 1.4

    public var isShowing: Bool { model.isVisible }
    var currentKeycaps: [String] { model.keycaps }
    var currentTyped: String { model.typed }

    public func handleKeyDown(keyCode: UInt16, flags: CGEventFlags, character: String?, isRepeat: Bool) {
        let config = ConfigStore.shared.config
        guard config.keystrokeOverlayEnabled, !isRepeat else { return }
        let mode = KeystrokeFormatter.Mode(rawValue: config.keystrokeOverlayMode) ?? .shortcuts
        guard let caps = KeystrokeFormatter.keycaps(keyCode: keyCode, flags: flags, character: character, mode: mode) else { return }
        let plainCharacter = mode == .all && caps.count == 1 && caps[0].count == 1
        if plainCharacter, Date().timeIntervalSince(lastTypedAt) < Self.displayDuration, !model.typed.isEmpty || model.keycaps.isEmpty {
            model.typed = String((model.typed + (character ?? caps[0])).suffix(24))
        } else if plainCharacter {
            model.keycaps = []
            model.typed = character ?? caps[0]
        } else {
            model.typed = ""
            model.keycaps = caps
        }
        lastTypedAt = Date()
        show()
    }

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
        model.isVisible = true
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.model.isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard let self, !self.model.isVisible else { return }
                self.panel?.orderOut(nil)
                self.model.typed = ""
                self.model.keycaps = []
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.displayDuration, execute: work)
    }

    public func hide() {
        hideWork?.cancel()
        model.isVisible = false
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: KeystrokeOverlayView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }

    static let edgeMargin: CGFloat = 32

    public static let positions: [(id: String, title: String)] = [
        ("top-left", "Top Left"), ("top", "Top"), ("top-right", "Top Right"),
        ("bottom-left", "Bottom Left"), ("bottom", "Bottom"), ("bottom-right", "Bottom Right")
    ]

    static func frame(on screen: NSRect, position: String, size: NSSize = NSSize(width: 640, height: 100)) -> NSRect {
        let margin = Self.edgeMargin
        let y = position.hasPrefix("top") ? screen.maxY - size.height - margin : screen.minY + margin
        let x: CGFloat
        if position.hasSuffix("left") {
            x = screen.minX + margin
        } else if position.hasSuffix("right") {
            x = screen.maxX - size.width - margin
        } else {
            x = screen.midX - size.width / 2
        }
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        panel.setFrame(Self.frame(on: visible, position: ConfigStore.shared.config.keystrokeOverlayPosition), display: false)
    }
}
