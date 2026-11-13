import AppKit

let path = CommandLine.arguments[1]
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let screen = NSScreen.main!
let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
window.level = .normal
window.isOpaque = true
window.hasShadow = false
window.ignoresMouseEvents = true
window.collectionBehavior = [.canJoinAllSpaces, .stationary]
let view = NSImageView(frame: NSRect(origin: .zero, size: screen.frame.size))
view.image = NSImage(contentsOfFile: path)
view.imageScaling = .scaleAxesIndependently
window.contentView = view
window.orderFrontRegardless()
signal(SIGTERM) { _ in exit(0) }
app.run()
