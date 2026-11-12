import Foundation
import ApplicationServices
import AppKit

public enum PermissionKind: String, CaseIterable, Identifiable {
    case accessibility
    case inputMonitoring

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        }
    }

    public var symbol: String {
        switch self {
        case .accessibility: return "accessibility"
        case .inputMonitoring: return "keyboard"
        }
    }

    public var purpose: String {
        switch self {
        case .accessibility: return "Lets Keyli type into the app you’re using when you click a key."
        case .inputMonitoring: return "Lets Keyli light up keys you press on the physical keyboard. Nothing is recorded."
        }
    }

    public var usedBy: String {
        switch self {
        case .accessibility: return "Typing from the on-screen keyboard"
        case .inputMonitoring: return "Highlight physical keys"
        }
    }

    public var isRequired: Bool {
        self == .accessibility
    }

    public var tccService: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "ListenEvent"
        }
    }

    public var settingsURL: URL? {
        switch self {
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .inputMonitoring:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
    }
}

public enum PermissionStatus: Equatable {
    case granted
    case notGranted
    case needsRepair

    public var label: String {
        switch self {
        case .granted: return "Allowed"
        case .notGranted: return "Not Allowed"
        case .needsRepair: return "Needs Repair"
        }
    }

    public static func resolve(isGranted: Bool, wasGrantedBefore: Bool) -> PermissionStatus {
        if isGranted { return .granted }
        return wasGrantedBefore ? .needsRepair : .notGranted
    }
}

public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()

    @Published public private(set) var hasAccessibilityPermission: Bool = false
    @Published public private(set) var hasInputMonitoringPermission: Bool = false
    @Published public private(set) var hasPostEventPermission: Bool = false
    @Published public private(set) var busy: Set<PermissionKind> = []

    private var pollTimer: Timer?
    private var pollDeadline: Date = .distantPast
    private let defaults = UserDefaults.standard

    private init() {
        checkPermissions()
    }

    public static var canTypeNow: Bool {
        AXIsProcessTrusted() || CGPreflightPostEventAccess()
    }

    public var canType: Bool {
        hasAccessibilityPermission || hasPostEventPermission
    }

    public func isGranted(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .accessibility: return canType
        case .inputMonitoring: return hasInputMonitoringPermission
        }
    }

    public func status(of kind: PermissionKind) -> PermissionStatus {
        PermissionStatus.resolve(isGranted: isGranted(kind), wasGrantedBefore: defaults.bool(forKey: grantedKey(kind)))
    }

    public var attentionCount: Int {
        var count = 0
        if !canType { count += 1 }
        if ConfigStore.shared.config.isPhysicalMonitoringEnabled && !hasInputMonitoringPermission { count += 1 }
        return count
    }

    public var grantedCount: Int {
        PermissionKind.allCases.filter { isGranted($0) }.count
    }

    private func grantedKey(_ kind: PermissionKind) -> String {
        "io.coreify.keyli.permission.\(kind.rawValue).wasGranted"
    }

    private func promptedKey(_ kind: PermissionKind) -> String {
        "io.coreify.keyli.permission.\(kind.rawValue).wasPrompted"
    }

    public func checkPermissions() {
        let accessibility = AXIsProcessTrusted()
        let postEvent = CGPreflightPostEventAccess()
        let monitor = PhysicalKeyboardMonitor.shared
        let listen = CGPreflightListenEventAccess() || monitor.isRunning

        if hasAccessibilityPermission != accessibility {
            hasAccessibilityPermission = accessibility
        }
        if hasPostEventPermission != postEvent {
            hasPostEventPermission = postEvent
        }
        if canType {
            if !defaults.bool(forKey: grantedKey(.accessibility)) {
                defaults.set(true, forKey: grantedKey(.accessibility))
            }
            if KeyboardState.shared.dispatchIssue == .missingPermission {
                KeyboardState.shared.dispatchIssue = nil
            }
        }
        if hasInputMonitoringPermission != listen {
            hasInputMonitoringPermission = listen
        }
        if listen && !defaults.bool(forKey: grantedKey(.inputMonitoring)) {
            defaults.set(true, forKey: grantedKey(.inputMonitoring))
        }
        if ConfigStore.shared.config.isPhysicalMonitoringEnabled && monitor.hasVisibleKeyboard && !monitor.isRunning {
            if listen || defaults.bool(forKey: promptedKey(.inputMonitoring)) {
                monitor.refresh()
                if monitor.isRunning && !hasInputMonitoringPermission {
                    hasInputMonitoringPermission = true
                }
            }
        }
    }

    public func request(_ kind: PermissionKind) {
        let alreadyPrompted = defaults.bool(forKey: promptedKey(kind))
        defaults.set(true, forKey: promptedKey(kind))

        switch kind {
        case .accessibility:
            if alreadyPrompted {
                openSettings(kind)
            } else {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
        case .inputMonitoring:
            if alreadyPrompted {
                openSettings(kind)
            } else if !CGRequestListenEventAccess() {
                PhysicalKeyboardMonitor.shared.refresh()
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

    public func openSettings(_ kind: PermissionKind) {
        if let url = kind.settingsURL {
            NSWorkspace.shared.open(url)
        }
        startPollingForPermissions()
    }

    public func openAccessibilityPreferences() {
        openSettings(.accessibility)
    }

    public func openInputMonitoringPreferences() {
        openSettings(.inputMonitoring)
    }

    public func repair(_ kind: PermissionKind) {
        guard !busy.contains(kind) else { return }
        busy.insert(kind)
        let bundleId = Bundle.main.bundleIdentifier ?? KeyliConstants.bundleIdentifier
        let services = kind == .accessibility ? [kind.tccService, "PostEvent"] : [kind.tccService]

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
                self.defaults.set(false, forKey: self.promptedKey(kind))
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

    private var isEverythingNeededGranted: Bool {
        let monitoringSatisfied = hasInputMonitoringPermission || !ConfigStore.shared.config.isPhysicalMonitoringEnabled
        return canType && monitoringSatisfied
    }

    public func startPollingForPermissions() {
        pollDeadline = Date().addingTimeInterval(300)
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.checkPermissions()
            if self.isEverythingNeededGranted || Date() > self.pollDeadline {
                timer.invalidate()
                self.pollTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
