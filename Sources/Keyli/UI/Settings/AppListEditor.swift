import SwiftUI
import AppKit

private final class AppListEditorState: ObservableObject {
    @Published var showsAppPicker = false
}

public struct AppListEditor: View {
    @StateObject private var state = AppListEditorState()
    @Binding public var bundleIds: [String]
    public var emptyText: String

    public init(bundleIds: Binding<[String]>, emptyText: String) {
        self._bundleIds = bundleIds
        self.emptyText = emptyText
    }

    public static func appInfo(for bundleId: String) -> (name: String, icon: NSImage?) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return (bundleId, nil)
        }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return (name, NSWorkspace.shared.icon(forFile: url.path))
    }

    public static func adding(_ bundleId: String, to list: [String]) -> [String] {
        list.contains(bundleId) ? list : list + [bundleId]
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if bundleIds.isEmpty {
                Text(emptyText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            ForEach(bundleIds, id: \.self) { bundleId in
                let info = Self.appInfo(for: bundleId)
                HStack(spacing: 8) {
                    if let icon = info.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                    }
                    Text(info.name)
                        .font(.system(size: 12))
                    Spacer(minLength: 0)
                    Button {
                        bundleIds.removeAll { $0 == bundleId }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(info.name)")
                }
                .frame(height: 24)
            }
            Button("Add Apps…") { state.showsAppPicker = true }
            .buttonStyle(SettingsSecondaryButtonStyle())
            .padding(.top, 2)
        }
        .padding(.leading, 33)
        .padding(.trailing, 10)
        .sheet(isPresented: $state.showsAppPicker) {
            InstalledAppPicker(existingIdentifiers: bundleIds) { identifiers in
                for identifier in identifiers {
                    bundleIds = Self.adding(identifier, to: bundleIds)
                }
            }
        }
    }
}
