import SwiftUI

public enum SettingsCategory: String, CaseIterable {
    case keyboard = "Keyboard"
    case app = "App"
    case info = ""
}

public enum SettingsTab: String, CaseIterable, Identifiable {
    case keyboard = "Keyboard"
    case typing = "Typing"
    case themes = "Themes"
    case general = "General"
    case permissions = "Permissions"
    case about = "About"

    public var id: String { rawValue }

    public var category: SettingsCategory {
        switch self {
        case .keyboard, .typing, .themes: return .keyboard
        case .general, .permissions: return .app
        case .about: return .info
        }
    }

    public static var byCategory: [(category: SettingsCategory, tabs: [SettingsTab])] {
        SettingsCategory.allCases.map { category in
            (category, SettingsTab.allCases.filter { $0.category == category })
        }
    }

    public var icon: String {
        switch self {
        case .keyboard: return "keyboard"
        case .typing: return "character.cursor.ibeam"
        case .themes: return "paintpalette"
        case .general: return "gearshape"
        case .permissions: return "lock.shield"
        case .about: return "info.circle"
        }
    }

    public var tileColors: (top: String, bottom: String) {
        switch self {
        case .keyboard: return ("#6B6E75", "#3E4046")
        case .typing: return ("#F2B552", "#D9891F")
        case .themes: return ("#F07A62", "#D2493A")
        case .general: return ("#A3A6AC", "#7B7E85")
        case .permissions: return ("#5BC27A", "#2F9150")
        case .about: return ("#C9A56E", "#9C7A45")
        }
    }

    public var headerSummary: String {
        switch self {
        case .keyboard: return "The floating keyboard window, layout and key highlighting."
        case .typing: return "How clicked keys are sent to the app you’re using."
        case .themes: return "Pick a look for every keyboard, or design your own."
        case .general: return "Startup, menu bar and reset."
        case .permissions: return "What macOS lets Keyli do, and why. Updates live."
        case .about: return "Version, links and support."
        }
    }

    public static let windowSize = NSSize(width: 820, height: 580)
    public static let sidebarWidth: CGFloat = 210
    public static let detailWidth: CGFloat = windowSize.width - sidebarWidth
    public static let detailHorizontalPadding: CGFloat = 28
    public static let contentWidth: CGFloat = detailWidth - detailHorizontalPadding * 2
}

public enum KeyliChrome {
    public static let accent = Color(hex: "#E8A33D")
    public static let accentNSColor = NSColor(srgbRed: 232 / 255, green: 163 / 255, blue: 61 / 255, alpha: 1)
    public static let onAccent = Color(hex: "#1F1A12")
    public static let cardBackground = Color.primary.opacity(0.035)

    public static var supportsGlass: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }

    public static var usesGlass: Bool {
        supportsGlass && ConfigStore.shared.config.liquidGlassEnabled
    }
}

public struct GlassFill<S: Shape>: View {
    public let shape: S
    @ObservedObject private var configStore: ConfigStore = .shared

    public init(shape: S) {
        self.shape = shape
    }

    public var body: some View {
        if #available(macOS 26.0, *), configStore.config.liquidGlassEnabled {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(Color(NSColor.windowBackgroundColor))
        }
    }
}

public struct SettingsSectionHeader: View {
    public let title: String
    public let symbol: String

    public init(title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(KeyliChrome.accent.opacity(0.12))
                    .frame(width: 24, height: 24)

                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(KeyliChrome.accent)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)

            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(height: 0.5)
        }
        .padding(.top, 14)
    }
}

public struct SettingsRow<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .padding(.leading, 33)
        .padding(.trailing, 10)
    }
}

public struct SettingsSwitchIndicator: View {
    public let isOn: Bool

    public var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? KeyliChrome.accent : Color.primary.opacity(0.13))
                .frame(width: 30, height: 18)
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.16), radius: 1, y: 0.5)
                .offset(x: isOn ? 6 : -6)
        }
        .accessibilityHidden(true)
    }
}

public struct SettingsToggle: View {
    public let title: String
    public var detail: String?
    @Binding public var isOn: Bool

    public init(_ title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    public var body: some View {
        SettingsRow {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isOn.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    SettingsSwitchIndicator(isOn: isOn)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.primary)
                        if let detail = detail {
                            Text(detail)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? "On" : "Off")
        }
    }
}

public struct SettingsSliderRow: View {
    public let title: String
    public let valueText: String
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double

    public init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, valueText: String) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.valueText = valueText
    }

    public var body: some View {
        SettingsRow {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 130, alignment: .leading)
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
                .frame(width: 220)
                .accessibilityLabel(title)
            Text(valueText)
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

public struct SettingsInlineNote: View {
    public let symbol: String
    public let title: String
    public let detail: String

    public init(symbol: String, title: String, detail: String) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KeyliChrome.accent)
                .frame(width: 28, height: 28)
                .background(KeyliChrome.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(KeyliChrome.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KeyliChrome.accent.opacity(0.14), lineWidth: 0.5)
        )
    }
}

public struct SettingsPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(KeyliChrome.onAccent)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(KeyliChrome.accent)
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
    }
}

public struct SettingsSecondaryButtonStyle: ButtonStyle {
    public var isDestructive: Bool

    public init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isDestructive ? Color.red : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
    }
}

public struct SettingsMenuOption<Value: Hashable>: Identifiable {
    public let value: Value
    public let title: String

    public var id: Value { value }

    public init(_ value: Value, _ title: String) {
        self.value = value
        self.title = title
    }
}

public struct SettingsMenuPicker<Value: Hashable>: View {
    public let title: String
    @Binding public var selection: Value
    public let options: [SettingsMenuOption<Value>]
    public var width: CGFloat

    public init(_ title: String, selection: Binding<Value>, options: [SettingsMenuOption<Value>], width: CGFloat = 220) {
        self.title = title
        self._selection = selection
        self.options = options
        self.width = width
    }

    private var currentTitle: String {
        options.first { $0.value == selection }?.title ?? ""
    }

    public var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 8) {
                Text(currentTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .frame(width: width, height: 30)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(title)
        .accessibilityValue(currentTitle)
    }
}

public struct SettingsTabTile: View {
    public let tab: SettingsTab
    public var size: CGFloat

    public init(tab: SettingsTab, size: CGFloat = 22) {
        self.tab = tab
        self.size = size
    }

    public var body: some View {
        let colors = tab.tileColors
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: colors.top), Color(hex: colors.bottom)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            Image(systemName: tab.icon)
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 0.5, y: 0.5)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
