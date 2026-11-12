import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class ThemeStudioUIState: ObservableObject {
    @Published var showDeleteConfirmation: Bool = false
    @Published var showImportError: Bool = false
    @Published var statusMessage: String? = nil

    func showStatus(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }
}

public struct ThemeStudioView: View {
    @ObservedObject public var themeManager: ThemeManager = .shared
    @ObservedObject public var keyboardState: KeyboardState = .shared

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

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 280)
        } detail: {
            HStack(spacing: 0) {
                previewPane
                Divider()
                inspector
                    .frame(width: 310)
            }
        }
        .navigationTitle("Theme Studio")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    themeManager.duplicateTheme(selectedTheme)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .help("Duplicate the selected theme")

                Button {
                    importTheme()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import a theme from a JSON file")

                Menu {
                    Button("Export to File…") {
                        exportTheme()
                    }
                    Button("Copy as JSON") {
                        copyJson()
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export the selected theme")

                Button {
                    uiState.showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!isEditable)
                .help("Delete the selected theme")
            }
        }
        .frame(minWidth: 900, minHeight: 520)
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

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: Binding<String?>(
            get: { themeManager.currentTheme.id },
            set: { id in
                if let id = id {
                    themeManager.selectTheme(byId: id)
                }
            }
        )) {
            Section("Built-in") {
                ForEach(themeManager.availableThemes.filter { $0.isBuiltIn }) { theme in
                    themeRow(themeManager.resolved(theme))
                        .tag(theme.id)
                }
            }

            if !themeManager.customThemes.isEmpty {
                Section("My Themes") {
                    ForEach(themeManager.customThemes) { theme in
                        themeRow(theme)
                            .tag(theme.id)
                            .contextMenu {
                                Button("Duplicate") {
                                    themeManager.duplicateTheme(theme)
                                }
                                Button("Delete", role: .destructive) {
                                    themeManager.deleteCustomTheme(theme)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func themeRow(_ theme: KeyboardTheme) -> some View {
        HStack(spacing: 8) {
            ThemeSwatchView(theme: theme, size: CGSize(width: 30, height: 20))
            Text(theme.name)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Preview

    private var previewPane: some View {
        let layout = keyboardState.currentLayout
        let aspect = CGFloat(layout.unitWidth / max(1, layout.unitHeight))

        return VStack(spacing: 14) {
            Spacer(minLength: 0)

            KeyboardView(state: keyboardState, showStatusBar: false)
                .padding(12)
                .background(KeyboardBackdrop(theme: keyboardState.currentTheme))
                .aspectRatio(aspect, contentMode: .fit)
                .frame(maxWidth: 780)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

            Text(uiState.statusMessage ?? "Click keys to preview press states. Changes apply to every keyboard right away.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: - Inspector

    private var inspector: some View {
        Form {
            if isEditable {
                Section("Name") {
                    TextField("Name", text: binding(\.name), prompt: Text("Theme name"))
                        .labelsHidden()
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Built-in themes can’t be changed. Duplicate this theme to customize it.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Duplicate to Customize") {
                            themeManager.duplicateTheme(selectedTheme)
                        }
                    }
                }
            }

            Section("Colors") {
                colorRow("Background", \.backgroundColorHex)
                colorRow("Keys", \.keycapBaseColorHex)
                colorRow("Modifier keys", \.modifierKeyColorHex)
                colorRow("Pressed key", \.keycapActiveColorHex)
                colorRow("Key labels", \.keycapTextColorHex)
                colorRow("Accent", \.accentColorHex)
                colorRow("Border", \.borderColorHex)
            }
            .disabled(!isEditable)

            Section("Keys") {
                Picker("Style", selection: binding(\.keycapStyle)) {
                    ForEach(KeycapStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }

                Picker("Font", selection: binding(\.fontDesign)) {
                    Text("System").tag("default")
                    Text("Rounded").tag("rounded")
                    Text("Monospaced").tag("monospaced")
                    Text("Serif").tag("serif")
                }

                sliderRow("Corner radius", \.cornerRadius, in: 1...14, format: "%.0f pt")
                sliderRow("Spacing", \.keySpacing, in: 2...10, format: "%.1f pt")
                sliderRow("Elevation", \.keyElevation, in: 0...6, format: "%.1f pt")
                sliderRow("Border width", \.borderWidth, in: 0...3, format: "%.1f pt")
                sliderRow("Border opacity", \.borderOpacity, in: 0...1, format: "%.0f%%", scale: 100)
            }
            .disabled(!isEditable)

            Section("Background") {
                Toggle("Blur content behind keyboard", isOn: binding(\.backgroundBlur))
                sliderRow("Opacity", \.backgroundOpacity, in: 0.1...1.0, format: "%.0f%%", scale: 100)
            }
            .disabled(!isEditable)
        }
        .formStyle(.grouped)
    }

    // MARK: - Row Helpers

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

    @ViewBuilder
    private func colorRow(_ title: String, _ keyPath: WritableKeyPath<KeyboardTheme, String>) -> some View {
        let hex = binding(keyPath)
        ColorPicker(
            title,
            selection: Binding(
                get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.toHex() }
            ),
            supportsOpacity: false
        )
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
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue * scale))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }

    // MARK: - Actions

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
