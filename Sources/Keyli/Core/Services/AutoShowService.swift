import AppKit
import ApplicationServices
import Combine

public final class AutoShowService {
    public static let shared = AutoShowService()

    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var autoShown = false
    private var cancellables: Set<AnyCancellable> = []
    private var hideWork: DispatchWorkItem?

    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]
    static let blockedSubroles: Set<String> = ["AXSecureTextField"]

    public static func isTextInput(role: String?, subrole: String?, editable: Bool?) -> Bool {
        guard let role else { return false }
        if let subrole, blockedSubroles.contains(subrole) { return false }
        if role == "AXSecureTextField" { return false }
        return textRoles.contains(role) && editable != false
    }

    public static func shouldShow(enabled: Bool, isText: Bool, bundleId: String?, excluded: [String], keyboardVisible: Bool) -> Bool {
        guard enabled, isText, !keyboardVisible else { return false }
        if let bundleId, excluded.contains(bundleId) { return false }
        return true
    }

    public func start() {
        ConfigStore.shared.$config
            .map(\.autoShowKeyboard)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled, let app = FocusManager.shared.targetApplication {
                    self.observe(app)
                } else if !enabled {
                    self.stopObserving()
                }
            }
            .store(in: &cancellables)
    }

    public func observe(_ app: NSRunningApplication) {
        guard ConfigStore.shared.config.autoShowKeyboard, PermissionsManager.canTypeNow else {
            stopObserving()
            return
        }
        let pid = app.processIdentifier
        guard pid != observedPID else { return }
        stopObserving()
        var created: AXObserver?
        let callback: AXObserverCallback = { _, element, _, refcon in
            guard let refcon else { return }
            let service = Unmanaged<AutoShowService>.fromOpaque(refcon).takeUnretainedValue()
            service.focusChanged(element)
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(created, appElement, kAXFocusedUIElementChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        observedPID = pid
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let element = Self.axElement(focused) {
            focusChanged(element)
        }
    }

    public func stopObserving() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        observedPID = 0
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    static func isTextElement(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for depth in 0..<4 {
            guard let node = current else { return false }
            let role = string(node, kAXRoleAttribute)
            let subrole = string(node, kAXSubroleAttribute)
            if role == "AXSecureTextField" || subrole == "AXSecureTextField" { return false }
            var settable: DarwinBoolean = false
            let editable = AXUIElementIsAttributeSettable(node, kAXValueAttribute as CFString, &settable) == .success ? settable.boolValue : nil
            if isTextInput(role: role, subrole: subrole, editable: editable) { return true }
            if depth == 0 {
                var ancestor: CFTypeRef?
                if AXUIElementCopyAttributeValue(node, "AXEditableAncestor" as CFString, &ancestor) == .success, ancestor != nil { return true }
            }
            var parent: CFTypeRef?
            current = AXUIElementCopyAttributeValue(node, kAXParentAttribute as CFString, &parent) == .success ? axElement(parent) : nil
        }
        return false
    }

    private func currentFocusIsText() -> Bool {
        guard observedPID != 0 else { return false }
        let app = AXUIElementCreateApplication(observedPID)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = Self.axElement(focused) else { return false }
        return Self.isTextElement(element)
    }

    static func axElement(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func focusChanged(_ element: AXUIElement) {
        let isText = Self.isTextElement(element)
        let config = ConfigStore.shared.config
        let panel = PanelManager.shared
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if isText {
                self.hideWork?.cancel()
                if Self.shouldShow(enabled: config.autoShowKeyboard, isText: true, bundleId: FocusManager.shared.targetApplication?.bundleIdentifier, excluded: config.autoShowExcludedApps, keyboardVisible: panel.isFloatingVisible) {
                    panel.showFloatingKeyboard()
                    self.autoShown = true
                }
            } else if config.autoHideKeyboard, self.autoShown, panel.isFloatingVisible {
                self.hideWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.autoShown, panel.isFloatingVisible else { return }
                    if self.currentFocusIsText() || panel.containsPointer || NSRunningApplication.current.isActive {
                        return
                    }
                    panel.hideFloatingKeyboard()
                    self.autoShown = false
                }
                self.hideWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
            }
        }
    }

    public func userToggledKeyboard() {
        autoShown = false
        hideWork?.cancel()
    }
}
