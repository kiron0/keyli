import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no Dock icon, menu bar agent)
        NSApp.setActivationPolicy(.accessory)

        guard SingleInstanceService.shared.ensureSingleInstance() else {
            NSApp.terminate(nil)
            return
        }

        KeyboardCoordinator.shared.start()
        StatusItemController.shared.setup()

        // If floating keyboard is preferred or was visible, restore
        if ConfigStore.shared.config.isFloatingVisible && SetupAssistantModel.isCompleted() {
            PanelManager.shared.showFloatingKeyboard()
        }
        SetupAssistantController.shared.showIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if PanelManager.shared.isFloatingVisible {
            SettingsWindowController.shared.showSettings()
        } else {
            PanelManager.shared.showFloatingKeyboard()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        PanelManager.shared.flushPendingFrameSave()
        ThemeManager.shared.flushPendingWrites()
        PhysicalKeyboardMonitor.shared.stop()
    }
}
