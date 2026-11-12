import Foundation
import AppKit

public final class FocusManager: ObservableObject {
    public static let shared = FocusManager()

    @Published public private(set) var targetApplication: NSRunningApplication?
    @Published public private(set) var targetAppName: String = "No App"
    @Published public private(set) var targetAppIcon: NSImage?
    @Published public private(set) var targetPID: pid_t = 0

    private var observer: NSObjectProtocol?

    private init() {
        startObserving()
        resolveCurrentFrontmostApp()
    }

    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    public func startObserving() {
        guard observer == nil else { return }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            self.handleApplicationActivation(app)
        }
    }

    public func resolveCurrentFrontmostApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            handleApplicationActivation(frontApp)
        }
    }

    private func handleApplicationActivation(_ app: NSRunningApplication) {
        // Never treat Keyli itself as the typing target
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier
            || app.bundleIdentifier == Bundle.main.bundleIdentifier
            || app.bundleIdentifier == KeyliConstants.bundleIdentifier {
            return
        }

        PhysicalKeyboardMonitor.shared.clearPressedKeys()
        if KeyboardState.shared.dispatchIssue == .noTarget || KeyboardState.shared.dispatchIssue == .secureInput {
            KeyboardState.shared.dispatchIssue = nil
        }

        self.targetApplication = app
        self.targetAppName = app.localizedName ?? "Active App"
        self.targetAppIcon = app.icon
        self.targetPID = app.processIdentifier

        // Update shared KeyboardState
        KeyboardState.shared.targetAppName = self.targetAppName
        KeyboardState.shared.targetAppBundleId = app.bundleIdentifier ?? ""
        KeyboardState.shared.targetAppIcon = self.targetAppIcon
    }

    /// Validates if target is still alive and running
    public var isTargetValid: Bool {
        guard let app = targetApplication else { return false }
        return !app.isTerminated
    }
}
