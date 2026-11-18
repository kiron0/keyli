import SwiftUI
import AppKit

final class RemapEditorState: ObservableObject {
    @Published var selectedKeyId: String?
    @Published var hoveredKeyId: String?
    @Published var showResetConfirmation = false
    @Published var originals: [String: KeyboardKey] = [:]
    var originalsLayoutId: String?
}

public struct RemapTabView: View {
    @ObservedObject private var configStore: ConfigStore = .shared
    @ObservedObject private var state: KeyboardState = .shared
    @StateObject private var editor = RemapEditorState()
    @StateObject private var recorder = SnippetRecorder()

    public init() {}

    public var body: some View {
        let layout = state.currentLayout
        let remaps = configStore.config.keyRemaps
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Keys", symbol: "keyboard")

            Text("Click a key to change what it types or does. Dots mark changed keys. Shift, Control, Option, Command, Caps Lock and fn stay as they are.")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 33)

            RemapKeyboardPicker(
                layout: layout,
                theme: state.currentTheme,
                remappedIds: Set(remaps.map(\.keyId)),
                editor: editor
            )
            .padding(.leading, 33)
            .padding(.trailing, 10)
            .padding(.vertical, 4)

            if let id = editor.selectedKeyId, let key = layout.keys.first(where: { $0.id == id }) {
                editorFields(for: key)
            }

            SettingsSectionHeader(title: "Layouts", symbol: "character.textbox")

            SettingsRow {
                let active = KeyRemapper.activePreset(in: remaps)
                Button("Standard") {
                    configStore.config.keyRemaps = KeyRemapper.removingPresets(from: remaps)
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                ForEach(RemapPreset.allCases) { preset in
                    if active == preset {
                        Button(preset.title) {}
                            .buttonStyle(SettingsPrimaryButtonStyle())
                    } else {
                        Button(preset.title) {
                            configStore.config.keyRemaps = KeyRemapper.applying(preset, to: remaps)
                        }
                        .buttonStyle(SettingsSecondaryButtonStyle())
                    }
                }
            }

            Text("Layouts change the letters on Keyli's keys. Use them with the ABC or U.S. input source; if your Mac already uses Dvorak or Colemak, keep Standard.")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 33)

            SettingsSectionHeader(title: "Reset", symbol: "arrow.counterclockwise")

