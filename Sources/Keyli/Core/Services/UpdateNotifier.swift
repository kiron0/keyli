import Foundation
import UserNotifications

@MainActor
enum UpdateNotifier {
    static let identifierPrefix = "keyli-update-"
    private static let notifiedVersionKey = "keyli_update_notified_version"

    static func notifyAvailable(version: String) {
        post(
            version: version,
            kind: "available",
            title: "Keyli \(version) is available",
            body: "Click the Keyli menu bar icon menu and choose Update to install it."
        )
    }

    static func notifyReady(version: String) {
        post(
            version: version,
            kind: "ready",
            title: "Keyli \(version) is ready",
            body: "Choose Restart to Update in the Keyli menu bar menu to finish installing."
        )
    }

    static func shouldNotify(version: String, kind: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: notifiedVersionKey) != "\(kind):\(version)"
    }

    static var canPost: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func installDelegate() {
        guard canPost else { return }
        UNUserNotificationCenter.current().delegate = UpdateNotificationDelegate.shared
    }

    private static func post(version: String, kind: String, title: String, body: String) {
        guard canPost, shouldNotify(version: version, kind: kind) else { return }
        UserDefaults.standard.set("\(kind):\(version)", forKey: notifiedVersionKey)
        Task {
            let center = UNUserNotificationCenter.current()
            var status = (await center.notificationSettings()).authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                status = (await center.notificationSettings()).authorizationStatus
            }
            guard status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(kind)-\(version)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}

final class UpdateNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UpdateNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            if identifier.hasPrefix(UpdateNotifier.identifierPrefix) {
                UpdateChecker.shared.presentAvailableUpdate()
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
