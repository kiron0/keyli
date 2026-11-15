import AppKit
import SwiftUI

final class SnippetsWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class SnippetsSearchState: ObservableObject {
    @Published var query = ""
}

public enum SnippetFilter {
    public static func matching(_ snippets: [Snippet], query: String) -> [Snippet] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return snippets }
        return snippets.filter {
            $0.title.lowercased().contains(trimmed) || $0.text.lowercased().contains(trimmed) || $0.keys.joined().lowercased().contains(trimmed)
        }
    }
}

enum SnippetsAppearance {
    static func contrast(_ foreground: String, on background: String) -> Double {
        let first = KeyboardTheme.relativeLuminance(hex: foreground)
        let second = KeyboardTheme.relativeLuminance(hex: background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    static func readableColor(_ preferred: String, on background: String) -> String {
        if contrast(preferred, on: background) >= 4.5 { return preferred }
        return contrast("#000000", on: background) >= contrast("#FFFFFF", on: background)
            ? "#000000" : "#FFFFFF"
    }

    static func backdrop(for theme: KeyboardTheme) -> KeyboardTheme {
        // Keep text contrast stable regardless of the desktop behind this utility window.
        var backdrop = theme
        backdrop.backgroundOpacity = 1
        return backdrop
    }

    static func fontDesign(for theme: KeyboardTheme) -> Font.Design {
        switch theme.fontDesign {
        case "monospaced": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return .default
        }
    }
}

struct SnippetsPanelView: View {
    @ObservedObject var state: KeyboardState = .shared
    @ObservedObject var configStore: ConfigStore = .shared
    @ObservedObject var search: SnippetsSearchState
    let onClose: () -> Void

    var body: some View {
        let theme = state.currentTheme
        let text = Color(hex: SnippetsAppearance.readableColor(theme.keycapTextColorHex, on: theme.backgroundColorHex))
        let rowText = Color(hex: SnippetsAppearance.readableColor(theme.keycapTextColorHex, on: theme.keycapBaseColorHex))
        let rowAccent = Color(hex: SnippetsAppearance.readableColor(theme.accentColorHex, on: theme.keycapBaseColorHex))
        let accent = Color(hex: SnippetsAppearance.readableColor(theme.accentColorHex, on: theme.backgroundColorHex))
        let design = SnippetsAppearance.fontDesign(for: theme)
        let backdropTheme = SnippetsAppearance.backdrop(for: theme)
        let snippets = SnippetFilter.matching(configStore.config.snippets, query: search.query)
        VStack(spacing: 8) {
            ZStack {
                DragHandleView().frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 8) {
                    KeyboardChromeButton(systemImage: "xmark", tint: text, help: "Close Snippets", action: onClose)
                    Text("Snippets")
                        .font(.system(size: 12, weight: .semibold, design: design))
                        .foregroundStyle(text)
                        .allowsHitTesting(false)
                    Spacer(minLength: 0)
                    KeyboardChromeButton(systemImage: "slider.horizontal.3", tint: text, help: "Edit Snippets in Settings") {
                        SettingsWindowController.shared.showSettings(tab: .typing)
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 30)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium, design: design))
                    .foregroundStyle(rowText)
                    .accessibilityHidden(true)
                TextField("Search snippets", text: $search.query, prompt: Text("Search snippets").foregroundColor(rowText))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: design))
                    .foregroundStyle(rowText)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color(hex: theme.keycapBaseColorHex), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 10)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(snippets) { snippet in
                        Button {
                            SnippetRunner.run(snippet)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: snippet.kind == .shortcut ? "command" : "text.quote")
                                    .font(.system(size: 11, weight: .semibold, design: design))
                                    .foregroundStyle(rowAccent)
                                    .frame(width: 18)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(snippet.title)
                                        .font(.system(size: 12.5, weight: .semibold, design: design))
                                        .foregroundStyle(rowText)
                                        .lineLimit(1)
                                    Text(snippet.kind == .shortcut ? snippet.keys.joined(separator: " ") : snippet.text)
                                        .font(.system(size: 11.5, design: snippet.kind == .shortcut ? .monospaced : design))
                                        .foregroundStyle(rowText)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 42)
                            .background(Color(hex: theme.keycapBaseColorHex), in: RoundedRectangle(cornerRadius: min(9, CGFloat(theme.cornerRadius)), style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(snippet.title)
                    }
                    if snippets.isEmpty {
                        VStack(spacing: 8) {
                            Text(configStore.config.snippets.isEmpty ? "No snippets yet." : "No snippets match “\(search.query)”.")
                                .font(.system(size: 12, design: design))
                                .foregroundStyle(text)
                            if configStore.config.snippets.isEmpty {
                                Button("Add Snippets…") {
                                    SettingsWindowController.shared.showSettings(tab: .typing)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .semibold, design: design))
                                .foregroundStyle(accent)
                            }
                        }
                        .padding(.top, 30)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyboardBackdrop(theme: backdropTheme))
        .preferredColorScheme(theme.isDarkBackground ? .dark : .light)
        .tint(accent)
        .ignoresSafeArea()
    }
}

public final class SnippetsPanelController {
    public static let shared = SnippetsPanelController()

    private var panel: SnippetsWindow?
    private let search = SnippetsSearchState()

    public var isVisible: Bool { panel?.isVisible ?? false }

    public func toggle() {
        isVisible ? hide() : show()
    }

    public func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.level = ConfigStore.shared.config.isFloatingPinned ? .floating : .normal
        panel.orderFrontRegardless()
    }

    public func hide() {
        search.query = ""
        panel?.orderOut(nil)
    }

    static func initialFrame(keyboard: NSRect?, screen: NSRect, size: NSSize = NSSize(width: 300, height: 380)) -> NSRect {
        guard let keyboard else {
            return NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
        }
        var x = keyboard.maxX + 12
        if x + size.width > screen.maxX { x = keyboard.minX - size.width - 12 }
        x = max(screen.minX, min(x, screen.maxX - size.width))
        let y = max(screen.minY, min(keyboard.maxY - size.height, screen.maxY - size.height))
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func makePanel() -> SnippetsWindow {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let keyboard = PanelManager.shared.isFloatingVisible ? PanelManager.shared.getOrCreateFloatingPanel().frame : nil
        let frame = Self.initialFrame(keyboard: keyboard, screen: screen)
        let panel = SnippetsWindow(contentRect: frame, styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.minSize = NSSize(width: 240, height: 220)
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        let host = NSHostingView(rootView: SnippetsPanelView(search: search) { [weak self] in self?.hide() })
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }
}
