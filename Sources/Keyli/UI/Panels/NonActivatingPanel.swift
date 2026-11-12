import AppKit

open class NonActivatingPanel: NSPanel {
    public init(contentRect: NSRect, resizable: Bool = true) {
        var mask: NSWindow.StyleMask = [.nonactivatingPanel, .titled, .fullSizeContentView]
        if resizable {
            mask.insert(.resizable)
        }
        super.init(
            contentRect: contentRect,
            styleMask: mask,
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.becomesKeyOnlyIfNeeded = false
        self.hidesOnDeactivate = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = resizable
        self.isMovable = resizable
        self.animationBehavior = .utilityWindow
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            self.standardWindowButton(button)?.isHidden = true
        }
        if resizable {
            self.minSize = NSSize(width: KeyliConstants.minFloatingWidth, height: KeyliConstants.minFloatingHeight)
        }
    }

    open override var canBecomeKey: Bool {
        return false
    }

    open override var canBecomeMain: Bool {
        return false
    }
}
