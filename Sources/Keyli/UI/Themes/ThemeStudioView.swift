import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class ThemeStudioUIState: ObservableObject {
    @Published var showDeleteConfirmation: Bool = false
    @Published var showImportError: Bool = false
    @Published var statusMessage: String? = nil
    @Published var searchText: String = ""

    func showStatus(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }
}

public enum ThemeStudioLayout {
    public static let windowSize = NSSize(width: 1060, height: 720)
    public static let sidebarWidth: CGFloat = 220
    public static let detailWidth: CGFloat = windowSize.width - sidebarWidth
    public static let detailHorizontalPadding: CGFloat = 28
    public static let contentWidth: CGFloat = detailWidth - detailHorizontalPadding * 2
    public static let columnSpacing: CGFloat = 18
    public static let columnWidth: CGFloat = (contentWidth - columnSpacing * 2) / 3
}

public struct ThemeStudioView: View {
    @ObservedObject public var themeManager: ThemeManager = .shared
    @StateObject private var uiState = ThemeStudioUIState()

    public init() {}

    private var selectedTheme: KeyboardTheme {
        themeManager.currentTheme
    }

    private var displayedTheme: KeyboardTheme {
        themeManager.resolved(themeManager.currentTheme)
    }

    private var isEditable: Bool {
        !selectedTheme.isBuiltIn
    }

    private var trimmedQuery: String {
        uiState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matches(_ theme: KeyboardTheme) -> Bool {
        trimmedQuery.isEmpty || theme.name.localizedCaseInsensitiveContains(trimmedQuery)
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(KeyliChrome.accent)
        .background {
            GlassFill(shape: Rectangle())
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .confirmationDialog(
            "Delete “\(selectedTheme.name)”?",
            isPresented: $uiState.showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                themeManager.deleteCustomTheme(selectedTheme)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This theme will be removed permanently.")
        }
        .alert("The theme couldn’t be imported", isPresented: $uiState.showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The file isn’t a valid Keyli theme.")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                TextField("Search themes…", text: $uiState.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 10)
            .padding(.top, 40)
            .padding(.bottom, 8)

            Divider().opacity(0.35)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    let custom = themeManager.customThemes.filter(matches)
                    if !custom.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            sectionTitle("My Themes")
                            ForEach(custom) { theme in
                                sidebarRow(theme)
                            }
                        }
                    }

                    let builtIn = themeManager.availableThemes.filter { $0.isBuiltIn && matches($0) }
                    if !builtIn.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            sectionTitle("Built-in (\(builtIn.count))")
                            ForEach(builtIn) { theme in
                                sidebarRow(theme)
                            }
                        }
                    }

                    if custom.isEmpty && builtIn.isEmpty {
                        Text("No matching themes")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .frame(width: ThemeStudioLayout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(KeyliChrome.cardBackground)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
    }

    private func sidebarRow(_ theme: KeyboardTheme) -> some View {
        ThemeSidebarRow(
            theme: theme,
            displayTheme: themeManager.resolved(theme),
            isSelected: selectedTheme.id == theme.id,
            onSelect: { themeManager.selectTheme(theme) },
            onDuplicate: { themeManager.duplicateTheme(theme) },
            onDelete: theme.isBuiltIn ? nil : { themeManager.deleteCustomTheme(theme) }
        )
        .equatable()
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            preview
            if !isEditable {
                SettingsInlineNote(
                    symbol: "lock.fill",
                    title: "Built-in themes can’t be changed",
                    detail: "Duplicate this theme to customize colors, keys and background."
                )
            }
            ScrollView(.vertical, showsIndicators: true) {
                inspector
                    .padding(.bottom, 24)
                    .frame(width: ThemeStudioLayout.contentWidth, alignment: .topLeading)
            }
        }
        .padding(.horizontal, ThemeStudioLayout.detailHorizontalPadding)
        .padding(.top, 40)
        .frame(width: ThemeStudioLayout.detailWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if isEditable {
                    TextField("Theme name", text: binding(\.name))
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .bold))
                        .accessibilityLabel("Theme name")
                } else {
                    Text(selectedTheme.name)
                        .font(.system(size: 20, weight: .bold))
                }
                Text(uiState.statusMessage ?? (isEditable ? "Custom theme. Changes apply to every keyboard right away." : "Built-in theme."))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Button("Duplicate") {
                    themeManager.duplicateTheme(selectedTheme)
                }
                .buttonStyle(SettingsPrimaryButtonStyle())

                Button("Import…") {
                    importTheme()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())

