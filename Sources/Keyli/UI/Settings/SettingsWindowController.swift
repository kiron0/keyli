import AppKit
import SwiftUI

public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()

    private let tabController = NSTabViewController()
    private var hasBeenShown = false

    private init() {
        tabController.tabStyle = .toolbar

        for tab in SettingsTab.allCases {
            let host = NSHostingController(rootView: tab.makeView())
            host.title = tab.rawValue
            host.sizingOptions = [.preferredContentSize]
            host.preferredContentSize = NSSize(width: SettingsView.contentWidth, height: tab.contentHeight)

            let item = NSTabViewItem(viewController: host)
            item.label = tab.rawValue
            item.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.rawValue)
            tabController.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabController)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.title = SettingsTab.general.rawValue
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showSettings(tab: SettingsTab? = nil) {
        if let tab = tab, let index = SettingsTab.allCases.firstIndex(of: tab) {
            tabController.selectedTabViewItemIndex = index
        }
        NSApp.activate()
        if !hasBeenShown {
            window?.center()
            hasBeenShown = true
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

public final class ThemeStudioWindowController: NSWindowController {
    public static let shared = ThemeStudioWindowController()

    private var hasBeenShown = false

    private init() {
        let host = NSHostingController(rootView: ThemeStudioView())
        host.sceneBridgingOptions = [.toolbars, .title]

        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.title = "Theme Studio"
        window.setContentSize(NSSize(width: 1040, height: 620))
        window.minSize = NSSize(width: 920, height: 540)
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showThemeStudio() {
        NSApp.activate()
        if !hasBeenShown {
            window?.center()
            hasBeenShown = true
        }
        window?.makeKeyAndOrderFront(nil)
    }
}
