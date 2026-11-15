import SwiftUI
import AppKit

final class SnippetRecorder: ObservableObject {
    @Published var recordingId: String?
    private var monitor: Any?

    func start(onKeys: @escaping (String, [String]) -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let id = self.recordingId else { return event }
            if event.keyCode == 53 {
                DispatchQueue.main.async { self.recordingId = nil }
                return nil
            }
            let keys = ShortcutManager.keys(keyCode: event.keyCode, flags: event.modifierFlags)
            guard !keys.isEmpty else { return nil }
            DispatchQueue.main.async {
                onKeys(id, keys)
                self.recordingId = nil
            }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recordingId = nil
    }
}

public struct SnippetEditor: View {
    @ObservedObject private var configStore: ConfigStore = .shared
    @StateObject private var recorder = SnippetRecorder()

    public init() {}

    private func binding(_ id: String) -> Binding<Snippet>? {
        guard configStore.config.snippets.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { configStore.config.snippets.first { $0.id == id } ?? Snippet(title: "", kind: .text) },
            set: { updated in
                if let index = configStore.config.snippets.firstIndex(where: { $0.id == id }) {
                    configStore.config.snippets[index] = updated
                }
            }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(configStore.config.snippets) { snippet in
                if let item = binding(snippet.id) {
                    row(item)
                }
            }
            HStack(spacing: 8) {
                Button("Add Text Snippet") {
                    configStore.config.snippets.append(Snippet(title: "Snippet \(configStore.config.snippets.count + 1)", kind: .text, text: ""))
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                Button("Add Shortcut Key") {
                    configStore.config.snippets.append(Snippet(title: "Shortcut \(configStore.config.snippets.count + 1)", kind: .shortcut))
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
            }
        }
        .padding(.leading, 33)
        .padding(.trailing, 10)
        .onAppear {
            recorder.start { id, keys in
                if let index = configStore.config.snippets.firstIndex(where: { $0.id == id }) {
                    configStore.config.snippets[index].keys = keys
                }
            }
        }
        .onDisappear { recorder.stop() }
    }

    private func row(_ item: Binding<Snippet>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.wrappedValue.kind == .shortcut ? "command" : "text.quote")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(KeyliChrome.accent)
                .frame(width: 22)
                .accessibilityHidden(true)
            TextField("Title", text: item.title)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 120)
            if item.wrappedValue.kind == .text {
                TextField("Text to type", text: item.text)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            } else {
                Button {
                    recorder.recordingId = item.wrappedValue.id
                } label: {
                    Text(recorder.recordingId == item.wrappedValue.id ? "Press keys…" : (item.wrappedValue.keys.isEmpty ? "Record Shortcut" : item.wrappedValue.keys.joined(separator: " ")))
                        .font(.system(size: 11.5, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
            }
            Button {
                configStore.config.snippets.removeAll { $0.id == item.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(item.wrappedValue.title)")
        }
    }
}
