import Foundation
import ApplicationServices
import AppKit
import IOKit.hid
import ServiceManagement

public enum PermissionKind: String, CaseIterable, Identifiable {
    case accessibility
    case inputMonitoring
    case loginItem

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .loginItem: return "Open at Login"
        }
    }

    public var symbol: String {
        switch self {
        case .accessibility: return "accessibility"
        case .inputMonitoring: return "keyboard"
        case .loginItem: return "power"
        }
    }

    public var purpose: String {
        switch self {
        case .accessibility:
            return "Lets Keyli type into the app you’re using and send brightness, volume and media keys."
        case .inputMonitoring:
            return "Lets Keyli light up keys you press on the physical keyboard. Nothing is recorded."
        case .loginItem:
            return "Starts Keyli when you log in so the keyboard is ready in the menu bar."
        }
    }

    public var usedBy: String {
        switch self {
        case .accessibility: return "Typing, shortcuts, function, media keys, and locking the physical keyboard"
        case .inputMonitoring: return "Highlight physical keys"
        case .loginItem: return "Launch Keyli at login"
        }
    }

    public var isRequired: Bool {
        self == .accessibility
    }

    public var tccServices: [String] {
        switch self {
        case .accessibility: return ["Accessibility", "PostEvent"]
        case .inputMonitoring: return ["ListenEvent"]
        case .loginItem: return []
        }
    }

    public var settingsURL: URL? {
        switch self {
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .inputMonitoring:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        case .loginItem:
            return URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        }
    }
}

public enum PermissionStatus: Equatable {
    case granted
    case notGranted
    case waiting
    case denied
    case needsRepair
    case needsRelaunch
    case requiresApproval
    case off

    public var label: String {
        switch self {
        case .granted: return "Allowed"
        case .notGranted: return "Not Allowed"
        case .waiting: return "Waiting…"
        case .denied: return "Denied"
        case .needsRepair: return "Needs Repair"
        case .needsRelaunch: return "Relaunch Needed"
        case .requiresApproval: return "Needs Approval"
        case .off: return "Off"
        }
    }

    public var isGranted: Bool {
        self == .granted
    }

    public static func resolve(isGranted: Bool, wasGrantedBefore: Bool) -> PermissionStatus {
        if isGranted { return .granted }
        return wasGrantedBefore ? .needsRepair : .notGranted
    }

    public static func accessibility(trusted: Bool, wasGrantedBefore: Bool, isWaiting: Bool) -> PermissionStatus {
        if trusted { return .granted }
        if wasGrantedBefore { return .needsRepair }
        return isWaiting ? .waiting : .notGranted
    }

    public static func inputMonitoring(
        access: IOHIDAccessType,
        tapNeeded: Bool,
        tapRunning: Bool,
        wasGrantedBefore: Bool,
        isWaiting: Bool
    ) -> PermissionStatus {
        if access == kIOHIDAccessTypeGranted {
            return (tapNeeded && !tapRunning) ? .needsRelaunch : .granted
        }
        if access == kIOHIDAccessTypeDenied {
            return wasGrantedBefore ? .needsRepair : .denied
        }
        return isWaiting ? .waiting : .notGranted
    }

    public static func loginItem(_ status: SMAppService.Status, wanted: Bool) -> PermissionStatus {
        switch status {
        case .enabled: return .granted
        case .requiresApproval: return .requiresApproval
        default: return wanted ? .notGranted : .off
        }
    }
}

