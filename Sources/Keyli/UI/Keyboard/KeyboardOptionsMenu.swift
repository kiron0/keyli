import SwiftUI

public struct KeyboardOptionsMenuItems: View {
    @ObservedObject public var configStore: ConfigStore = .shared
    @ObservedObject public var themeManager: ThemeManager = .shared
    public var showsWindowOptions: Bool

    public init(showsWindowOptions: Bool) {
        self.showsWindowOptions = showsWindowOptions
    }

    public var body: some View {
        Picker("Layout", selection: $configStore.config.layoutGeometry) {
            ForEach(GeometryType.allCases, id: \.rawValue) { geo in
                Text(geo.displayName).tag(geo.rawValue)
            }
        }
        .pickerStyle(.menu)

        Picker("Theme", selection: Binding(
            get: { themeManager.currentTheme.id },
            set: { themeManager.selectTheme(byId: $0) }
        )) {
            ForEach(themeManager.availableThemes) { theme in
                Text(theme.name).tag(theme.id)
            }
        }
        .pickerStyle(.menu)

        if showsWindowOptions {
            Picker("Opacity", selection: Binding(
                get: { Int((configStore.config.floatingOpacity * 100).rounded()) },
                set: { configStore.config.floatingOpacity = Double($0) / 100.0 }
            )) {
                ForEach([100, 85, 70, 55, 40], id: \.self) { percent in
                    Text("\(percent)%").tag(percent)
                }
            }
            .pickerStyle(.menu)

            Toggle("Keep on Top", isOn: $configStore.config.isFloatingPinned)
            Toggle("Lock Position", isOn: $configStore.config.isFloatingPositionLocked)
        }

        Toggle("Highlight Physical Keys", isOn: $configStore.config.isPhysicalMonitoringEnabled)

        Divider()

        Button("Theme Studio…") {
            NotificationCenter.default.post(name: KeyliConstants.NotificationName.openThemeStudio, object: nil)
        }
        Button("Settings…") {
            NotificationCenter.default.post(name: KeyliConstants.NotificationName.openSettings, object: nil)
        }
        Button("Check for Updates…") {
            Task { @MainActor in
                await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
            }
        }
    }
}

final class HoverUIState: ObservableObject {
    @Published var isHovered: Bool = false
}

public struct KeyboardChromeButton: View {
    public let systemImage: String
    public let tint: Color
    public let help: String
    public let action: () -> Void

    @StateObject private var hover = HoverUIState()

    public init(systemImage: String, tint: Color, help: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tint = tint
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(tint.opacity(hover.isHovered ? 0.95 : 0.7))
                .frame(width: 18, height: 18)
                .background(Circle().fill(tint.opacity(hover.isHovered ? 0.22 : 0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

public struct KeyboardChromeMenu<Content: View>: View {
    public let tint: Color
    public let content: () -> Content

    public init(tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.tint = tint
        self.content = content
    }

    public var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(tint.opacity(0.8))
                .frame(width: 18, height: 18)
                .background(Circle().fill(tint.opacity(0.12)))
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Keyboard Options")
        .accessibilityLabel("Keyboard Options")
    }
}