                Button("Export…") {
                    exportTheme()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .contextMenu {
                    Button("Copy as JSON") {
                        copyJson()
                    }
                }
                .help("Save the theme as a JSON file. Right-click to copy JSON instead.")

                if isEditable {
                    Button("Delete…") {
                        uiState.showDeleteConfirmation = true
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle(isDestructive: true))
                }
            }
        }
        .frame(width: ThemeStudioLayout.contentWidth)
    }

    private var preview: some View {
        ThemeStudioPreview()
    }

    private var inspector: some View {
        HStack(alignment: .top, spacing: ThemeStudioLayout.columnSpacing) {
            column {
                SettingsSectionHeader(title: "Colors", symbol: "paintpalette")
                colorRow("Background", \.backgroundColorHex)
                colorRow("Keys", \.keycapBaseColorHex)
                colorRow("Modifier keys", \.modifierKeyColorHex)
                colorRow("Pressed key", \.keycapActiveColorHex)
                colorRow("Key labels", \.keycapTextColorHex)
                colorRow("Accent", \.accentColorHex)
                colorRow("Border", \.borderColorHex)
            }

            column {
                SettingsSectionHeader(title: "Keys", symbol: "keyboard")
                pickerRow("Style") {
                    SettingsMenuPicker(
                        "Style",
                        selection: binding(\.keycapStyle),
                        options: KeycapStyle.allCases.map { SettingsMenuOption($0, $0.displayName) },
                        width: 150
                    )
                }
                pickerRow("Font") {
                    SettingsMenuPicker(
                        "Font",
                        selection: binding(\.fontDesign),
                        options: [
                            SettingsMenuOption("default", "System"),
                            SettingsMenuOption("rounded", "Rounded"),
                            SettingsMenuOption("monospaced", "Monospaced"),
                            SettingsMenuOption("serif", "Serif")
                        ],
                        width: 150
                    )
                }
                sliderRow("Corner radius", \.cornerRadius, in: 1...14, format: "%.0f pt")
                sliderRow("Spacing", \.keySpacing, in: 2...10, format: "%.1f pt")
                sliderRow("Elevation", \.keyElevation, in: 0...6, format: "%.1f pt")
            }

            column {
                SettingsSectionHeader(title: "Surface", symbol: "square.dashed")
                sliderRow("Border width", \.borderWidth, in: 0...3, format: "%.1f pt")
                sliderRow("Border opacity", \.borderOpacity, in: 0...1, format: "%.0f%%", scale: 100)
                sliderRow("Background opacity", \.backgroundOpacity, in: 0.1...1.0, format: "%.0f%%", scale: 100)
                toggleRow("Blur behind keyboard", binding(\.backgroundBlur))
            }
        }
        .disabled(!isEditable)
        .opacity(isEditable ? 1 : 0.55)
    }

    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .frame(width: ThemeStudioLayout.columnWidth, alignment: .topLeading)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<KeyboardTheme, Value>) -> Binding<Value> {
        Binding(
            get: { displayedTheme[keyPath: keyPath] },
            set: { newValue in
                var theme = themeManager.currentTheme
                guard !theme.isBuiltIn else { return }
                theme[keyPath: keyPath] = newValue
                themeManager.updateCustomTheme(theme)
            }
        )
    }

    private func rowLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary)
    }

    @ViewBuilder
    private func colorRow(_ title: String, _ keyPath: WritableKeyPath<KeyboardTheme, String>) -> some View {
        let hex = binding(keyPath)
        HStack(spacing: 8) {
            rowLabel(title)
            Spacer(minLength: 4)
            Text(hex.wrappedValue)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.secondary)
            ColorPicker(
                title,
                selection: Binding(
                    get: { Color(hex: hex.wrappedValue) },
                    set: { hex.wrappedValue = $0.toHex() }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
        }
        .frame(minHeight: 28)
        .padding(.leading, 33)
    }

    @ViewBuilder
    private func pickerRow<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            rowLabel(title)
            Spacer(minLength: 4)
            content()
        }
        .frame(minHeight: 30)
        .padding(.leading, 33)
    }

    @ViewBuilder
    private func sliderRow(
        _ title: String,
        _ keyPath: WritableKeyPath<KeyboardTheme, Double>,
        in range: ClosedRange<Double>,
        format: String,
        scale: Double = 1
    ) -> some View {
        let value = binding(keyPath)
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                rowLabel(title)
                Spacer()
                Text(String(format: format, value.wrappedValue * scale))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.secondary)
            }
            Slider(value: value, in: range)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
        .padding(.leading, 33)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func toggleRow(_ title: String, _ isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 9) {
                SettingsSwitchIndicator(isOn: isOn.wrappedValue)
                rowLabel(title)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
        .padding(.leading, 33)
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a Keyli theme file"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if themeManager.importTheme(from: url) == nil {
            uiState.showImportError = true
        }
    }

    private func exportTheme() {
        themeManager.flushPendingWrites()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(selectedTheme.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if themeManager.exportTheme(selectedTheme, to: url) {
            uiState.showStatus("Exported “\(selectedTheme.name)”.")
        }
    }

    private func copyJson() {
        if let json = themeManager.exportThemeJSON(selectedTheme) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            uiState.showStatus("Theme JSON copied.")
        }
    }
}

struct ThemeSidebarRow: View, Equatable {
    let theme: KeyboardTheme
    let displayTheme: KeyboardTheme
    let isSelected: Bool
    let onSelect: () -> Void
    let onDuplicate: () -> Void
    let onDelete: (() -> Void)?

    @StateObject private var hover = HoverUIState()

    static func == (lhs: ThemeSidebarRow, rhs: ThemeSidebarRow) -> Bool {
        lhs.displayTheme == rhs.displayTheme && lhs.isSelected == rhs.isSelected && lhs.theme.name == rhs.theme.name
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                ThemeSwatchView(theme: displayTheme, size: CGSize(width: 28, height: 18))
                Text(theme.name)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? KeyliChrome.accent.opacity(0.18) : (hover.isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            if hover.isHovered != hovering {
                hover.isHovered = hovering
            }
        }
        .contextMenu {
            Button("Duplicate", action: onDuplicate)
            if let onDelete = onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
    }
}

struct ThemeStudioPreview: View {
    @ObservedObject var keyboardState: KeyboardState = .shared

    var body: some View {
        let layout = keyboardState.currentLayout
        let previewWidth = ThemeStudioLayout.contentWidth - 120
        let keyboardHeight = (previewWidth - 24) / KeyliConstants.keyboardAspect(layout) + 24

        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )

            KeyboardView(state: keyboardState, showStatusBar: false, isInteractive: false)
                .padding(12)
                .frame(width: previewWidth, height: keyboardHeight)
                .background(KeyboardBackdrop(theme: keyboardState.currentTheme))
                .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        }
        .frame(width: ThemeStudioLayout.contentWidth, height: keyboardHeight + 36)
    }
}
