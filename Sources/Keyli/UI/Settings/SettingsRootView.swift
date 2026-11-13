import AppKit
import SwiftUI

public final class SettingsNavigationModel: ObservableObject {
    @Published public private(set) var selection: SettingsTab = .keyboard

    public init() {}

    public func select(_ tab: SettingsTab) {
        guard selection != tab else { return }
        selection = tab
    }
}

public struct SettingsRootView: View {
    @ObservedObject public var navigation: SettingsNavigationModel
    @ObservedObject private var permissionsManager = PermissionsManager.shared

    public init(navigation: SettingsNavigationModel) {
        self.navigation = navigation
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(KeyliChrome.accent)
        .background {
            GlassFill(shape: Rectangle())
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(SettingsTab.byCategory, id: \.category) { group in
                VStack(alignment: .leading, spacing: 2) {
                    if !group.category.rawValue.isEmpty {
                        Text(group.category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)
                    }
                    ForEach(group.tabs) { tab in
                        sidebarRow(tab)
                    }
                }
                if group.category == .app {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 46)
        .padding(.bottom, 12)
        .frame(width: SettingsTab.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(KeyliChrome.cardBackground)
    }

    private func sidebarRow(_ tab: SettingsTab) -> some View {
        SettingsSidebarRow(
            tab: tab,
            isSelected: navigation.selection == tab,
            badgeCount: tab == .permissions ? permissionsManager.attentionCount : 0,
            onSelect: { navigation.select(tab) }
        )
        .equatable()
    }

    private var detail: some View {
        let tab = navigation.selection
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tab.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text(tab.headerSummary)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .frame(width: SettingsTab.contentWidth, alignment: .leading)
            .accessibilityElement(children: .combine)

            ScrollView(.vertical, showsIndicators: true) {
                page(for: tab)
                    .padding(.bottom, 28)
                    .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, SettingsTab.detailHorizontalPadding)
        .padding(.top, 40)
        .frame(width: SettingsTab.detailWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .id(tab)
    }

    @ViewBuilder
    private func page(for tab: SettingsTab) -> some View {
        switch tab {
        case .keyboard: KeyboardTabView()
        case .typing: TypingTabView()
        case .themes: ThemesTabView()
        case .general: GeneralTabView()
        case .permissions: PermissionsTabView()
        case .about: AboutTabView()
        }
    }
}

struct SettingsSidebarRow: View, Equatable {
    let tab: SettingsTab
    let isSelected: Bool
    let badgeCount: Int
    let onSelect: () -> Void

    @StateObject private var hover = HoverUIState()

    static func == (lhs: SettingsSidebarRow, rhs: SettingsSidebarRow) -> Bool {
        lhs.tab == rhs.tab && lhs.isSelected == rhs.isSelected && lhs.badgeCount == rhs.badgeCount
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? KeyliChrome.accent : Color.secondary)
                    .frame(width: 18)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 9.5, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.orange, in: Capsule())
                        .accessibilityLabel("\(badgeCount) permissions need attention")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? KeyliChrome.accent.opacity(0.18) : (hover.isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            if hover.isHovered != hovering {
                hover.isHovered = hovering
            }
        }
    }
}
