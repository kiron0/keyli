import AppKit
import SwiftUI
import Combine

public final class StatusItemController: NSObject {
    public static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var updateObservers = Set<AnyCancellable>()
    private var showsUpdateBadge = false
    private var iconCache: [String: NSImage] = [:]
    private var iconCacheSources: [InputSourceOption] = []

    private override init() {
        super.init()
    }

    public func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
        InputSourceService.shared.$currentId
            .combineLatest(InputSourceService.shared.$sources)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateIcon(isKeyboardVisible: PanelManager.shared.isFloatingVisible)
            }
            .store(in: &updateObservers)
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
        let service = InputSourceService.shared
        let current = service.sources.first { $0.id == service.currentId }
        if let current {
            if iconCacheSources != service.sources {
                iconCacheSources = service.sources
                iconCache.removeAll()
            }
            let image = iconCache[current.id] ?? service.icon(for: current.id) ?? Self.letterBadge(current.name)
            iconCache[current.id] = image
            button.image = image
        } else {
            let image = NSImage(systemSymbolName: isKeyboardVisible ? "keyboard.fill" : "keyboard", accessibilityDescription: "Keyli")
            image?.isTemplate = true
            button.image = image
        }
        guard !showsUpdateBadge else { return }
        let sourceName = current?.name ?? KeyliConstants.appName
        button.toolTip = sourceName
        button.setAccessibilityLabel("\(sourceName), \(KeyliConstants.appName) input menu")
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isQuickToggle = event?.type == .leftMouseUp && event?.modifierFlags.contains(.option) == true

        if isQuickToggle {
            PanelManager.shared.toggleFloatingKeyboard()
        } else {
            showContextMenu(sender)
        }
    }

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    private static func letterBadge(_ name: String) -> NSImage {
        InputSourceService.labelBadge(String(name.prefix(1)).uppercased())
    }

    private func addInputSourceItems(to menu: NSMenu) {
        let service = InputSourceService.shared
        service.refresh()
        guard !service.sources.isEmpty else { return }
        for source in service.sources {
            let item = NSMenuItem(title: source.name, action: #selector(selectInputSource(_:)), keyEquivalent: "")
            item.representedObject = source.id
            item.state = source.id == service.currentId ? .on : .off
            if iconCacheSources != service.sources {
                iconCacheSources = service.sources
                iconCache.removeAll()
            }
            let image = iconCache[source.id] ?? service.icon(for: source.id) ?? Self.letterBadge(source.name)
            iconCache[source.id] = image
            item.image = image
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
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

        addInputSourceItems(to: menu)

        let emojiItem = NSMenuItem(title: "Emoji & Symbols", action: #selector(showEmojiAndSymbols), keyEquivalent: "")
        emojiItem.image = Self.symbol("face.smiling")
        Self.applyShortcut(.showEmojiAndSymbols, to: emojiItem)
        menu.addItem(emojiItem)

        let isVisible = PanelManager.shared.isFloatingVisible
        let keyboardItem = NSMenuItem(title: isVisible ? "Hide Keyboard" : "Show Keyboard", action: #selector(toggleFloating), keyEquivalent: "")
        keyboardItem.image = Self.symbol(isVisible ? "keyboard.fill" : "keyboard")
        keyboardItem.toolTip = "Tip: ⌥-click the menu bar icon to toggle the keyboard directly."
        Self.applyShortcut(.toggleKeyboard, to: keyboardItem)
        menu.addItem(keyboardItem)
        menu.addItem(NSMenuItem.separator())

        let shortcutItems = Self.shortcutMenuItems(excluding: Self.actionsShownElsewhere)
        if !shortcutItems.isEmpty {
            let header = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            shortcutItems.forEach(menu.addItem)
            menu.addItem(NSMenuItem.separator())
        }

        let studioItem = NSMenuItem(title: "Theme Studio…", action: #selector(openThemeStudio), keyEquivalent: "")
        studioItem.image = Self.symbol("paintpalette")
        Self.applyShortcut(.openThemeStudio, to: studioItem)
        menu.addItem(studioItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.image = Self.symbol("gearshape")
        Self.applyShortcut(.openSettings, to: settingsItem)
        menu.addItem(settingsItem)
        let setupPending = !PermissionsManager.shared.canType || !SetupAssistantModel.isCompleted()
        let setupItem = NSMenuItem(title: setupPending ? "Finish Setup…" : "Setup Assistant…", action: #selector(openSetup), keyEquivalent: "")
        setupItem.image = Self.symbol(setupPending ? "exclamationmark.circle" : "checklist")
        Self.applyShortcut(.openSetupAssistant, to: setupItem)
        menu.addItem(setupItem)
        let updatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "u")
        updatesItem.image = Self.symbol("arrow.triangle.2.circlepath")
        Self.applyShortcut(.checkForUpdates, to: updatesItem)
        menu.addItem(updatesItem)
        menu.addItem(NSMenuItem.separator())

        let systemItem = NSMenuItem(title: "Open Keyboard Settings…", action: #selector(openKeyboardSettings), keyEquivalent: "")
        systemItem.image = Self.symbol("switch.2")
        Self.applyShortcut(.openKeyboardSettings, to: systemItem)
        menu.addItem(systemItem)
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.image = Self.symbol("power")
        menu.addItem(quitItem)

        for item in menu.items where item.target == nil {
            item.target = self
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    static let actionsShownElsewhere: Set<ShortcutAction> = [
        .showEmojiAndSymbols, .toggleKeyboard, .openThemeStudio, .openSettings,
        .openSetupAssistant, .checkForUpdates, .openKeyboardSettings
    ]

    static func applyShortcut(_ action: ShortcutAction, to item: NSMenuItem, manager: ShortcutManager = .shared) {
        guard let equivalent = manager.menuKeyEquivalent(for: action) else { return }
        item.keyEquivalent = equivalent.key
        item.keyEquivalentModifierMask = equivalent.modifiers
    }

    static func shortcutMenuItems(
        excluding hidden: Set<ShortcutAction>,
        manager: ShortcutManager = .shared,
        config: KeyliConfig = ConfigStore.shared.config
    ) -> [NSMenuItem] {
        manager.actionsWithShortcuts
            .filter { !hidden.contains($0) }
            .map { action in
                let item = NSMenuItem(title: action.title, action: #selector(performShortcutAction(_:)), keyEquivalent: "")
                item.representedObject = action.rawValue
                item.image = symbol(action.symbol)
                item.toolTip = action.detail
                if let isOn = action.isOn(config) {
                    item.state = isOn ? .on : .off
                }
                applyShortcut(action, to: item, manager: manager)
                return item
            }
    }

    @objc private func performShortcutAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = ShortcutAction(rawValue: raw) else { return }
        ShortcutManager.shared.perform(action)
    }

    @objc private func selectInputSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        InputSourceService.shared.select(id: id)
    }

    @objc private func showEmojiAndSymbols() {
        InputSourceService.shared.showEmojiAndSymbols()
    }

    @objc private func openKeyboardSettings() {
        InputSourceService.shared.openInputSourceSettings()
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
