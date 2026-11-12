import Foundation

public enum KeyliConstants {
    public static let appName = "Keyli"
    public static let bundleIdentifier = "io.coreify.keyli"
    public static let suiteName = "io.coreify.keyli"

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
