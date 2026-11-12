import SwiftUI

public struct PermissionsTabView: View {
    @ObservedObject public var permissionsManager: PermissionsManager = .shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                // Accessibility Status
                permissionRow(
                    title: "Accessibility",
                    description: "Lets Keyli type into other apps when you click keys.",
                    icon: "accessibility",
                    isGranted: permissionsManager.hasPostEventPermission,
                    onRequest: {
                        permissionsManager.requestAccessibility()
                        permissionsManager.openAccessibilityPreferences()
                    }
                )

                // Input Monitoring Status
                permissionRow(
                    title: "Input Monitoring",
                    description: "Lets Keyli highlight keys you press on the physical keyboard. Optional.",
                    icon: "keyboard",
                    isGranted: permissionsManager.hasInputMonitoringPermission,
                    onRequest: {
                        permissionsManager.requestInputMonitoring()
                        permissionsManager.openInputMonitoringPreferences()
                    }
                )
            } footer: {
                Text("Viewing the keyboard needs no permission. If a permission stays off after you allow it in System Settings, quit and reopen Keyli.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            permissionsManager.checkPermissions()
            permissionsManager.startPollingForPermissions()
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        description: String,
        icon: String,
        isGranted: Bool,
        onRequest: @escaping () -> Void
    ) -> some View {
        LabeledContent {
            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Allow…", action: onRequest)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.tint)
            }
        }
    }
}
