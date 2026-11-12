import Foundation
import AppKit
import Combine

public final class KeyboardState: ObservableObject {
    public static let shared = KeyboardState()

    @Published public var isShiftActive: Bool = false
    @Published public var isOptionActive: Bool = false
    @Published public var isControlActive: Bool = false
    @Published public var isCommandActive: Bool = false
    @Published public var isCapsLockActive: Bool = false
    @Published public var isFnActive: Bool = false

    /// Keycodes currently physically pressed down (from PhysicalKeyboardMonitor)
    @Published public var pressedPhysicalKeyCodes: Set<UInt16> = []

    /// Virtual keycap ID currently depressed via mouse/pointer click
    @Published public var virtualPressedKeyId: String? = nil

    /// Target application information
    @Published public var targetAppName: String = "No Target Selected"
    @Published public var targetAppBundleId: String = ""
    @Published public var targetAppIcon: NSImage? = nil

    @Published public var dispatchIssue: KeyDispatchIssue? = nil

    /// Active layout and theme
    @Published public var currentLayout: KeyboardLayout
    @Published public var currentTheme: KeyboardTheme

    public init() {
        self.currentTheme = .appleNative
        self.currentLayout = KeyboardLayout(
            id: "ansi_default",
            name: "US ANSI",
            geometryType: .ansi,
            unitWidth: 15.0,
            unitHeight: 6.0,
            keys: []
        )
    }

    public func resetModifiers() {
        isShiftActive = false
        isOptionActive = false
        isControlActive = false
        isCommandActive = false
        isFnActive = false
    }

    public func toggleModifier(_ type: ModifierType) {
        switch type {
        case .shift:
            isShiftActive.toggle()
        case .option:
            isOptionActive.toggle()
        case .control:
            isControlActive.toggle()
        case .command:
            isCommandActive.toggle()
        case .capsLock:
            isCapsLockActive.toggle()
        case .fn:
            isFnActive.toggle()
        }
    }

    public func isKeyCurrentlyPressed(keyCode: UInt16, keyId: String) -> Bool {
        if virtualPressedKeyId == keyId {
            return true
        }
        return pressedPhysicalKeyCodes.contains(keyCode)
    }
}
