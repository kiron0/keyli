import SwiftUI
import AppKit

final class ShortcutRecorderState: ObservableObject {
    @Published var recording: ShortcutAction?
    private var monitor: Any?

    func start(manager: ShortcutManager) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak manager] event in
            guard let self, let manager, let action = self.recording else { return event }
            guard event.window == NSApp.keyWindow else { return event }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 53 && flags.isEmpty {
                DispatchQueue.main.async { self.recording = nil }
                return nil
            }
            if event.keyCode == 51 && flags.isEmpty {
                DispatchQueue.main.async {
                    manager.setKeys([], for: action)
                    self.recording = nil
                }
                return nil
            }
            let keys = ShortcutManager.keys(keyCode: event.keyCode, flags: event.modifierFlags)
            guard !keys.isEmpty else { return nil }
            DispatchQueue.main.async {
                if manager.setKeys(keys, for: action) {
                    self.recording = nil
                }
            }
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recording = nil
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

public struct ShortcutsTabView: View {
    @ObservedObject private var manager = ShortcutManager.shared
    @StateObject private var recorder = ShortcutRecorderState()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ShortcutAction.Group.allCases, id: \.self) { group in
                SettingsSectionHeader(title: group.rawValue, symbol: group.symbol)

                let actions = ShortcutAction.allCases.filter { $0.group == group }
                ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                    if index > 0 {
                        Divider()
                            .opacity(0.35)
                            .padding(.leading, 42)
                    }
                    row(action)
                }
            }

            if let error = manager.shortcutError ?? manager.registrationError {
                errorBanner(error)
                    .padding(.top, 10)
            }

            SettingsSectionHeader(title: "Built-in", symbol: "command")

            SettingsInlineNote(
                symbol: "menubar.rectangle",
                title: "Menu bar menu",
                detail: "⌘ , opens Settings, ⌘ U checks for updates and ⌘ Q quits while the Keyli menu is open. ^ ⌘ Space opens Emoji & Symbols everywhere."
            )
            .padding(.leading, 33)

            SettingsRow {
                Button("Reset Shortcuts") {
                    recorder.recording = nil
                    manager.resetToDefaults()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())

                Text("Click a shortcut to record. Esc cancels, ⌫ clears.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.top, 6)
        }
        .onAppear { recorder.start(manager: manager) }
        .onDisappear { recorder.stop() }
    }

    private func row(_ action: ShortcutAction) -> some View {
        let binding = manager.binding(for: action)
        let active = binding.isEnabled
        let isRecording = recorder.recording == action

        return HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    manager.setEnabled(!active, for: action)
                }
            } label: {
                SettingsSwitchIndicator(isOn: active)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enable \(action.title)")
            .accessibilityValue(active ? "On" : "Off")

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? KeyliChrome.accent.opacity(0.12) : Color.primary.opacity(0.05))
                    .frame(width: 28, height: 28)
                Image(systemName: action.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? KeyliChrome.accent : Color.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                Text(action.detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isRecording {
                Button {
                    recorder.recording = nil
                } label: {
                    HStack(spacing: 5) {
                        Text("Press keys…")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Text("esc to cancel")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(KeyliChrome.accent.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(KeyliChrome.accent, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            } else if binding.keys.isEmpty {
                Button {
                    recorder.recording = action
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Record Shortcut")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(KeyliChrome.accent.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(KeyliChrome.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Button {
                        recorder.recording = action
                    } label: {
                        HStack(spacing: 3) {
                            ForEach(Array(binding.keys.enumerated()), id: \.offset) { _, key in
                                Text(key)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(active ? Color.primary : Color.secondary)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .padding(.horizontal, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .fill(Color.primary.opacity(active ? 0.12 : 0.05))
                                    )
                            }
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(active ? 0.06 : 0.03)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Click to change shortcut")
                    .accessibilityLabel("\(action.title) shortcut \(binding.keys.joined(separator: " "))")

                    Button {
                        manager.setKeys([], for: action)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary.opacity(active ? 0.65 : 0.3))
                    }
                    .buttonStyle(.plain)
                    .help("Remove shortcut")
                    .accessibilityLabel("Remove \(action.title) shortcut")
                }
            }
        }
        .padding(.leading, 33)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .frame(minHeight: 40)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(width: 30, height: 30)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
        .padding(.leading, 33)
    }
}
