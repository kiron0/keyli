import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard SingleInstanceService.shared.ensureSingleInstance() else {
            NSApp.terminate(nil)
            return
        }

        KeyboardCoordinator.shared.start()
        KeySoundEngine.shared.activate()
        ShortcutManager.shared.start()
        AutoShowService.shared.start()
        PhysicalKeyboardMonitor.shared.refresh()
        StatusItemController.shared.setup()
        UpdateNotifier.installDelegate()
        UpdateChecker.shared.startAutomaticChecks()

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
        UpdateChecker.shared.stopAutomaticChecks()
        PanelManager.shared.flushPendingFrameSave()
        ThemeManager.shared.flushPendingWrites()
        PersonalLexicon.shared.flush()
        PhysicalKeyboardLockService.shared.unlock()
        PhysicalKeyboardMonitor.shared.stop()
    }
}
