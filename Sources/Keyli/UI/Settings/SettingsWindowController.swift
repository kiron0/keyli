import AppKit
import SwiftUI

public enum WindowActivationCoordinator {
    public static func update() {
        guard let application = NSApp else { return }
        let hasOpenWindow = SettingsWindowController.shared.isOpen || ThemeStudioWindowController.shared.isOpen
        let policy: NSApplication.ActivationPolicy = hasOpenWindow ? .regular : .accessory
        guard application.activationPolicy() != policy else { return }
        application.setActivationPolicy(policy)
    }
}

public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    public let navigation = SettingsNavigationModel()
    private var window: NSWindow?

    public var isOpen: Bool { window != nil }

    private override init() {
        super.init()
    }

    public func showSettings(tab: SettingsTab? = nil) {
        if let tab = tab {
            navigation.select(tab)
        }

        if let window = window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsRootView(navigation: navigation))
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = "Keyli Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(SettingsTab.windowSize)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.fullScreenNone]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.tabbingMode = .disallowed
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.delegate = self
        window.center()

        self.window = window
        WindowActivationCoordinator.update()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
        DispatchQueue.main.async {
            WindowActivationCoordinator.update()
        }
    }
}

public final class ThemeStudioWindowController: NSObject, NSWindowDelegate {
    public static let shared = ThemeStudioWindowController()

    private var window: NSWindow?

    public var isOpen: Bool { window != nil }

    private override init() {
        super.init()
    }

    public func showThemeStudio() {
        if let window = window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let host = NSHostingController(rootView: ThemeStudioView())
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.title = "Keyli Theme Studio"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(ThemeStudioLayout.windowSize)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.fullScreenNone]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.tabbingMode = .disallowed
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.delegate = self
        window.center()

        self.window = window
        WindowActivationCoordinator.update()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
        DispatchQueue.main.async {
            WindowActivationCoordinator.update()
        }
    }
}
