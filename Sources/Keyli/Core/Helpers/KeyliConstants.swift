import Foundation

public enum KeyliConstants {
    public static let appName = "Keyli"
    public static let bundleIdentifier = "io.coreify.keyli"
    public static let suiteName = "io.coreify.keyli"

    public static let author = "Toufiq Hasan Kiron"
    public static let tagline = "An on-screen keyboard that types without stealing focus."
    public static let githubRepository = "kiron0/keyli"
    public static let websiteURL = URL(string: "https://keyli.kiron.dev")!
    public static let authorURL = URL(string: "https://kiron.dev")!
    public static let repositoryURL = URL(string: "https://github.com/\(githubRepository)")!
    public static let issuesURL = URL(string: "https://github.com/\(githubRepository)/issues/new")!
    public static let buyMeACoffeeURL = URL(string: "https://buymeacoffee.com/_thk")!

    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public static var copyright: String {
        "Copyright © \(Calendar.current.component(.year, from: Date())) \(author)"
    }

    /// Magic marker integer placed in CGEvent user data field to identify synthetic events
    /// produced by Keyli and avoid re-entrant event loops in the physical monitor.
    /// 'KEYL' in hex = 0x4B45594C
    public static let syntheticEventUserData: Int64 = 0x4B45594C

    public static let noKeyCode: UInt16 = 0xFFFF

    public static let defaultFloatingWidth: CGFloat = 820
    public static let defaultFloatingHeight: CGFloat = 340
    public static let minFloatingWidth: CGFloat = 620
    public static let minFloatingHeight: CGFloat = 250

    public static let defaultMenuWidth: CGFloat = 720
    public static let defaultMenuHeight: CGFloat = 300

    public static let keyboardHorizontalPadding: CGFloat = 20
    public static let keyboardChromeHeight: CGFloat = 64

    public static func keyboardAspect(_ layout: KeyboardLayout) -> CGFloat {
        CGFloat(layout.unitWidth / max(1, layout.unitHeight))
    }

    public static func panelHeight(forWidth width: CGFloat, layout: KeyboardLayout) -> CGFloat {
        (keyboardChromeHeight + (width - keyboardHorizontalPadding) / keyboardAspect(layout)).rounded()
    }

    public static func panelWidth(forHeight height: CGFloat, layout: KeyboardLayout) -> CGFloat {
        (keyboardHorizontalPadding + (height - keyboardChromeHeight) * keyboardAspect(layout)).rounded()
    }

    public enum NotificationName {
        public static let themeDidChange = Notification.Name("io.coreify.keyli.themeDidChange")
        public static let layoutDidChange = Notification.Name("io.coreify.keyli.layoutDidChange")
        public static let toggleFloatingKeyboard = Notification.Name("io.coreify.keyli.toggleFloatingKeyboard")
        public static let openSettings = Notification.Name("io.coreify.keyli.openSettings")
        public static let openThemeStudio = Notification.Name("io.coreify.keyli.openThemeStudio")
    }
}
