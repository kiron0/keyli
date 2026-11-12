import SwiftUI

public struct PermissionsTabView: View {
    @ObservedObject public var permissionsManager: PermissionsManager = .shared
    @ObservedObject public var configStore: ConfigStore = .shared

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsInlineNote(
                symbol: "hand.raised.fill",
                title: "macOS stays in control",
                detail: "Viewing the keyboard needs no permission. Turn any permission off in System Settings › Privacy & Security at any time."
            )

            SettingsSectionHeader(title: "Needed for Typing", symbol: "checkmark.shield")
            permissionCard(.accessibility)

            SettingsSectionHeader(title: "Optional", symbol: "slider.horizontal.3")
            permissionCard(.inputMonitoring)

            HStack(spacing: 10) {
                Button("Show Keyli in Finder") {
                    permissionsManager.revealAppInFinder()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .help("Drag Keyli into a System Settings list if it isn’t shown there.")

                Button("Relaunch Keyli") {
                    permissionsManager.relaunch()
                }
                .buttonStyle(SettingsSecondaryButtonStyle())
                .help("Some permission changes only apply after Keyli restarts.")

                Spacer(minLength: 0)
            }
            .padding(.top, 6)
        }
        .onAppear {
            permissionsManager.checkPermissions()
            permissionsManager.startPollingForPermissions()
        }
    }

    @ViewBuilder
    private func permissionCard(_ kind: PermissionKind) -> some View {
        let status = permissionsManager.status(of: kind)
        let isBusy = permissionsManager.busy.contains(kind)
        let needsAttention = status == .needsRepair
            || (kind == .accessibility && status != .granted)
            || (kind == .inputMonitoring && status != .granted && configStore.config.isPhysicalMonitoringEnabled)

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KeyliChrome.accent)
                .frame(width: 32, height: 32)
                .background(KeyliChrome.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(kind.title)
                        .font(.system(size: 12.5, weight: .semibold))
                    statusBadge(status)
                }
                Text(kind.purpose)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Used by: \(kind.usedBy)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                if let hint = hint(for: kind, status: status) {
                    Label(hint, systemImage: "info.circle")
                        .font(.system(size: 10.5))
                        .foregroundStyle(needsAttention ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    switch status {
                    case .granted:
                        Button("Manage") { permissionsManager.openSettings(kind) }
                            .buttonStyle(SettingsSecondaryButtonStyle())
                            .help("Opens the \(kind.title) list in System Settings.")
                    case .notGranted:
                        Button("Allow") { permissionsManager.request(kind) }
                            .buttonStyle(SettingsPrimaryButtonStyle())
                        Button("Settings") { permissionsManager.openSettings(kind) }
                            .buttonStyle(SettingsSecondaryButtonStyle())
                            .help("Opens the \(kind.title) list in System Settings.")
                    case .needsRepair:
                        Button("Repair") { permissionsManager.repair(kind) }
                            .buttonStyle(SettingsPrimaryButtonStyle())
                            .help("Clears the old macOS entry for Keyli and asks again.")
                        Button("Settings") { permissionsManager.openSettings(kind) }
                            .buttonStyle(SettingsSecondaryButtonStyle())
                    }
                }
            }
        }
        .padding(12)
        .background(KeyliChrome.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(needsAttention ? Color.orange.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.title), \(status.label)")
    }

    private func hint(for kind: PermissionKind, status: PermissionStatus) -> String? {
        switch (kind, status) {
        case (_, .granted):
            return nil
        case (.accessibility, .needsRepair):
            return "macOS dropped Keyli’s access, usually after an update. Repair clears the old entry, then turn Keyli on again."
        case (.accessibility, .notGranted):
            return "Turn on Keyli in the Accessibility list. If it’s missing, drag Keyli in from Finder."
        case (.inputMonitoring, .needsRepair):
            return "Repair clears the old entry, then turn Keyli on again and relaunch."
        case (.inputMonitoring, .notGranted):
            return "After turning Keyli on in the list, relaunch Keyli."
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: PermissionStatus) -> some View {
        let color: Color = status == .granted ? .green : (status == .needsRepair ? .orange : .secondary)
        let symbol = status == .granted ? "checkmark.circle.fill" : (status == .needsRepair ? "exclamationmark.triangle.fill" : "circle.dashed")
        Label(status.label, systemImage: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}
