import AppKit
import SwiftUI

public enum SetupStep: Int, CaseIterable, Identifiable {
    case welcome
    case accessibility
    case inputMonitoring
    case loginItem
    case done

    public var id: Int { rawValue }

    public var shortTitle: String {
        switch self {
        case .welcome: return "Welcome"
        case .accessibility: return "Typing"
        case .inputMonitoring: return "Key Lighting"
        case .loginItem: return "Login"
        case .done: return "Ready"
        }
    }

    public static func resume(accessibilityGranted: Bool, completed: Bool, saved: Int) -> SetupStep? {
        if completed {
            return accessibilityGranted ? nil : .accessibility
        }
        let savedStep = SetupStep(rawValue: saved) ?? .welcome
        if !accessibilityGranted && savedStep.rawValue > SetupStep.accessibility.rawValue {
            return .accessibility
        }
        return savedStep
    }
}

public final class SetupAssistantModel: ObservableObject {
    @Published public var step: SetupStep {
        didSet {
            isMovingForward = step.rawValue >= oldValue.rawValue
            defaults.set(step.rawValue, forKey: SetupAssistantModel.stepKey)
        }
    }
    @Published public private(set) var isMovingForward = true
    @Published public var hasAppeared = false

    static let completedKey = "io.coreify.keyli.setup.completed"
    static let stepKey = "io.coreify.keyli.setup.step"

    private let defaults: UserDefaults

    public init(step: SetupStep, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.step = step
    }

    public static func isCompleted(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: completedKey)
    }

    public func canAdvance(accessibilityGranted: Bool) -> Bool {
        step != .accessibility || accessibilityGranted
    }

    public func next() {
        guard let following = SetupStep(rawValue: step.rawValue + 1) else { return }
        step = following
    }

    public func back() {
        guard let previous = SetupStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    public func markCompleted() {
        defaults.set(true, forKey: SetupAssistantModel.completedKey)
        defaults.removeObject(forKey: SetupAssistantModel.stepKey)
    }
}

public final class SetupAssistantController: NSObject, NSWindowDelegate {
    public static let shared = SetupAssistantController()
    public static let windowSize = NSSize(width: 600, height: 520)

    private var window: NSWindow?
    private var model: SetupAssistantModel?

    public var isOpen: Bool { window != nil }

    private override init() {
        super.init()
    }

    public func showIfNeeded() {
        PermissionsManager.shared.checkPermissions()
        let defaults = UserDefaults.standard
        if !SetupAssistantModel.isCompleted(defaults)
            && defaults.object(forKey: SetupAssistantModel.stepKey) == nil
            && PermissionsManager.shared.canType
            && defaults.bool(forKey: "io.coreify.keyli.permission.accessibility.wasGranted") {
            SetupAssistantModel(step: .done, defaults: defaults).markCompleted()
        }
        guard let step = SetupStep.resume(
            accessibilityGranted: PermissionsManager.shared.canType,
            completed: SetupAssistantModel.isCompleted(),
            saved: UserDefaults.standard.integer(forKey: SetupAssistantModel.stepKey)
        ) else { return }
        show(from: step)
    }

    public func show(from step: SetupStep = .welcome) {
        if let window = window {
            model?.step = step
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }

        let model = SetupAssistantModel(step: step)
        self.model = model
        let hosting = NSHostingController(rootView: SetupAssistantView(model: model, onFinish: { [weak self] in
            self?.finish()
        }))
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.alphaValue = 0
        window.animationBehavior = .none
        window.title = "Set Up Keyli"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(SetupAssistantController.windowSize)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.fullScreenNone, .moveToActiveSpace]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.delegate = self
        window.center()

        self.window = window
        hosting.view.layoutSubtreeIfNeeded()
        WindowActivationCoordinator.update()
        DispatchQueue.main.async {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0 : 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
            PermissionsManager.shared.startPollingForPermissions()
        }
    }

    private func finish() {
        model?.markCompleted()
        window?.close()
        PanelManager.shared.showFloatingKeyboard()
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
        model = nil
        DispatchQueue.main.async {
            WindowActivationCoordinator.update()
        }
    }
}

struct SetupAssistantView: View {
    @ObservedObject var model: SetupAssistantModel
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var configStore = ConfigStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onFinish: () -> Void

