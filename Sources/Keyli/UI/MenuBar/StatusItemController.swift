import AppKit
import SwiftUI

public final class StatusItemController: NSObject {
    public static let shared = StatusItemController()

    private var statusItem: NSStatusItem?

    private override init() {
        super.init()
    }

    public func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "io.coreify.keyli.statusItem"
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyli")
            button.image?.isTemplate = true
            button.toolTip = "Keyli"
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.statusItem = item
        applyVisibility(ConfigStore.shared.config.showMenuBarIcon)
    }

    public func applyVisibility(_ isVisible: Bool) {
        statusItem?.isVisible = isVisible
        if !isVisible {
            PanelManager.shared.hideQuickPanel()
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondaryClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)

        if isSecondaryClick {
            PanelManager.shared.hideQuickPanel()
            showContextMenu(sender)
        } else {
            PanelManager.shared.toggleQuickPanel(relativeTo: sender)
        }
    }

    public func closePopover() {
        PanelManager.shared.hideQuickPanel()
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let floatingTitle = PanelManager.shared.isFloatingVisible ? "Hide Floating Keyboard" : "Show Floating Keyboard"
        menu.addItem(NSMenuItem(title: floatingTitle, action: #selector(toggleFloating), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Theme Studio…", action: #selector(openThemeStudio), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Keyli", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func toggleFloating() {
        PanelManager.shared.toggleFloatingKeyboard()
    }

    @objc private func openThemeStudio() {
        NotificationCenter.default.post(name: KeyliConstants.NotificationName.openThemeStudio, object: nil)
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: KeyliConstants.NotificationName.openSettings, object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
