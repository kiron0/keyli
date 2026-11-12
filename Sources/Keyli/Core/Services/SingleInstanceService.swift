import Foundation
import AppKit

public final class SingleInstanceService {
    public static let shared = SingleInstanceService()

    private init() {}

    public func ensureSingleInstance() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? KeyliConstants.bundleIdentifier)
        let currentPID = ProcessInfo.processInfo.processIdentifier

        for app in runningApps where app.processIdentifier != currentPID {
            // Another instance is already running
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            return false
        }
        return true
    }
}
