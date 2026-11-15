import Foundation
import AppKit
import Combine

@MainActor
public final class KeyboardCoordinator {
    public static let shared = KeyboardCoordinator()

    private var notificationObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastConfig = ConfigStore.shared.config

    private init() {}

    public func start() {
        PermissionsManager.shared.checkPermissions()
        FocusManager.shared.startObserving()
        KeyboardLayoutManager.shared.startObservingInputSource()
        KeyboardLayoutManager.shared.reloadActiveLayout()
        ThemeManager.shared.applySavedTheme()

        if !PermissionsManager.shared.canType {
            PermissionsManager.shared.startPollingForPermissions()
        }

        setupNotificationObservers()
        observeConfig()
    }

    private func setupNotificationObservers() {
        let center = NotificationCenter.default

        let obs1 = center.addObserver(
            forName: KeyliConstants.NotificationName.openSettings,
            object: nil,
            queue: .main
        ) { _ in
            SettingsWindowController.shared.showSettings()
        }

        let obs2 = center.addObserver(
            forName: KeyliConstants.NotificationName.openThemeStudio,
            object: nil,
            queue: .main
        ) { _ in
            ThemeStudioWindowController.shared.showThemeStudio()
        }

        let obs3 = center.addObserver(
            forName: KeyliConstants.NotificationName.toggleFloatingKeyboard,
            object: nil,
            queue: .main
        ) { _ in
            PanelManager.shared.toggleFloatingKeyboard()
        }

        notificationObservers = [obs1, obs2, obs3]
    }

    private func observeConfig() {
        lastConfig = ConfigStore.shared.config
        ConfigStore.shared.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newConfig in
                MainActor.assumeIsolated {
                    self?.configDidChange(newConfig)
                }
            }
            .store(in: &cancellables)
    }

    private func configDidChange(_ config: KeyliConfig) {
        let previous = lastConfig
        lastConfig = config
        guard previous != config else { return }

        if previous.layoutGeometry != config.layoutGeometry {
            KeyboardLayoutManager.shared.reloadActiveLayout()
            PanelManager.shared.fitPanelsToLayout()
        }

        if previous.themeId != config.themeId && ThemeManager.shared.currentTheme.id != config.themeId {
            ThemeManager.shared.applySavedTheme()
        }

        if previous.isFloatingPinned != config.isFloatingPinned
            || previous.isFloatingPositionLocked != config.isFloatingPositionLocked
            || previous.floatingOpacity != config.floatingOpacity {
            PanelManager.shared.applyWindowConfig()
        }

        if previous.isFloatingVisible != config.isFloatingVisible
            && PanelManager.shared.isFloatingVisible != config.isFloatingVisible {
            if config.isFloatingVisible {
                PanelManager.shared.showFloatingKeyboard()
            } else {
                PanelManager.shared.hideFloatingKeyboard()
            }
        }

        if previous.launchAtLogin != config.launchAtLogin {
            PermissionsManager.shared.checkPermissions()
        }

        if previous.showMenuBarIcon != config.showMenuBarIcon {
            StatusItemController.shared.applyVisibility(config.showMenuBarIcon)
        }

        let physicalSoundsChanged = (previous.playKeyClickSound && previous.keySoundsForPhysicalTyping)
            != (config.playKeyClickSound && config.keySoundsForPhysicalTyping)
        if previous.isPhysicalMonitoringEnabled != config.isPhysicalMonitoringEnabled
            || physicalSoundsChanged
            || previous.keystrokeOverlayEnabled != config.keystrokeOverlayEnabled {
            if !config.keystrokeOverlayEnabled {
                KeystrokeOverlay.shared.hide()
            }
            PhysicalKeyboardMonitor.shared.refresh()
            if PhysicalKeyboardMonitor.shared.needsEventTap && !PermissionsManager.shared.hasInputMonitoringPermission {
                PermissionsManager.shared.requestInputMonitoring()
            }
            PermissionsManager.shared.checkPermissions()
        }
    }
}
