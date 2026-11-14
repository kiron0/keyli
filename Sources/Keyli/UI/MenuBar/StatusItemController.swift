import AppKit
import SwiftUI
import Combine

public final class StatusItemController: NSObject {
    public static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var updateObservers = Set<AnyCancellable>()
    private var showsUpdateBadge = false

    private override init() {
        super.init()
    }

    public func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "io.coreify.keyli.statusItem"
        if let button = item.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.statusItem = item
        updateIcon(isKeyboardVisible: PanelManager.shared.isFloatingVisible)
        PanelManager.shared.onVisibilityChange = { [weak self] isVisible in
            self?.updateIcon(isKeyboardVisible: isVisible)
        }
        applyVisibility(ConfigStore.shared.config.showMenuBarIcon)
        MainActor.assumeIsolated {
            observeUpdates()
        }
    }

    @MainActor
    private func observeUpdates() {
        UpdateChecker.shared.$availableUpdate
            .map { $0 != nil }
            .combineLatest(UpdateDownloadService.shared.$state.map { state -> Bool in
                if case .ready = state { return true }
                return false
            })
            .map { $0 || $1 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                self?.updateBadge(show: show)
            }
            .store(in: &updateObservers)
    }

    private func updateBadge(show: Bool) {
        showsUpdateBadge = show
        guard let button = statusItem?.button else { return }
        button.wantsLayer = true
        let name = "keyliUpdateDot"
        let existing = button.layer?.sublayers?.first { $0.name == name }
        guard show else {
            existing?.removeFromSuperlayer()
            updateIcon(isKeyboardVisible: PanelManager.shared.isFloatingVisible)
            return
        }
        let dot = existing ?? CALayer()
        dot.name = name
        dot.backgroundColor = NSColor.systemRed.cgColor
        dot.borderColor = NSColor.windowBackgroundColor.cgColor
        dot.borderWidth = 1
        let size: CGFloat = 7
        dot.frame = CGRect(x: button.bounds.maxX - size - 2, y: button.bounds.maxY - size - 3, width: size, height: size)
        dot.cornerRadius = size / 2
        if existing == nil { button.layer?.addSublayer(dot) }
        button.setAccessibilityLabel("\(KeyliConstants.appName), update available")
        button.toolTip = "\(KeyliConstants.appName) — update available"
    }

    static func updateMenuTitle(availableVersion: String?, state: UpdateState) -> String? {
        switch state {
        case .ready(_, let version):
            return "Restart to Update to v\(version)"
        case .downloading, .extracting:
            return availableVersion.map { "Downloading v\($0)…" }
        default:
            return availableVersion.map { "Update to v\($0)…" }
        }
    }

    static var redDot: NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    public func applyVisibility(_ isVisible: Bool) {
        statusItem?.isVisible = isVisible
    }

    private func updateIcon(isKeyboardVisible: Bool) {
        guard let button = statusItem?.button else { return }
        let symbol = isKeyboardVisible ? "keyboard.fill" : "keyboard"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Keyli")
        image?.isTemplate = true
        button.image = image
        guard !showsUpdateBadge else { return }
        button.toolTip = isKeyboardVisible ? "Hide Keyboard" : "Show Keyboard"
        button.setAccessibilityLabel(isKeyboardVisible ? "Hide Keyli keyboard" : "Show Keyli keyboard")
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondaryClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)

        if isSecondaryClick {
            showContextMenu(sender)
        } else {
            PanelManager.shared.toggleFloatingKeyboard()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let (updateTitle, isReady) = MainActor.assumeIsolated { () -> (String?, Bool) in
            let state = UpdateDownloadService.shared.state
            let title = Self.updateMenuTitle(availableVersion: UpdateChecker.shared.availableUpdate?.version, state: state)
            if case .ready = state { return (title, true) }
            return (title, false)
        }
        if let updateTitle {
            let updateItem = NSMenuItem(
                title: updateTitle,
                action: isReady ? #selector(restartToUpdate) : #selector(showAvailableUpdate),
                keyEquivalent: ""
            )
            updateItem.image = Self.redDot
            menu.addItem(updateItem)
            menu.addItem(NSMenuItem.separator())
        }

        let floatingTitle = PanelManager.shared.isFloatingVisible ? "Hide Keyboard" : "Show Keyboard"
        menu.addItem(NSMenuItem(title: floatingTitle, action: #selector(toggleFloating), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Theme Studio…", action: #selector(openThemeStudio), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        let setupPending = !PermissionsManager.shared.canType || !SetupAssistantModel.isCompleted()
        menu.addItem(NSMenuItem(title: setupPending ? "Finish Setup…" : "Setup Assistant…", action: #selector(openSetup), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "u"))
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

    @objc private func openSetup() {
        SetupAssistantController.shared.show(from: PermissionsManager.shared.canType ? .welcome : .accessibility)
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: KeyliConstants.NotificationName.openSettings, object: nil)
    }

    @objc private func showAvailableUpdate() {
        MainActor.assumeIsolated {
            UpdateChecker.shared.presentAvailableUpdate()
        }
    }

    @objc private func restartToUpdate() {
        MainActor.assumeIsolated {
            UpdateChecker.shared.restartToUpdate()
        }
    }

    @objc private func checkForUpdates() {
        Task { @MainActor in
            await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
