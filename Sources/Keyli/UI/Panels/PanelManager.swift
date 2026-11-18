import AppKit
import SwiftUI

public final class PanelManager: NSObject, NSWindowDelegate {
    public static let shared = PanelManager()

    private var floatingPanel: NonActivatingPanel?
    private var screenObserver: NSObjectProtocol?
    private var pendingFrameSave: DispatchWorkItem?
    private var isLiveResizing = false
    private var resizeDrivenByHeight = false
    public private(set) var isFloatingVisible: Bool = false {
        didSet {
            if oldValue != isFloatingVisible {
                onVisibilityChange?(isFloatingVisible)
            }
        }
    }

    public var onVisibilityChange: ((Bool) -> Void)?

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
        KeyboardState.shared.releaseAllModifiers()
        if ConfigStore.shared.config.isFloatingVisible {
            ConfigStore.shared.config.isFloatingVisible = false
        }
        updateMonitorVisibility()
    }

    public func toggleFloatingKeyboard() {
        AutoShowService.shared.userToggledKeyboard()
        if isFloatingVisible, let panel = floatingPanel, !panel.occlusionState.contains(.visible) || isCoveredByOtherWindows(panel) {
            panel.orderFrontRegardless()
            return
        }
        if isFloatingVisible {
            hideFloatingKeyboard()
        } else {
            showFloatingKeyboard()
        }
    }

    private func isCoveredByOtherWindows(_ panel: NSPanel) -> Bool {
        guard panel.level == .normal else { return false }
        let options: CGWindowListOption = [.optionOnScreenAboveWindow, .excludeDesktopElements]
        guard let above = CGWindowListCopyWindowInfo(options, CGWindowID(panel.windowNumber)) as? [[String: Any]] else { return false }
        let frame = panel.frame
        let screenHeight = NSScreen.screens.first?.frame.height ?? frame.maxY
        let panelRect = CGRect(x: frame.minX, y: screenHeight - frame.maxY, width: frame.width, height: frame.height)
        for info in above {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  (info[kCGWindowAlpha as String] as? CGFloat ?? 1) > 0.1 else { continue }
            let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            let overlap = rect.intersection(panelRect)
            if !overlap.isNull && overlap.width * overlap.height > panelRect.width * panelRect.height * 0.25 {
                return true
            }
        }
        return false
    }

    public var containsPointer: Bool {
        guard let panel = floatingPanel, panel.isVisible else { return false }
        return panel.frame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation)
    }

    public func applyWindowConfig() {
        guard let panel = floatingPanel else { return }
        let config = ConfigStore.shared.config
        panel.level = config.isFloatingPinned ? .floating : .normal
        panel.isMovable = !config.isFloatingPositionLocked
        applySizeLock(to: panel)
        panel.alphaValue = CGFloat(min(1.0, max(0.3, config.floatingOpacity)))
    }

    private func applySizeLock(to panel: NSPanel) {
        if ConfigStore.shared.config.isFloatingPositionLocked {
            panel.minSize = panel.frame.size
            panel.maxSize = panel.frame.size
        } else {
            panel.minSize = minimumSize(for: KeyboardState.shared.currentLayout)
            panel.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    private func updateMonitorVisibility() {
        PhysicalKeyboardMonitor.shared.hasVisibleKeyboard = isFloatingVisible
    }

    private func keepFloatingPanelOnScreen() {
        guard let panel = floatingPanel else { return }
        let clamped = WindowPositioner.clampToVisibleScreen(frame: panel.frame)
        if clamped != panel.frame {
            panel.setFrame(clamped, display: true)
        }
    }

    private func minimumSize(for layout: KeyboardLayout) -> NSSize {
        NSSize(
            width: KeyliConstants.minFloatingWidth,
            height: KeyliConstants.panelHeight(forWidth: KeyliConstants.minFloatingWidth, layout: layout)
        )
    }

    public func fitPanelsToLayout(preservingHeight: Bool = false) {
        guard let panel = floatingPanel else { return }
        let layout = KeyboardState.shared.currentLayout
        panel.minSize = minimumSize(for: layout)
        panel.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let frame = panel.frame
        var width = max(KeyliConstants.minFloatingWidth, frame.width)
        if preservingHeight {
            let screenWidth = (panel.screen ?? NSScreen.main)?.visibleFrame.width ?? .greatestFiniteMagnitude
            width = min(screenWidth, max(KeyliConstants.minFloatingWidth, KeyliConstants.panelWidth(forHeight: frame.height, layout: layout)))
        }
        let height = KeyliConstants.panelHeight(forWidth: width, layout: layout)
        if abs(height - frame.height) > 0.5 || abs(width - frame.width) > 0.5 {
            let fitted = NSRect(x: frame.minX, y: frame.maxY - height, width: width, height: height)
            panel.setFrame(WindowPositioner.clampToVisibleScreen(frame: fitted), display: true)
        }
        applySizeLock(to: panel)
    }

    public static func proportionalSize(
        proposed: NSSize,
        drivenByHeight: Bool,
        layout: KeyboardLayout,
        maxSize: NSSize
    ) -> NSSize {
        var width = drivenByHeight
            ? KeyliConstants.panelWidth(forHeight: proposed.height, layout: layout)
            : proposed.width
        let maxWidth = min(maxSize.width, KeyliConstants.panelWidth(forHeight: maxSize.height, layout: layout))
        width = min(max(width, KeyliConstants.minFloatingWidth), maxWidth).rounded()
        return NSSize(width: width, height: KeyliConstants.panelHeight(forWidth: width, layout: layout))
    }

    public func windowWillStartLiveResize(_ notification: Notification) {
        guard (notification.object as? NSWindow) === floatingPanel, let panel = floatingPanel else { return }
        isLiveResizing = true
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let edgeTolerance: CGFloat = 12
        let onSideEdge = mouse.x <= frame.minX + edgeTolerance || mouse.x >= frame.maxX - edgeTolerance
        resizeDrivenByHeight = !onSideEdge
    }

    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard sender === floatingPanel else { return frameSize }
        if ConfigStore.shared.config.isFloatingPositionLocked {
            return sender.frame.size
        }
        let visible = (sender.screen ?? NSScreen.main)?.visibleFrame.size ?? NSSize(width: 2000, height: 1200)
        return PanelManager.proportionalSize(
            proposed: frameSize,
            drivenByHeight: isLiveResizing ? resizeDrivenByHeight : abs(frameSize.width - sender.frame.width) < 0.5,
            layout: KeyboardState.shared.currentLayout,
            maxSize: visible
        )
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        guard (notification.object as? NSWindow) === floatingPanel else { return }
        isLiveResizing = false
        scheduleFrameSave(delay: 0)
    }

    public func windowDidMove(_ notification: Notification) {
        guard (notification.object as? NSWindow) === floatingPanel else { return }
        scheduleFrameSave(delay: 0.4)
    }

    public func windowDidResize(_ notification: Notification) {
        guard (notification.object as? NSWindow) === floatingPanel, !isLiveResizing else { return }
        scheduleFrameSave(delay: 0.4)
    }

    private func scheduleFrameSave(delay: TimeInterval) {
        pendingFrameSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.savePanelFrame()
        }
        pendingFrameSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func flushPendingFrameSave() {
        guard let item = pendingFrameSave, !item.isCancelled else { return }
        item.cancel()
        pendingFrameSave = nil
        savePanelFrame()
    }

    private func savePanelFrame() {
        guard let panel = floatingPanel else { return }
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
