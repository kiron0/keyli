import Foundation
import ApplicationServices
import AppKit

public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()

    @Published public private(set) var hasAccessibilityPermission: Bool = false
    @Published public private(set) var hasInputMonitoringPermission: Bool = false
    @Published public private(set) var hasPostEventPermission: Bool = false

    private var pollTimer: Timer?
    private var pollDeadline: Date = .distantPast

    private init() {
        checkPermissions()
    }

    public var canType: Bool {
        hasPostEventPermission
    }

    public func checkPermissions() {
        let accessibility = checkAccessibility()
        let postEvent = CGPreflightPostEventAccess()
        let listen = CGPreflightListenEventAccess()

        if hasAccessibilityPermission != accessibility {
            hasAccessibilityPermission = accessibility
        }
        if hasPostEventPermission != postEvent {
            hasPostEventPermission = postEvent
            if postEvent && KeyboardState.shared.dispatchIssue == .missingPermission {
                KeyboardState.shared.dispatchIssue = nil
            }
        }
        if hasInputMonitoringPermission != listen {
            hasInputMonitoringPermission = listen
            PhysicalKeyboardMonitor.shared.refresh()
        }
    }

    private func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func requestAccessibility() {
        _ = CGRequestPostEventAccess()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        checkPermissions()
        startPollingForPermissions()
    }

    public func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        checkPermissions()
        startPollingForPermissions()
    }

    public func requestAllRequiredPermissions() {
        checkPermissions()
        if !hasPostEventPermission {
            requestAccessibility()
        }
        if !hasInputMonitoringPermission && ConfigStore.shared.config.isPhysicalMonitoringEnabled {
            requestInputMonitoring()
        }
    }

    private var isEverythingNeededGranted: Bool {
        let monitoringSatisfied = hasInputMonitoringPermission || !ConfigStore.shared.config.isPhysicalMonitoringEnabled
        return hasPostEventPermission && monitoringSatisfied
    }

    public func startPollingForPermissions() {
        pollDeadline = Date().addingTimeInterval(300)
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
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
    }

    public func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPollingForPermissions()
    }

    public func openInputMonitoringPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        startPollingForPermissions()
    }
}
