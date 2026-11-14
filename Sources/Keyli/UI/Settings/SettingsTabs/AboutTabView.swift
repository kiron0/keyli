import AppKit
import SwiftUI

final class AboutTabPresentationState: ObservableObject {
    @Published var hoveredResource: String?
}

private struct AboutHighlight: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KeyliChrome.accent)
                .frame(width: 28, height: 28)
                .background(KeyliChrome.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AboutResourceCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let footer: String
    let isHovered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                HStack(spacing: 3) {
                    Text(footer)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(isHovered ? KeyliChrome.accent : Color.secondary.opacity(0.8))
                .padding(.top, 3)
            }
            .padding(.horizontal, 3)
        }
        .padding(8)
        .background(KeyliChrome.cardBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isHovered ? KeyliChrome.accent.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: isHovered ? 1 : 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

public struct AboutTabView: View {
    @StateObject private var presentationState = AboutTabPresentationState()
    @ObservedObject private var updateChecker = UpdateChecker.shared

    private var status: (symbol: String, text: String, color: Color) {
        switch updateChecker.checkState {
        case .idle: return ("checkmark.seal", "Ready", .secondary)
        case .checking: return ("arrow.triangle.2.circlepath", "Checking…", KeyliChrome.accent)
        case .available(let version, _, _): return ("arrow.down.circle.fill", "Version \(version) available", KeyliChrome.accent)
        case .upToDate: return ("checkmark.circle.fill", "Up to date", .green)
        case .failed: return ("exclamationmark.circle.fill", "Check unavailable", .red)
        }
    }

    public init() {}

    private static let resourceColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero

            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(title: "Why Keyli", symbol: "sparkles")
                HStack(alignment: .top, spacing: 18) {
                    AboutHighlight(symbol: "swift", title: "Native", detail: "SwiftUI and AppKit, no web views. Tiny and fast.")
                    AboutHighlight(symbol: "hand.raised.fill", title: "Private", detail: "No account, tracking or analytics. Keys are never logged.")
                    AboutHighlight(symbol: "cursorarrow.click.2", title: "Focus-Safe", detail: "Types into your app without taking focus away.")
                }
                .padding(.leading, 33)
            }

            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(title: "Resources", symbol: "lifepreserver")

                LazyVGrid(columns: Self.resourceColumns, alignment: .leading, spacing: 12) {
                    resourceCard(
                        id: "website",
                        symbol: "globe",
                        tint: Color(red: 0.30, green: 0.31, blue: 0.34),
                        title: "Website",
                        detail: "Guides and release notes.",
                        footer: "Open Website",
                        url: KeyliConstants.websiteURL
                    )
                    resourceCard(
                        id: "issues",
                        symbol: "ladybug.fill",
                        tint: Color(red: 0.94, green: 0.38, blue: 0.36),
                        title: "Report an Issue",
                        detail: "Share feedback or a bug.",
                        footer: "Open GitHub",
                        url: KeyliConstants.issuesURL
                    )
                    resourceCard(
                        id: "coffee",
                        symbol: "cup.and.saucer.fill",
                        tint: Color(red: 0.98, green: 0.68, blue: 0.18),
                        title: "Buy Me a Coffee",
                        detail: "Support independent development.",
                        footer: "Open Buy Me a Coffee",
                        url: KeyliConstants.buyMeACoffeeURL
                    )
                }
                .padding(.leading, 33)
            }

            HStack(spacing: 7) {
                Image(systemName: "heart.fill").foregroundStyle(KeyliChrome.accent)
                Text("Designed and built by")
                Button(KeyliConstants.author) {
                    NSWorkspace.shared.open(KeyliConstants.authorURL)
                }
                .buttonStyle(.link)
                Text("•").foregroundStyle(Color.secondary.opacity(0.6))
                Button("GitHub") {
                    NSWorkspace.shared.open(KeyliConstants.repositoryURL)
                }
                .buttonStyle(.link)
                Spacer(minLength: 0)
                Text(KeyliConstants.copyright)
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Color.secondary)
            .padding(.top, 4)
        }
        .padding(.top, 4)
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
    }

    private var hero: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(KeyliConstants.appName)
                        .font(.system(size: 21, weight: .bold))
                    Text("VERSION \(KeyliConstants.appVersion)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(KeyliChrome.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(KeyliChrome.accent.opacity(0.11), in: Capsule())
                        .textSelection(.enabled)
                }
                Text(KeyliConstants.tagline)
                    .font(.system(size: 12.5, weight: .medium))
                Label(status.text, systemImage: status.symbol)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(status.color)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Button(updateChecker.isChecking ? "Checking…" : "Check for Updates") {
                    Task { await updateChecker.checkForUpdates(isUserInitiated: true) }
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
                .disabled(updateChecker.isChecking)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [KeyliChrome.accent.opacity(0.13), KeyliChrome.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func resourceCard(id: String, symbol: String, tint: Color, title: String, detail: String, footer: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            AboutResourceCard(
                symbol: symbol,
                tint: tint,
                title: title,
                detail: detail,
                footer: footer,
                isHovered: presentationState.hoveredResource == id
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(detail)")
        .help(url.absoluteString)
        .onHover { hovering in
            if hovering {
                presentationState.hoveredResource = id
            } else if presentationState.hoveredResource == id {
                presentationState.hoveredResource = nil
            }
        }
    }
}
