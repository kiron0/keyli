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
            permissionCard(.loginItem)

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
        }
    }

    @ViewBuilder
    private func permissionCard(_ kind: PermissionKind) -> some View {
        let status = permissionsManager.status(of: kind)
        let isBusy = permissionsManager.busy.contains(kind)
        let needsAttention = permissionsManager.needsAttention(kind)

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
                    actions(for: kind, status: status)
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

    @ViewBuilder
    private func actions(for kind: PermissionKind, status: PermissionStatus) -> some View {
        switch status {
        case .granted:
            if kind == .loginItem {
                Button("Turn Off") { permissionsManager.turnOffLoginItem() }
                    .buttonStyle(SettingsSecondaryButtonStyle())
            } else {
                Button("Manage") { permissionsManager.openSettings(kind) }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                    .help("Opens the \(kind.title) list in System Settings.")
            }
        case .notGranted, .off:
            Button(kind == .loginItem ? "Turn On" : "Allow") { permissionsManager.request(kind) }
                .buttonStyle(SettingsPrimaryButtonStyle())
            if kind != .loginItem {
                Button("Settings") { permissionsManager.openSettings(kind) }
                    .buttonStyle(SettingsSecondaryButtonStyle())
            }
        case .waiting:
            Button("Open System Settings") { permissionsManager.openSettings(kind) }
                .buttonStyle(SettingsPrimaryButtonStyle())
        case .denied, .requiresApproval:
            Button("Open System Settings") { permissionsManager.openSettings(kind) }
                .buttonStyle(SettingsPrimaryButtonStyle())
            if status == .denied {
                Button("Reset") { permissionsManager.repair(kind) }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                    .help("Clears the macOS decision for Keyli and asks again.")
            }
        case .needsRepair:
            Button("Repair") { permissionsManager.repair(kind) }
                .buttonStyle(SettingsPrimaryButtonStyle())
                .help("Clears the old macOS entry for Keyli and asks again.")
            Button("Settings") { permissionsManager.openSettings(kind) }
                .buttonStyle(SettingsSecondaryButtonStyle())
        case .needsRelaunch:
            Button("Relaunch Keyli") { permissionsManager.relaunch() }
                .buttonStyle(SettingsPrimaryButtonStyle())
        }
    }

    private func hint(for kind: PermissionKind, status: PermissionStatus) -> String? {
        switch (kind, status) {
        case (_, .granted), (_, .off):
            return nil
        case (_, .waiting):
            return "Turn on Keyli in System Settings. This page updates by itself when you do."
        case (_, .needsRelaunch):
            return "Access is on. macOS applies it to the keyboard monitor after Keyli restarts."
        case (_, .needsRepair):
            return "macOS dropped Keyli’s access, usually after an update. Repair clears the old entry, then turn Keyli on again."
        case (_, .denied):
            return "Turn on Keyli in System Settings, or Reset to be asked again."
        case (.loginItem, .requiresApproval):
            return "Turn on Keyli under Login Items & Extensions."
        case (.accessibility, _):
            return "Turn on Keyli in the Accessibility list. If it’s missing, drag Keyli in from Finder."
        case (.inputMonitoring, _):
            return "Needed only to highlight physical keys."
        case (.loginItem, _):
            return nil
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: PermissionStatus) -> some View {
        let color: Color = {
            switch status {
            case .granted: return .green
            case .denied: return .red
            case .needsRepair, .needsRelaunch, .requiresApproval: return .orange
            case .waiting: return .blue
            case .notGranted, .off: return .secondary
            }
        }()
        let symbol: String = {
            switch status {
            case .granted: return "checkmark.circle.fill"
            case .denied: return "xmark.circle.fill"
            case .needsRepair, .needsRelaunch, .requiresApproval: return "exclamationmark.triangle.fill"
            case .waiting: return "clock"
            case .notGranted: return "circle.dashed"
            case .off: return "minus.circle"
            }
        }()
        Label(status.label, systemImage: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}
