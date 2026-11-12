import AppKit
import SwiftUI

public final class PanelManager: NSObject, NSWindowDelegate {
    public static let shared = PanelManager()

    private var floatingPanel: NonActivatingPanel?
    private var quickPanel: NonActivatingPanel?
    private var outsideClickMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    public private(set) var isFloatingVisible: Bool = false
    public private(set) var isQuickVisible: Bool = false

    private override init() {
        super.init()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.keepFloatingPanelOnScreen()
        }
    }

    public func getOrCreateFloatingPanel() -> NonActivatingPanel {
        if let panel = floatingPanel {
            return panel
        }

        let savedRect: NSRect
        let config = ConfigStore.shared.config
        if let x = config.floatingWindowX, let y = config.floatingWindowY,
           let w = config.floatingWindowWidth, let h = config.floatingWindowHeight {
            savedRect = WindowPositioner.clampToVisibleScreen(frame: NSRect(x: x, y: y, width: w, height: h))
        } else {
            savedRect = WindowPositioner.defaultFloatingRect()
        }

        let panel = NonActivatingPanel(contentRect: savedRect)
        panel.delegate = self
        let layout = KeyboardState.shared.currentLayout
        panel.minSize = NSSize(
            width: KeyliConstants.minFloatingWidth,
            height: KeyliConstants.panelHeight(forWidth: KeyliConstants.minFloatingWidth, layout: layout)
        )

        let container = FloatingKeyboardContainerView { [weak self] in
            self?.hideFloatingKeyboard()
        }
        let hostingView = NSHostingView(rootView: container)
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.setFrame(savedRect, display: false)

        self.floatingPanel = panel
        fitPanelsToLayout()
        return panel
    }

    public func showFloatingKeyboard() {
        let panel = getOrCreateFloatingPanel()
        applyWindowConfig()
        panel.orderFrontRegardless()
        isFloatingVisible = true
        if !ConfigStore.shared.config.isFloatingVisible {
            ConfigStore.shared.config.isFloatingVisible = true
        }
        updateMonitorVisibility()
    }

    public func hideFloatingKeyboard() {
        floatingPanel?.orderOut(nil)
        isFloatingVisible = false
        if ConfigStore.shared.config.isFloatingVisible {
            ConfigStore.shared.config.isFloatingVisible = false
        }
        updateMonitorVisibility()
    }

    public func toggleFloatingKeyboard() {
        if isFloatingVisible {
            hideFloatingKeyboard()
        } else {
            showFloatingKeyboard()
        }
    }

    public func applyWindowConfig() {
        guard let panel = floatingPanel else { return }
        let config = ConfigStore.shared.config
        panel.level = config.isFloatingPinned ? .floating : .normal
        panel.alphaValue = CGFloat(min(1.0, max(0.3, config.floatingOpacity)))
    }

    public func showQuickPanel(relativeTo button: NSStatusBarButton) {
        let size = NSSize(
            width: KeyliConstants.defaultMenuWidth,
            height: KeyliConstants.panelHeight(forWidth: KeyliConstants.defaultMenuWidth, layout: KeyboardState.shared.currentLayout)
        )

        let panel: NonActivatingPanel
        if let existing = quickPanel {
            panel = existing
        } else {
            panel = NonActivatingPanel(contentRect: NSRect(origin: .zero, size: size), resizable: false)
            panel.level = .statusBar
            panel.animationBehavior = .none
            let quickView = MenuBarQuickView(
                onDetach: { [weak self] in
                    self?.hideQuickPanel()
                    self?.showFloatingKeyboard()
                }
            )
            let hostingView = NSHostingView(rootView: quickView)
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            quickPanel = panel
        }

        var origin = NSPoint(x: 100, y: 100)
        if let buttonWindow = button.window {
            let anchor = buttonWindow.frame
            origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 6)
            let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? anchor
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = max(origin.y, visible.minY + 8)
        }

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        isQuickVisible = true
        updateMonitorVisibility()

        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in
                self?.hideQuickPanel()
            }
        }
    }

    public func hideQuickPanel() {
        guard isQuickVisible else { return }
        quickPanel?.orderOut(nil)
        isQuickVisible = false
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        updateMonitorVisibility()
    }

    public func toggleQuickPanel(relativeTo button: NSStatusBarButton) {
        if isQuickVisible {
            hideQuickPanel()
        } else {
            showQuickPanel(relativeTo: button)
        }
    }

    private func updateMonitorVisibility() {
        PhysicalKeyboardMonitor.shared.hasVisibleKeyboard = isFloatingVisible || isQuickVisible
    }

    private func keepFloatingPanelOnScreen() {
        guard let panel = floatingPanel else { return }
        let clamped = WindowPositioner.clampToVisibleScreen(frame: panel.frame)
        if clamped != panel.frame {
            panel.setFrame(clamped, display: true)
        }
    }

    public func fitPanelsToLayout() {
        let layout = KeyboardState.shared.currentLayout

        if let panel = floatingPanel {
            panel.minSize = NSSize(
                width: KeyliConstants.minFloatingWidth,
                height: KeyliConstants.panelHeight(forWidth: KeyliConstants.minFloatingWidth, layout: layout)
            )
            let frame = panel.frame
            let width = max(KeyliConstants.minFloatingWidth, frame.width)
            let height = KeyliConstants.panelHeight(forWidth: width, layout: layout)
            if abs(height - frame.height) > 0.5 || abs(width - frame.width) > 0.5 {
                let fitted = NSRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
                panel.setFrame(WindowPositioner.clampToVisibleScreen(frame: fitted), display: true)
            }
        }

        if let panel = quickPanel, isQuickVisible {
            let frame = panel.frame
            let height = KeyliConstants.panelHeight(forWidth: frame.width, layout: layout)
            panel.setFrame(NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height), display: true)
        }
    }

    // MARK: - NSWindowDelegate

    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard sender === floatingPanel else { return frameSize }
        let layout = KeyboardState.shared.currentLayout
        let current = sender.frame.size
        let widthFromHeight = KeyliConstants.panelWidth(forHeight: frameSize.height, layout: layout)
        let widthDelta = abs(frameSize.width - current.width)
        let heightDrivenDelta = abs(widthFromHeight - current.width)

        var width = widthDelta >= heightDrivenDelta ? frameSize.width : widthFromHeight
        let visible = (sender.screen ?? NSScreen.main)?.visibleFrame.size ?? NSSize(width: 2000, height: 1200)
        let maxWidth = min(visible.width, KeyliConstants.panelWidth(forHeight: visible.height, layout: layout))
        width = min(max(width, KeyliConstants.minFloatingWidth), maxWidth)
        return NSSize(width: width, height: KeyliConstants.panelHeight(forWidth: width, layout: layout))
    }

    public func windowDidMove(_ notification: Notification) {
        savePanelFrame(notification)
    }

    public func windowDidResize(_ notification: Notification) {
        savePanelFrame(notification)
    }

    private func savePanelFrame(_ notification: Notification) {
        guard let panel = floatingPanel, (notification.object as? NSWindow) === panel else { return }
        let f = panel.frame
        var config = ConfigStore.shared.config
        config.floatingWindowX = f.origin.x
        config.floatingWindowY = f.origin.y
        config.floatingWindowWidth = f.size.width
        config.floatingWindowHeight = f.size.height
        if config != ConfigStore.shared.config {
            ConfigStore.shared.config = config
        }
    }
}