    private var stepAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.34)
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let offset: CGFloat = model.isMovingForward ? 28 : -28
        return .asymmetric(
            insertion: .offset(x: offset).combined(with: .opacity),
            removal: .offset(x: -offset * 0.5).combined(with: .opacity)
        )
    }

    private func go(_ move: () -> Void) {
        withAnimation(stepAnimation, move)
    }

    private func entrance(_ index: Int) -> some ViewModifier {
        EntranceModifier(isVisible: model.hasAppeared || model.step != .welcome, index: index, reduceMotion: reduceMotion)
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 40)
                .padding(.horizontal, 36)

            ZStack(alignment: .topLeading) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(model.step)
                    .transition(stepTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 44)
            .padding(.top, 30)
            .clipped()

            footer
                .frame(height: 30)
                .padding(.horizontal, 36)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(KeyliChrome.accent)
        .background {
            GlassFill(shape: Rectangle())
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            permissions.checkPermissions()
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.5).delay(0.08)) {
                model.hasAppeared = true
            }
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(SetupStep.allCases) { step in
                let reached = step.rawValue <= model.step.rawValue
                VStack(alignment: .leading, spacing: 6) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(KeyliChrome.accent)
                                .scaleEffect(x: reached ? 1 : 0.0001, y: 1, anchor: .leading)
                        }
                        .frame(height: 4)
                    Text(step.shortTitle)
                        .font(.system(size: 10, weight: step == model.step ? .bold : .medium))
                        .foregroundStyle(step == model.step ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(step.rawValue + 1), \(step.shortTitle)\(step == model.step ? ", current" : "")")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .welcome:
            welcome
        case .accessibility:
            permissionStep(
                .accessibility,
                eyebrow: "Step 1 · Required",
                title: "Let Keyli type for you",
                detail: "macOS only lets an app press keys in other apps once you allow it under Accessibility. Without this, Keyli can show the keyboard but can’t type.",
                steps: [
                    "Click Allow Typing.",
                    "In System Settings, turn on Keyli under Privacy & Security › Accessibility.",
                    "Come back here. This page updates by itself."
                ]
            )
        case .inputMonitoring:
            permissionStep(
                .inputMonitoring,
                eyebrow: "Step 2 · Recommended",
                title: "Light up the keys you press",
                detail: "With Input Monitoring, every key you press on your Mac’s keyboard lights the same key on screen. Keyli never records or saves what you type.",
                steps: [
                    "Click Allow Key Lighting.",
                    "Turn on Keyli under Privacy & Security › Input Monitoring.",
                    "If macOS asks, relaunch Keyli."
                ]
            )
        case .loginItem:
            permissionStep(
                .loginItem,
                eyebrow: "Step 3 · Optional",
                title: "Open Keyli when you log in",
                detail: "Keyli waits in the menu bar so the keyboard is one click away. You can change this any time in Settings.",
                steps: []
            )
        case .done:
            done
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            appIcon
                .modifier(entrance(0))
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to Keyli")
                    .font(.system(size: 26, weight: .bold))
                Text("An on-screen keyboard that types into the app you’re using without stealing focus. Setup takes about a minute.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .modifier(entrance(1))
            VStack(alignment: .leading, spacing: 10) {
                checklistRow(symbol: "accessibility", title: "Typing", detail: "Required. Lets Keyli press keys in other apps.")
                    .modifier(entrance(2))
                checklistRow(symbol: "keyboard", title: "Key lighting", detail: "Recommended. Mirrors your physical keyboard on screen.")
                    .modifier(entrance(3))
                checklistRow(symbol: "power", title: "Open at login", detail: "Optional.")
                    .modifier(entrance(4))
            }
            .padding(.top, 4)
            if KeyliChrome.supportsGlass {
                HStack(spacing: 12) {
                    Text("Window style")
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 0)
                    AppearancePicker(width: 190)
                }
                .padding(.top, 6)
                .modifier(entrance(5))
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 18) {
            appIcon
            VStack(alignment: .leading, spacing: 8) {
                Text("You’re all set")
                    .font(.system(size: 26, weight: .bold))
                Text("Click a key to type into the app in front. Keyli lives in the menu bar; open Settings there to change themes, layout or permissions.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach([PermissionKind.accessibility, .inputMonitoring, .loginItem]) { kind in
                    summaryRow(kind)
                }
            }
            .padding(.top, 4)
        }
    }

    private var appIcon: some View {
        Group {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "keyboard")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(KeyliChrome.accent)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }

    private func checklistRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KeyliChrome.accent)
                .frame(width: 30, height: 30)
                .background(KeyliChrome.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(Color.secondary)
            }
        }
    }

    private func summaryRow(_ kind: PermissionKind) -> some View {
        let granted = permissions.status(of: kind) == .granted
        let symbol = granted ? "checkmark.circle.fill" : (kind.isRequired ? "exclamationmark.triangle.fill" : "minus.circle")
        let color: Color = granted ? .green : (kind.isRequired ? .orange : .secondary)
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30)
                .accessibilityHidden(true)
            Text(kind.title).font(.system(size: 12.5, weight: .semibold))
            Spacer(minLength: 0)
            Text(granted ? "On" : "Off").font(.system(size: 11.5)).foregroundStyle(Color.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func permissionStep(_ kind: PermissionKind, eyebrow: String, title: String, detail: String, steps: [String]) -> some View {
        let status = permissions.status(of: kind)
        let isBusy = permissions.busy.contains(kind)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(KeyliChrome.accent)
                    .frame(width: 52, height: 52)
                    .background(KeyliChrome.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(kind.isRequired ? KeyliChrome.accent : Color.secondary)
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                }
            }

            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(KeyliChrome.onAccent)
                                .frame(width: 18, height: 18)
                                .background(KeyliChrome.accent.opacity(0.85), in: Circle())
                            Text(text)
                                .font(.system(size: 12))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                statusPill(status)
                Spacer(minLength: 0)
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    actions(kind, status: status)
                }
            }
            .padding(12)
            .background(KeyliChrome.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(status == .granted ? Color.green.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 0.5)
            )

            if let hint = hint(kind, status: status) {
                Label(hint, systemImage: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func actions(_ kind: PermissionKind, status: PermissionStatus) -> some View {
        switch status {
        case .granted:
            EmptyView()
        case .notGranted, .off:
            Button(primaryTitle(kind)) { request(kind) }
                .buttonStyle(SettingsPrimaryButtonStyle())
        case .waiting, .denied, .requiresApproval:
            if kind != .loginItem {
                Button("Show in Finder") { permissions.revealAppInFinder() }
                    .buttonStyle(SettingsSecondaryButtonStyle())
                    .help("Drag Keyli into the System Settings list if it isn’t there.")
            }
            Button("Open System Settings") { permissions.openSettings(kind) }
                .buttonStyle(SettingsPrimaryButtonStyle())
        case .needsRepair:
            Button("Repair") { permissions.repair(kind) }
                .buttonStyle(SettingsPrimaryButtonStyle())
        case .needsRelaunch:
            Button("Relaunch Keyli") { permissions.relaunch() }
                .buttonStyle(SettingsPrimaryButtonStyle())
        }
    }

    private func primaryTitle(_ kind: PermissionKind) -> String {
        switch kind {
        case .accessibility: return "Allow Typing"
        case .inputMonitoring: return "Allow Key Lighting"
        case .loginItem: return "Open at Login"
        }
    }

    private func request(_ kind: PermissionKind) {
        if kind == .inputMonitoring && !configStore.config.isPhysicalMonitoringEnabled {
            configStore.config.isPhysicalMonitoringEnabled = true
        }
        permissions.request(kind)
    }

    private func hint(_ kind: PermissionKind, status: PermissionStatus) -> String? {
        switch status {
        case .granted:
            return nil
        case .waiting:
            return "Waiting for you to turn on Keyli in System Settings."
        case .denied:
            return "macOS has Keyli turned off. Turn it on in System Settings."
        case .needsRepair:
            return "macOS dropped Keyli’s old entry. Repair clears it and asks again."
        case .needsRelaunch:
            return "Access is on. Relaunch so macOS applies it; setup continues where you left off."
        case .requiresApproval:
            return "Turn on Keyli under General › Login Items & Extensions."
        case .notGranted, .off:
            return kind == .accessibility ? "If Keyli isn’t in the list, use Show in Finder and drag it in." : nil
        }
    }

    private func statusPill(_ status: PermissionStatus) -> some View {
        let granted = status == .granted
        let color: Color = granted ? .green : (status == .denied || status == .needsRepair ? .orange : .secondary)
        let symbol = granted ? "checkmark.circle.fill" : (status == .waiting ? "clock" : "circle.dashed")
        return Label(granted ? "Allowed" : status.label, systemImage: symbol)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(color)
    }

    private var footer: some View {
        let accessibilityGranted = permissions.canType
        return HStack(spacing: 10) {
            if model.step != .welcome && model.step != .done {
                Button("Back") { go { model.back() } }
                    .buttonStyle(SettingsSecondaryButtonStyle())
            }
            Spacer(minLength: 0)
            switch model.step {
            case .welcome:
                Button("Get Started") { go { model.next() } }
                    .buttonStyle(SettingsPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            case .accessibility:
                if !accessibilityGranted {
                    Text("Required to continue")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                Button("Continue") { go { model.next() } }
                    .buttonStyle(SettingsPrimaryButtonStyle())
                    .disabled(!model.canAdvance(accessibilityGranted: accessibilityGranted))
                    .opacity(model.canAdvance(accessibilityGranted: accessibilityGranted) ? 1 : 0.45)
                    .keyboardShortcut(.defaultAction)
            case .inputMonitoring, .loginItem:
                let kind: PermissionKind = model.step == .inputMonitoring ? .inputMonitoring : .loginItem
                if permissions.status(of: kind) == .granted {
                    Button("Continue") { go { model.next() } }
                        .buttonStyle(SettingsPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Skip for Now") { go { model.next() } }
                        .buttonStyle(SettingsSecondaryButtonStyle())
                }
            case .done:
                Button("Start Typing") { onFinish() }
                    .buttonStyle(SettingsPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct EntranceModifier: ViewModifier {
    let isVisible: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 10)
            .animation(reduceMotion ? nil : .smooth(duration: 0.5).delay(0.06 * Double(index)), value: isVisible)
    }
}
