import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InstalledApp: Identifiable, Sendable {
    let bundleIdentifier: String
    let name: String
    let url: URL
    let isBackground: Bool

    var id: String { bundleIdentifier.lowercased() }
}

enum InstalledAppCatalog {
    static var searchRoots: [URL] {
        [URL(fileURLWithPath: "/Applications"),
         URL(fileURLWithPath: "/System/Applications"),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
         URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"),
         URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]
    }

    static func application(at url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return nil }
        let info = bundle.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
        func flag(_ key: String) -> Bool {
            if let value = info[key] as? NSNumber { return value.boolValue }
            return ["true", "yes", "1"].contains((info[key] as? String)?.lowercased() ?? "")
        }
        return InstalledApp(bundleIdentifier: identifier, name: name, url: url,
                            isBackground: flag("LSUIElement") || flag("LSBackgroundOnly"))
    }

    static func scan(roots: [URL], running: [InstalledApp]) -> [InstalledApp] {
        var apps: [String: InstalledApp] = [:]
        for app in running { apps[app.id] = app }
        for root in roots {
            if Task.isCancelled { return [] }
            if root.pathExtension.lowercased() == "app" {
                if let app = application(at: root) { apps[app.id] = app }
                continue
            }
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
                                                            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in files {
                if Task.isCancelled { return [] }
                guard url.pathExtension.lowercased() == "app", let app = application(at: url) else { continue }
                // Prefer the first installed copy over duplicates or a running helper.
                if let existing = apps[app.id], existing.url.path.hasPrefix("/Applications/") { continue }
                apps[app.id] = app
            }
        }
        return apps.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func matching(_ apps: [InstalledApp], excluding existing: [String], query: String,
                         showBackground: Bool) -> [InstalledApp] {
        let excluded = Set(existing.map { $0.lowercased() })
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return apps.filter {
            !excluded.contains($0.id) && (showBackground || !$0.isBackground)
                && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
                    || $0.bundleIdentifier.localizedCaseInsensitiveContains(query))
        }
    }
}

private final class InstalledAppPickerState: ObservableObject {
    @Published var applications: [InstalledApp] = []
    @Published var selected: Set<String> = []
    @Published var query = ""
    @Published var showBackground = false
    @Published var isLoading = true
}

struct InstalledAppPicker: View {
    let existingIdentifiers: [String]
    let onAdd: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = InstalledAppPickerState()

    private var visibleApps: [InstalledApp] {
        InstalledAppCatalog.matching(state.applications, excluding: existingIdentifiers,
                                     query: state.query, showBackground: state.showBackground)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Apps")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                TextField("Search apps", text: $state.query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search apps")
                Toggle("Show background apps", isOn: $state.showBackground)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5, weight: .medium))
                    .fixedSize()
            }

            VStack(spacing: 0) {
                if state.isLoading {
                    ProgressView("Finding installed apps…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visibleApps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: state.query.isEmpty ? "app.dashed" : "magnifyingglass")
                            .font(.system(size: 24))
                            .accessibilityHidden(true)
                        Text(state.query.isEmpty ? "No apps available" : "No matching apps")
                            .font(.system(size: 13, weight: .medium))
                        Text(state.query.isEmpty ? "Apps already added are hidden. Try showing background apps or Browse…." : "Try another name or bundle identifier.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    selectAll
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(visibleApps) { app in
                                Toggle(isOn: Binding(
                                    get: { state.selected.contains(app.id) },
                                    set: { if $0 { state.selected.insert(app.id) } else { state.selected.remove(app.id) } }
                                )) {
                                    HStack(spacing: 8) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                            .resizable().frame(width: 18, height: 18)
                                            .accessibilityHidden(true)
                                        Text(app.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        if app.isBackground {
                                            Text("Background").font(.system(size: 10)).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .toggleStyle(.checkbox)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .help(app.bundleIdentifier)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.09), lineWidth: 0.5))

            HStack(spacing: 12) {
                Button("Browse…", action: browse)
                    .buttonStyle(SettingsSecondaryButtonStyle())
                Text("\(state.selected.count) selected")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(state.selected.count == 1 ? "Add App" : "Add Apps") {
                    onAdd(state.applications.filter { state.selected.contains($0.id) }.map(\.bundleIdentifier))
                    dismiss()
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(state.selected.isEmpty)
                .opacity(state.selected.isEmpty ? 0.45 : 1)
            }
        }
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 500, height: 520)
        .tint(KeyliChrome.accent)
        .background {
            GlassFill(shape: Rectangle()).ignoresSafeArea()
        }
        .task {
            let running = NSWorkspace.shared.runningApplications.compactMap { app -> InstalledApp? in
                guard !app.isTerminated, let url = app.bundleURL else { return nil }
                return InstalledAppCatalog.application(at: url)
            }
            let scan = Task.detached(priority: .userInitiated) {
                InstalledAppCatalog.scan(roots: InstalledAppCatalog.searchRoots, running: running)
            }
            let result = await withTaskCancellationHandler { await scan.value } onCancel: { scan.cancel() }
            guard !Task.isCancelled else { return }
            state.applications = result
            state.isLoading = false
        }
    }

    private var selectAll: some View {
        let ids = Set(visibleApps.map(\.id))
        let allSelected = !ids.isEmpty && ids.isSubset(of: state.selected)
        return HStack {
            Toggle(allSelected ? "Deselect All" : "Select All", isOn: Binding(
                get: { allSelected },
                set: { if $0 { state.selected.formUnion(ids) } else { state.selected.subtract(ids) } }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(ids.count == 1 ? "1 app" : "\(ids.count) apps").foregroundStyle(.secondary)
        }
        .padding(10)
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Select"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let app = InstalledAppCatalog.application(at: url),
                  !existingIdentifiers.contains(where: { $0.lowercased() == app.id }) else { continue }
            if !state.applications.contains(where: { $0.id == app.id }) { state.applications.append(app) }
            state.selected.insert(app.id)
        }
    }
}
