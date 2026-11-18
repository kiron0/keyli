import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var state: KeyboardState = .shared
    @ObservedObject var configStore: ConfigStore = .shared
    @ObservedObject var history: ClipboardHistory = .shared
    @ObservedObject var search: SnippetsSearchState
    let onClose: () -> Void

    var body: some View {
        let theme = state.currentTheme
        let text = Color(hex: SnippetsAppearance.readableColor(theme.keycapTextColorHex, on: theme.backgroundColorHex))
        let rowText = Color(hex: SnippetsAppearance.readableColor(theme.keycapTextColorHex, on: theme.keycapBaseColorHex))
        let accent = Color(hex: SnippetsAppearance.readableColor(theme.accentColorHex, on: theme.backgroundColorHex))
        let design = SnippetsAppearance.fontDesign(for: theme)
        let items = ClipboardHistory.matching(history.items, query: search.query)
        VStack(spacing: 8) {
            ZStack {
                DragHandleView().frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 8) {
                    KeyboardChromeButton(systemImage: "xmark", tint: text, help: "Close Clipboard History", action: onClose)
                    Text("Clipboard")
                        .font(.system(size: 12, weight: .semibold, design: design))
                        .foregroundStyle(text)
                        .allowsHitTesting(false)
                    Spacer(minLength: 0)
                    if !history.items.isEmpty {
                        KeyboardChromeButton(systemImage: "trash", tint: text, help: "Clear Clipboard History") {
                            history.clear()
                        }
                    }
                    KeyboardChromeButton(systemImage: "slider.horizontal.3", tint: text, help: "Clipboard Settings") {
                        SettingsWindowController.shared.showSettings(tab: .typing)
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 30)

            if configStore.config.clipboardHistoryEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium, design: design))
                        .foregroundStyle(rowText)
                        .accessibilityHidden(true)
                    TextField("Search clipboard", text: $search.query, prompt: Text("Search clipboard").foregroundColor(rowText))
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
                        ForEach(items) { item in
                            ClipboardRow(item: item, theme: theme, textColor: rowText, design: design)
                        }
                        if items.isEmpty {
                            Text(history.items.isEmpty ? "Copy some text and it shows up here." : "Nothing matches “\(search.query)”.")
                                .font(.system(size: 12, design: design))
                                .foregroundStyle(text)
                                .multilineTextAlignment(.center)
                                .padding(.top, 30)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
            } else {
                VStack(spacing: 10) {
                    Text("Clipboard history is off.")
                        .font(.system(size: 12.5, weight: .semibold, design: design))
                        .foregroundStyle(text)
                    Text("Keyli keeps the last \(ClipboardHistory.maxItems) text items you copy, in memory only. Copies from password managers are skipped.")
                        .font(.system(size: 11.5, design: design))
                        .foregroundStyle(text.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Button("Turn On") {
                        configStore.config.clipboardHistoryEnabled = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: design))
                    .foregroundStyle(accent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyboardBackdrop(theme: SnippetsAppearance.backdrop(for: theme)))
        .preferredColorScheme(theme.isDarkBackground ? .dark : .light)
        .tint(accent)
        .ignoresSafeArea()
    }
}

final class ClipboardRowHover: ObservableObject {
    @Published var isHovered = false
}

struct ClipboardRow: View {
    let item: ClipboardItem
    let theme: KeyboardTheme
    let textColor: Color
    let design: Font.Design
    @StateObject private var hover = ClipboardRowHover()

    var body: some View {
        let preview = item.text
            .replacingOccurrences(of: "\n", with: " ⏎ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        HStack(spacing: 8) {
            Button {
                ClipboardHistory.shared.paste(item)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview)
                        .font(.system(size: 12, design: design))
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.date, style: .relative)
                        .font(.system(size: 10, design: design))
                        .foregroundStyle(textColor.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paste \(preview)")

            if hover.isHovered {
                Button {
                    ClipboardHistory.shared.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(textColor.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Remove from history")
                .accessibilityLabel("Remove from history")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(hex: theme.keycapBaseColorHex), in: RoundedRectangle(cornerRadius: min(9, CGFloat(theme.cornerRadius)), style: .continuous))
        .onHover { hover.isHovered = $0 }
    }
}

public final class ClipboardPanelController {
    public static let shared = ClipboardPanelController()

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

    private func makePanel() -> SnippetsWindow {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let keyboard = PanelManager.shared.isFloatingVisible ? PanelManager.shared.getOrCreateFloatingPanel().frame : nil
        var frame = SnippetsPanelController.initialFrame(keyboard: keyboard, screen: screen)
        if SnippetsPanelController.shared.isVisible {
            frame = frame.offsetBy(dx: 0, dy: -min(60, frame.minY - screen.minY))
        }
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
        let host = NSHostingView(rootView: ClipboardPanelView(search: search) { [weak self] in self?.hide() })
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }
}