public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()

    @Published public private(set) var statuses: [PermissionKind: PermissionStatus] = [:]
    @Published public private(set) var busy: Set<PermissionKind> = []

    private var waiting: Set<PermissionKind> = []
    private var pollTimer: Timer?
    private var pollDeadline: Date = .distantPast
    private var activationObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard

    private init() {
        checkPermissions()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    public static var canTypeNow: Bool {
        AXIsProcessTrusted() || CGPreflightPostEventAccess()
    }

    public static var inputMonitoringAccess: IOHIDAccessType {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    }

    public func status(of kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? .notGranted
    }

    public var canType: Bool {
        status(of: .accessibility) == .granted
    }

    public var hasInputMonitoringPermission: Bool {
        PermissionsManager.inputMonitoringAccess == kIOHIDAccessTypeGranted
    }

    public func needsAttention(_ kind: PermissionKind) -> Bool {
        let status = status(of: kind)
        switch kind {
        case .accessibility:
            return status != .granted
        case .inputMonitoring:
            return PhysicalKeyboardMonitor.shared.needsEventTap && status != .granted
        case .loginItem:
            return status == .requiresApproval || (ConfigStore.shared.config.launchAtLogin && status != .granted)
        }
    }

    public var attentionCount: Int {
        PermissionKind.allCases.filter { needsAttention($0) }.count
    }

    public var grantedCount: Int {
        PermissionKind.allCases.filter { status(of: $0) == .granted }.count
    }

    private func grantedKey(_ kind: PermissionKind) -> String {
        "io.coreify.keyli.permission.\(kind.rawValue).wasGranted"
    }

    public func checkPermissions() {
        let monitor = PhysicalKeyboardMonitor.shared
        let config = ConfigStore.shared.config

        let trusted = PermissionsManager.canTypeNow
        if trusted {
            waiting.remove(.accessibility)
            defaults.set(true, forKey: grantedKey(.accessibility))
            if KeyboardState.shared.dispatchIssue == .missingPermission {
                KeyboardState.shared.dispatchIssue = nil
            }
        } else if PhysicalKeyboardLockService.shared.isLocked {
            PhysicalKeyboardLockService.shared.unlock()
        }
        let accessibilityStatus = PermissionStatus.accessibility(
            trusted: trusted,
            wasGrantedBefore: defaults.bool(forKey: grantedKey(.accessibility)),
            isWaiting: waiting.contains(.accessibility)
        )

        let access = PermissionsManager.inputMonitoringAccess
        let tapNeeded = monitor.needsEventTap
        if access == kIOHIDAccessTypeGranted {
            waiting.remove(.inputMonitoring)
            defaults.set(true, forKey: grantedKey(.inputMonitoring))
            if tapNeeded && !monitor.isRunning {
                monitor.refresh()
            }
        }
        let inputStatus = PermissionStatus.inputMonitoring(
            access: access,
            tapNeeded: tapNeeded,
            tapRunning: monitor.isRunning,
            wasGrantedBefore: defaults.bool(forKey: grantedKey(.inputMonitoring)),
            isWaiting: waiting.contains(.inputMonitoring)
        )

        let loginStatus: PermissionStatus
        if Bundle.main.bundleURL.pathExtension == "app" {
            loginStatus = PermissionStatus.loginItem(SMAppService.mainApp.status, wanted: config.launchAtLogin)
        } else {
            loginStatus = .off
        }
        if loginStatus == .granted {
            waiting.remove(.loginItem)
        }

        let updated: [PermissionKind: PermissionStatus] = [
            .accessibility: accessibilityStatus,
            .inputMonitoring: inputStatus,
            .loginItem: loginStatus
        ]
        if statuses != updated {
            statuses = updated
        }
    }

    public func request(_ kind: PermissionKind) {
        waiting.insert(kind)
        switch kind {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            if !AXIsProcessTrustedWithOptions(options) {
                _ = CGRequestPostEventAccess()
            }
        case .inputMonitoring:
            switch PermissionsManager.inputMonitoringAccess {
            case kIOHIDAccessTypeDenied:
                openSettings(kind)
            default:
                if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) {
                    openSettings(kind)
                }
            }
        case .loginItem:
            ConfigStore.shared.config.launchAtLogin = true
            LaunchAtLoginService.shared.setEnabled(true)
            if SMAppService.mainApp.status == .requiresApproval {
                openSettings(kind)
            }
        }
        checkPermissions()
        startPollingForPermissions()
    }

    public func requestAccessibility() {
        request(.accessibility)
    }

    public func requestInputMonitoring() {
        request(.inputMonitoring)
    }

    public func turnOffLoginItem() {
        ConfigStore.shared.config.launchAtLogin = false
        LaunchAtLoginService.shared.setEnabled(false)
        checkPermissions()
    }

    public func openSettings(_ kind: PermissionKind) {
        if kind == .loginItem {
            SMAppService.openSystemSettingsLoginItems()
        } else if let url = kind.settingsURL {
            NSWorkspace.shared.open(url)
        }
        waiting.insert(kind)
        checkPermissions()
        startPollingForPermissions()
    }

    public func openAccessibilityPreferences() {
        openSettings(.accessibility)
    }

    public func openInputMonitoringPreferences() {
        openSettings(.inputMonitoring)
    }

    public func repair(_ kind: PermissionKind) {
        let services = kind.tccServices
        guard !services.isEmpty, !busy.contains(kind) else {
            openSettings(kind)
            return
        }
        busy.insert(kind)
        let bundleId = Bundle.main.bundleIdentifier ?? KeyliConstants.bundleIdentifier

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for service in services {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
                process.arguments = ["reset", service, bundleId]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
                process.waitUntilExit()
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.defaults.set(false, forKey: self.grantedKey(kind))
                self.busy.remove(kind)
                self.request(kind)
            }
        }
    }

    public func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    public func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return }
        ThemeManager.shared.flushPendingWrites()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 0.6; /usr/bin/open \"$0\"", bundleURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    public func startPollingForPermissions() {
        pollDeadline = Date().addingTimeInterval(300)
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.checkPermissions()
            let needed = PermissionKind.allCases.filter { self.needsAttention($0) || self.waiting.contains($0) }
            if needed.isEmpty || Date() > self.pollDeadline {
                self.waiting.removeAll()
                self.checkPermissions()
                timer.invalidate()
                self.pollTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
