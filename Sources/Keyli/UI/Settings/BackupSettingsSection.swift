import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class BackupSectionState: ObservableObject {
    @Published var message: String?
    @Published var errorMessage: String?
    @Published var pendingRestore: URL?
}

public struct BackupSettingsSection: View {
    @ObservedObject private var configStore: ConfigStore = .shared
    @ObservedObject private var backup: SettingsBackup = .shared
    @StateObject private var ui = BackupSectionState()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionHeader(title: "Backup & Sync", symbol: "arrow.triangle.2.circlepath")

            SettingsRow {
                Button("Export Settings…", action: exportSettings)
                    .buttonStyle(SettingsSecondaryButtonStyle())
                Button("Import Settings…", action: chooseImport)
                    .buttonStyle(SettingsSecondaryButtonStyle())
                Text(ui.message ?? "Settings, shortcuts, custom themes and your personal dictionary.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }

            SettingsRow {
                Text("Sync folder")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 130, alignment: .leading)

                if let folder = backup.syncFolderURL {
                    Text(folder.lastPathComponent)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folder.path)
                    Button("Sync Now") {
                        backup.syncNow()
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                    Button("Stop Syncing") {
                        configStore.config.settingsSyncFolder = nil
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                } else {
                    Button("Choose Folder…", action: chooseSyncFolder)
                        .buttonStyle(SettingsSecondaryButtonStyle())
                }
            }

            Text(syncDetail)
                .font(.system(size: 10.5))
                .foregroundStyle(backup.syncError == nil ? Color.secondary : Color.red)
                .padding(.leading, 33)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog("Replace your Keyli settings?", isPresented: Binding(
            get: { ui.pendingRestore != nil },
            set: { if !$0 { ui.pendingRestore = nil } }
        )) {
            Button("Import", role: .destructive) {
                if let url = ui.pendingRestore {
                    importSettings(from: url)
                }
                ui.pendingRestore = nil
            }
            Button("Cancel", role: .cancel) {
                ui.pendingRestore = nil
            }
        } message: {
            Text("Settings and shortcuts are replaced by the backup. Themes and dictionary words from the backup are added. Window position and login item stay as they are.")
        }
        .alert("Keyli couldn't use that file", isPresented: Binding(
            get: { ui.errorMessage != nil },
            set: { if !$0 { ui.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ui.errorMessage ?? "")
        }
    }

    private var syncDetail: String {
        if let error = backup.syncError {
            return error
        }
        guard backup.syncFolderURL != nil else {
            return "Pick a folder in iCloud Drive, Dropbox or another synced place to keep Keyli the same on every Mac. If the folder already has Keyli settings, this Mac uses them."
        }
        if let date = backup.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "Changes sync automatically. Last synced \(formatter.localizedString(for: date, relativeTo: Date()))."
        }
        return "Changes sync automatically."
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Keyli Settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try backup.export(to: url)
            ui.message = "Saved “\(url.lastPathComponent)”."
        } catch {
            ui.errorMessage = "Keyli couldn't save the backup there. Choose another folder."
        }
    }

    private func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a Keyli settings backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ui.pendingRestore = url
    }

    private func importSettings(from url: URL) {
        do {
            try backup.restore(from: url)
            ui.message = "Imported “\(url.lastPathComponent)”."
        } catch {
            ui.errorMessage = (error as? LocalizedError)?.errorDescription ?? "That file isn't a Keyli settings backup."
        }
    }

    private func chooseSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Sync Here"
        panel.message = "Choose a folder that syncs between your Macs"
        let iCloud = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloud.path) {
            panel.directoryURL = iCloud
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        configStore.config.settingsSyncFolder = url.path
    }
}
