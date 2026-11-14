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
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier
            || app.bundleIdentifier == Bundle.main.bundleIdentifier
            || app.bundleIdentifier == KeyliConstants.bundleIdentifier {
            return
        }

        PhysicalKeyboardMonitor.shared.clearPressedKeys()
        if KeyboardState.shared.dispatchIssue == .noTarget || KeyboardState.shared.dispatchIssue == .secureInput {
            KeyboardState.shared.dispatchIssue = nil
        }

        let name = app.localizedName ?? "Active App"
        let bundleId = app.bundleIdentifier ?? ""
        let isSameApp = targetPID == app.processIdentifier && targetApplication != nil
        targetApplication = app
        if targetAppName != name { targetAppName = name }
        if targetPID != app.processIdentifier { targetPID = app.processIdentifier }
        if !isSameApp { targetAppIcon = app.icon }

        let state = KeyboardState.shared
        if state.targetAppName != name { state.targetAppName = name }
        if state.targetAppBundleId != bundleId { state.targetAppBundleId = bundleId }
        if !isSameApp { state.targetAppIcon = targetAppIcon }
    }

    public var isTargetValid: Bool {
        guard let app = targetApplication else { return false }
        return !app.isTerminated
    }
}
