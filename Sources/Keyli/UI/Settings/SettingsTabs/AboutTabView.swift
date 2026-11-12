import SwiftUI

public struct AboutTabView: View {
    public init() {}

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(KeyliConstants.appName)
                    .font(.title.weight(.semibold))
                Text(versionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Text("An on-screen keyboard for macOS that types into the app you’re using, without taking focus.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                Button("Visit Website") {
                    if let url = URL(string: "https://keyli.app") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("GitHub Repository") {
                    if let url = URL(string: "https://github.com/keyli") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .buttonStyle(SettingsSecondaryButtonStyle())
            .padding(.top, 4)

            Spacer(minLength: 24)

            Text("© 2026 Coreify. Released under MIT License.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }
}
