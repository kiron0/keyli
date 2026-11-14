import AppKit
import SwiftUI

@MainActor
final class AppUpdateWindowController: NSObject, NSWindowDelegate {
    static let shared = AppUpdateWindowController()
    private let windowWidth: CGFloat = 390
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func showCheckWindow() {
        if let win = window {
            NSApp.activate()
            win.makeKeyAndOrderFront(nil)
            return
        }

        buildAndPresentWindow()
    }

    private func buildAndPresentWindow() {
        let contentView = AppUpdateView(
            service: UpdateDownloadService.shared,
            checker: UpdateChecker.shared,
            onDismiss: { [weak self] in
                self?.close()
            }
        )
        let hosting = NSHostingController(rootView: contentView)
        hosting.safeAreaRegions = []
        hosting.sizingOptions = [.preferredContentSize]
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        let fittingSize = hosting.sizeThatFits(
            in: NSSize(width: windowWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        win.setContentSize(NSSize(width: windowWidth, height: ceil(fittingSize.height)))
        win.isOpaque = false
        win.backgroundColor = .clear
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.closeButton)?.isEnabled = true
        win.standardWindowButton(.closeButton)?.isHidden = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.animationBehavior = .none
        win.delegate = self
        self.window = win
        WindowActivationCoordinator.update()

        win.center()
        NSApp.activate()
        win.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
        cancelActiveDownloadIfNeeded()
        UpdateChecker.shared.resetState()
        WindowActivationCoordinator.update()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        cancelActiveDownloadIfNeeded()
        UpdateChecker.shared.resetState()
        WindowActivationCoordinator.update()
    }

    private func cancelActiveDownloadIfNeeded() {
        if case .ready = UpdateDownloadService.shared.state { return }
        UpdateDownloadService.shared.cancelDownload()
    }
}
