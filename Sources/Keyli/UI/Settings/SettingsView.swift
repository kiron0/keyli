import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case typing = "Typing"
    case appearance = "Appearance"
    case permissions = "Permissions"
    case about = "About"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .typing: return "keyboard"
        case .appearance: return "paintbrush"
        case .permissions: return "lock.shield"
        case .about: return "info.circle"
        }
    }

    public var contentHeight: CGFloat {
        switch self {
        case .general: return 400
        case .typing: return 380
        case .appearance: return 360
        case .permissions: return 300
        case .about: return 330
        }
    }

    public func makeView() -> AnyView {
        let width = SettingsView.contentWidth
        switch self {
        case .general:
            return AnyView(GeneralTabView().frame(width: width, height: contentHeight))
        case .typing:
            return AnyView(TypingTabView().frame(width: width, height: contentHeight))
        case .appearance:
            return AnyView(AppearanceTabView().frame(width: width, height: contentHeight))
        case .permissions:
            return AnyView(PermissionsTabView().frame(width: width, height: contentHeight))
        case .about:
            return AnyView(AboutTabView().frame(width: width, height: contentHeight))
        }
    }
}

public enum SettingsView {
    public static let contentWidth: CGFloat = 520
}

public struct SettingsSliderRow: View {
    public let title: String
    public let valueText: String
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double?

    public init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil, valueText: String) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.valueText = valueText
    }

    public var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                if let step = step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            .frame(maxWidth: 260)
        }
    }
}
