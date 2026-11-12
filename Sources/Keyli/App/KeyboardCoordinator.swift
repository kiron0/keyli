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
        // Initialize Core Services
        PermissionsManager.shared.checkPermissions()
        FocusManager.shared.startObserving()
        KeyboardLayoutManager.shared.startObservingInputSource()
        KeyboardLayoutManager.shared.reloadActiveLayout()
        ThemeManager.shared.applySavedTheme()

        if !PermissionsManager.shared.hasPostEventPermission {
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
            PanelManager.shared.hideQuickPanel()
            SettingsWindowController.shared.showSettings()
        }

        let obs2 = center.addObserver(
            forName: KeyliConstants.NotificationName.openThemeStudio,
            object: nil,
            queue: .main
        ) { _ in
            PanelManager.shared.hideQuickPanel()
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
        }

        if previous.themeId != config.themeId && ThemeManager.shared.currentTheme.id != config.themeId {
            ThemeManager.shared.applySavedTheme()
        }

        if previous.isFloatingPinned != config.isFloatingPinned || previous.floatingOpacity != config.floatingOpacity {
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

        if previous.showMenuBarIcon != config.showMenuBarIcon {
            StatusItemController.shared.applyVisibility(config.showMenuBarIcon)
        }

        if previous.isPhysicalMonitoringEnabled != config.isPhysicalMonitoringEnabled {
            if config.isPhysicalMonitoringEnabled && !PermissionsManager.shared.hasInputMonitoringPermission {
                PermissionsManager.shared.requestInputMonitoring()
            }
            PhysicalKeyboardMonitor.shared.refresh()
        }
    }
}