            SettingsRow {
                Button("Reset All Keys…") {
                    editor.showResetConfirmation = true
                }
                .buttonStyle(SettingsSecondaryButtonStyle(isDestructive: true))
                .disabled(remaps.isEmpty)

                Text(remaps.isEmpty ? "All keys work as usual." : (remaps.count == 1 ? "1 key changed." : "\(remaps.count) keys changed."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
            }
        }
        .onAppear { refreshOriginals() }
        .onChange(of: layout.id) { _, _ in refreshOriginals() }
        .onChange(of: configStore.config.showNumericKeypad) { _, _ in refreshOriginals(force: true) }
        .onDisappear { recorder.stop() }
        .confirmationDialog("Reset every changed key?", isPresented: $editor.showResetConfirmation) {
            Button("Reset", role: .destructive) {
                configStore.config.keyRemaps = []
                editor.selectedKeyId = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All keys go back to typing and doing what they normally do.")
        }
    }

    private func refreshOriginals(force: Bool = false) {
        let layout = state.currentLayout
        guard force || editor.originalsLayoutId != layout.id else { return }
        let plain = KeyboardLayoutManager.shared.generateLayout(
            geometry: layout.geometryType,
            numericKeypad: configStore.config.showNumericKeypad
        )
        editor.originals = Dictionary(uniqueKeysWithValues: plain.keys.map { ($0.id, $0) })
        editor.originalsLayoutId = layout.id
    }

    private func originalName(for key: KeyboardKey) -> String {
        let original = editor.originals[key.id] ?? key
        let label = original.labels.defaultLabel
        switch original.id {
        case "k_space": return "Space"
        case "k_lock": return "Lock"
        default:
            if label.count == 1 { return label.uppercased() }
            return label.prefix(1).uppercased() + label.dropFirst()
        }
    }

    private func remap(for id: String) -> KeyRemap? {
        configStore.config.keyRemaps.first { $0.keyId == id }
    }

    private func setRemap(_ remap: KeyRemap?, for id: String) {
        var list = configStore.config.keyRemaps.filter { $0.keyId != id }
        if let remap { list.append(remap) }
        if list != configStore.config.keyRemaps {
            configStore.config.keyRemaps = list
        }
    }

    private func update(_ id: String, _ change: (inout KeyRemap) -> Void) {
        guard var current = remap(for: id) else { return }
        change(&current)
        setRemap(current, for: id)
    }

    private func kindBinding(for key: KeyboardKey) -> Binding<String> {
        Binding(
            get: { remap(for: key.id)?.action.kindName ?? "default" },
            set: { kind in
                let label = remap(for: key.id)?.label
                let original = editor.originals[key.id] ?? key
                let action: RemapAction?
                switch kind {
                case "text":
                    let base = original.kind == .character && original.id != "k_space" ? original.labels.defaultLabel : ""
                    action = .text(base, shifted: nil)
                case "key":
                    action = .key(KeyRemapper.pressableKeys[0].code)
                case "shortcut":
                    action = .shortcut([])
                case "snippet":
                    action = .snippet(configStore.config.snippets.first?.id ?? "")
                case "disabled":
                    action = .disabled
                default:
                    action = nil
                }
                setRemap(action.map { KeyRemap(keyId: key.id, action: $0, label: label) }, for: key.id)
            }
        )
    }

    private func textBinding(for id: String) -> Binding<String> {
        Binding(
            get: {
                if case .text(let text, _)? = remap(for: id)?.action { return text }
                return ""
            },
            set: { newValue in
                update(id) { remap in
                    if case .text(_, let shifted) = remap.action {
                        remap.action = .text(newValue, shifted: shifted)
                    }
                }
            }
        )
    }

    private func shiftedBinding(for id: String) -> Binding<String> {
        Binding(
            get: {
                if case .text(_, let shifted)? = remap(for: id)?.action { return shifted ?? "" }
                return ""
            },
            set: { newValue in
                update(id) { remap in
                    if case .text(let text, _) = remap.action {
                        remap.action = .text(text, shifted: newValue.isEmpty ? nil : newValue)
                    }
                }
            }
        )
    }

    private func keyBinding(for id: String) -> Binding<UInt16> {
        Binding(
            get: {
                if case .key(let code)? = remap(for: id)?.action { return code }
                return KeyRemapper.pressableKeys[0].code
            },
            set: { code in
                update(id) { $0.action = .key(code) }
            }
        )
    }

    private func snippetBinding(for id: String) -> Binding<String> {
        Binding(
            get: {
                if case .snippet(let snippetId)? = remap(for: id)?.action { return snippetId }
                return ""
            },
            set: { snippetId in
                update(id) { $0.action = .snippet(snippetId) }
            }
        )
    }

    private func labelBinding(for id: String) -> Binding<String> {
        Binding(
            get: { remap(for: id)?.label ?? "" },
            set: { newValue in
                update(id) { $0.label = newValue.isEmpty ? nil : newValue }
            }
        )
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 130, alignment: .leading)
    }

