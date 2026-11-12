import AppKit

public enum WindowPositioner {
    public static func clampToVisibleScreen(frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { NSIntersectsRect($0.visibleFrame, frame) }) ?? NSScreen.main else {
            return frame
        }

        let visible = screen.visibleFrame
        var clamped = frame

        if clamped.width > visible.width {
            clamped.size.width = visible.width - 20
        }
        if clamped.height > visible.height {
            clamped.size.height = visible.height - 20
        }

        if clamped.maxX > visible.maxX {
            clamped.origin.x = visible.maxX - clamped.width - 10
        }
        if clamped.minX < visible.minX {
            clamped.origin.x = visible.minX + 10
        }

        if clamped.maxY > visible.maxY {
            clamped.origin.y = visible.maxY - clamped.height - 10
        }
        if clamped.minY < visible.minY {
            clamped.origin.y = visible.minY + 10
        }

        return clamped
    }

    public static func defaultFloatingRect() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 100, width: KeyliConstants.defaultFloatingWidth, height: KeyliConstants.defaultFloatingHeight)
        }
        let visible = screen.visibleFrame
        let width = KeyliConstants.defaultFloatingWidth
        let height = KeyliConstants.defaultFloatingHeight
        let x = visible.midX - (width / 2.0)
        let y = visible.minY + 60.0
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