    @ViewBuilder
    private func editorFields(for key: KeyboardKey) -> some View {
        let current = remap(for: key.id)
        SettingsRow {
            fieldLabel("Key")
            Text(originalName(for: key))
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            Button("Reset Key") {
                setRemap(nil, for: key.id)
            }
            .buttonStyle(SettingsSecondaryButtonStyle())
            .disabled(current == nil)
        }

        SettingsRow {
            fieldLabel("When pressed")
            SettingsMenuPicker(
                "When pressed",
                selection: kindBinding(for: key),
                options: [
                    SettingsMenuOption("default", "Works as usual"),
                    SettingsMenuOption("text", "Types text"),
                    SettingsMenuOption("key", "Presses another key"),
                    SettingsMenuOption("shortcut", "Sends a shortcut"),
                    SettingsMenuOption("snippet", "Runs a snippet"),
                    SettingsMenuOption("disabled", "Does nothing")
                ]
            )
        }

        switch current?.action {
        case .text?:
            SettingsRow {
                fieldLabel("Types")
                TextField("Text", text: textBinding(for: key.id))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                Text("With shift")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                TextField("Automatic", text: shiftedBinding(for: key.id))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
            }
        case .key?:
            SettingsRow {
                fieldLabel("Presses")
                SettingsMenuPicker(
                    "Presses",
                    selection: keyBinding(for: key.id),
                    options: KeyRemapper.pressableKeys.map { SettingsMenuOption($0.code, $0.name) }
                )
            }
        case .shortcut(let keys)?:
            SettingsRow {
                fieldLabel("Sends")
                Button(recorder.recordingId == key.id ? "Press the shortcut…" : (keys.isEmpty ? "Record Shortcut" : keys.joined(separator: " "))) {
                    recorder.recordingId = key.id
                    recorder.start { id, recorded in
                        update(id) { $0.action = .shortcut(recorded) }
                    }
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                if recorder.recordingId == key.id {
                    Text("Esc cancels")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                }
            }
        case .snippet?:
            SettingsRow {
                fieldLabel("Runs")
                if configStore.config.snippets.isEmpty {
                    Text("No snippets yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                    Button("Add Snippets…") {
                        SettingsWindowController.shared.showSettings(tab: .typing)
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                } else {
                    SettingsMenuPicker(
                        "Runs",
                        selection: snippetBinding(for: key.id),
                        options: configStore.config.snippets.map { SettingsMenuOption($0.id, $0.title) }
                    )
                }
            }
        case .disabled?, nil:
            EmptyView()
        }

        if let current, current.action != .disabled {
            SettingsRow {
                fieldLabel("Key label")
                TextField(KeyRemapper.label(for: KeyRemap(keyId: key.id, action: current.action), snippets: configStore.config.snippets), text: labelBinding(for: key.id))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                Text("Optional")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

struct RemapKeyboardPicker: View {
    let layout: KeyboardLayout
    let theme: KeyboardTheme
    let remappedIds: Set<String>
    @ObservedObject var editor: RemapEditorState

    var body: some View {
        GeometryReader { geo in
            let inset = geo.size.width * 0.02
            let size = CGSize(width: max(1, geo.size.width - inset * 2), height: max(1, geo.size.height - inset * 2))
            let geometry = KeyboardGeometry(layout: layout, size: size, spacing: CGFloat(theme.keySpacing))
            let renderer = KeyboardRenderer(
                theme: theme,
                modifiers: KeyModifierSnapshot(),
                physicalKeyCodes: [],
                virtualKeyId: nil,
                localPressedKeyId: editor.selectedKeyId,
                hoveredKeyId: editor.hoveredKeyId
            )
            let dot = Color(hex: theme.accentColorHex)
            let selectedId = editor.selectedKeyId
            Canvas { context, _ in
                for key in layout.keys {
                    let rect = geometry.frame(for: key)
                    renderer.draw(key: key, in: rect, context: context)
                    if !KeyRemapper.isRemappable(key) {
                        context.fill(Path(roundedRect: rect, cornerRadius: CGFloat(theme.cornerRadius)), with: .color(Color.black.opacity(0.28)))
                    }
                    if remappedIds.contains(key.id) {
                        let side = max(4, min(rect.width, rect.height) * 0.14)
                        context.fill(Path(ellipseIn: CGRect(x: rect.maxX - side * 1.8, y: rect.minY + side * 0.8, width: side, height: side)), with: .color(dot))
                    }
                    if key.id == selectedId {
                        context.stroke(Path(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerRadius: CGFloat(theme.cornerRadius) + 2), with: .color(dot), lineWidth: 2)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { point in
                guard let key = geometry.key(at: point), KeyRemapper.isRemappable(key) else { return }
                editor.selectedKeyId = editor.selectedKeyId == key.id ? nil : key.id
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    let id = geometry.key(at: point).flatMap { KeyRemapper.isRemappable($0) ? $0.id : nil }
                    if editor.hoveredKeyId != id { editor.hoveredKeyId = id }
                case .ended:
                    if editor.hoveredKeyId != nil { editor.hoveredKeyId = nil }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Keys to remap")
            .accessibilityChildren {
                ZStack(alignment: .topLeading) {
                    ForEach(layout.keys.filter(KeyRemapper.isRemappable)) { key in
                        let rect = geometry.frame(for: key)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .accessibilityLabel(key.labels.defaultLabel.isEmpty ? key.id : key.labels.defaultLabel)
                            .accessibilityValue(remappedIds.contains(key.id) ? "changed" : "")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAddTraits(key.id == selectedId ? .isSelected : [])
                            .accessibilityAction {
                                editor.selectedKeyId = key.id
                            }
                    }
                }
                .frame(width: size.width, height: size.height)
            }
            .padding(inset)
            .background(KeyboardBackdrop(theme: theme, cornerRadius: 12))
        }
        .aspectRatio(KeyliConstants.keyboardAspect(layout) * 0.98, contentMode: .fit)
    }
}
