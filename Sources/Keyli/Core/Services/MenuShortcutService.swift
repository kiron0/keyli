import AppKit
import ApplicationServices

public struct ShortcutModifiers: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let control = ShortcutModifiers(rawValue: 1 << 2)
    public static let command = ShortcutModifiers(rawValue: 1 << 3)

    public init(snapshot: KeyModifierSnapshot) {
        var value: ShortcutModifiers = []
        if snapshot.shift { value.insert(.shift) }
        if snapshot.option { value.insert(.option) }
        if snapshot.control { value.insert(.control) }
        if snapshot.command { value.insert(.command) }
        self = value
    }

    public static func fromAccessibilityMask(_ mask: Int) -> ShortcutModifiers {
        var value: ShortcutModifiers = []
        if mask & 1 != 0 { value.insert(.shift) }
        if mask & 2 != 0 { value.insert(.option) }
        if mask & 4 != 0 { value.insert(.control) }
        if mask & 8 == 0 { value.insert(.command) }
        return value
    }
}

public struct MenuShortcut: Equatable {
    public var title: String
    public var character: String?
    public var keyCode: UInt16?
    public var modifiers: ShortcutModifiers

    public init(title: String, character: String? = nil, keyCode: UInt16? = nil, modifiers: ShortcutModifiers) {
        self.title = title
        self.character = character
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public final class MenuShortcutService: ObservableObject {
    public static let shared = MenuShortcutService()

    @Published public private(set) var shortcuts: [MenuShortcut] = []
    @Published public private(set) var pid: pid_t = 0

    private let queue = DispatchQueue(label: "io.coreify.keyli.menu-shortcuts", qos: .userInitiated)
    private var cache: [pid_t: (date: Date, shortcuts: [MenuShortcut])] = [:]
    private var loadingPID: pid_t?
    private static let cacheLifetime: TimeInterval = 20
    private static let maxItems = 1500

    private init() {}

    public func refresh(for app: NSRunningApplication?) {
        guard let app, !app.isTerminated, AXIsProcessTrusted() else {
            if !shortcuts.isEmpty { shortcuts = [] }
            return
        }
        let pid = app.processIdentifier
        if let cached = cache[pid], Date().timeIntervalSince(cached.date) < Self.cacheLifetime {
            publish(cached.shortcuts, pid: pid)
            return
        }
        guard loadingPID != pid else { return }
        loadingPID = pid
        queue.async { [weak self] in
            let loaded = Self.readShortcuts(pid: pid)
            DispatchQueue.main.async {
                guard let self else { return }
                self.loadingPID = nil
                self.cache[pid] = (Date(), loaded)
                if self.cache.count > 8 {
                    let oldest = self.cache.min { $0.value.date < $1.value.date }?.key
                    if let oldest { self.cache[oldest] = nil }
                }
                self.publish(loaded, pid: pid)
            }
        }
    }

    private func publish(_ shortcuts: [MenuShortcut], pid: pid_t) {
        if self.pid != pid { self.pid = pid }
        if self.shortcuts != shortcuts { self.shortcuts = shortcuts }
    }

    public static func shortTitle(_ title: String, limit: Int = 16) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("…") || text.hasSuffix("...") || text.hasSuffix(".") {
            if text.hasSuffix("...") { text.removeLast(3) } else { text.removeLast() }
        }
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    public static func hints(
        for keys: [KeyboardKey],
        modifiers: ShortcutModifiers,
        shortcuts: [MenuShortcut]
    ) -> [String: String] {
        guard modifiers.contains(.command) || modifiers.contains(.control) else { return [:] }
        let matching = shortcuts.filter { $0.modifiers == modifiers }
        guard !matching.isEmpty else { return [:] }
        var byCharacter: [String: String] = [:]
        var byKeyCode: [UInt16: String] = [:]
        for shortcut in matching {
            if let keyCode = shortcut.keyCode, byKeyCode[keyCode] == nil {
                byKeyCode[keyCode] = shortcut.title
            }
            if let character = shortcut.character?.lowercased(), !character.isEmpty, byCharacter[character] == nil {
                byCharacter[character] = shortcut.title
            }
        }
        var result: [String: String] = [:]
        for key in keys where key.kind != .modifier && key.kind != .spacer {
            if let title = byKeyCode[key.keyCode] {
                result[key.id] = shortTitle(title)
                continue
            }
            guard key.kind == .character else { continue }
            let candidates = [key.labels.defaultLabel, key.labels.shiftLabel].compactMap { $0?.lowercased() }
            if let title = candidates.lazy.compactMap({ byCharacter[$0] }).first {
                result[key.id] = shortTitle(title)
            }
        }
        return result
    }

    private static let glyphKeyCodes: [String: UInt16] = [
        "\u{F700}": 126, "\u{F701}": 125, "\u{F702}": 123, "\u{F703}": 124,
        "\u{1B}": 53, "\u{8}": 51, "\u{7F}": 51, "\u{D}": 36, "\u{3}": 76, "\u{9}": 48,
        "\u{F728}": 117, "\u{F729}": 115, "\u{F72B}": 119, "\u{F72C}": 116, "\u{F72D}": 121
    ]

    static func readShortcuts(pid: pid_t) -> [MenuShortcut] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.6)
        guard let menuBar = element(app, kAXMenuBarAttribute) else { return [] }
        var result: [MenuShortcut] = []
        let topItems = children(of: menuBar)
        for (index, item) in topItems.enumerated() where index > 0 {
            for menu in children(of: item) {
                collect(menu: menu, depth: 0, into: &result)
                if result.count >= maxItems { return result }
            }
        }
        return result
    }

    private static func collect(menu: AXUIElement, depth: Int, into result: inout [MenuShortcut]) {
        guard depth < 3 else { return }
        for item in children(of: menu) {
            if result.count >= maxItems { return }
            let title = string(item, kAXTitleAttribute) ?? ""
            let character = string(item, kAXMenuItemCmdCharAttribute)
            let virtualKey = number(item, kAXMenuItemCmdVirtualKeyAttribute)
            if !title.isEmpty, (character?.isEmpty == false || virtualKey != nil) {
                let mask = number(item, kAXMenuItemCmdModifiersAttribute) ?? 0
                var keyCode = virtualKey.map { UInt16(truncatingIfNeeded: $0) }
                var char = character
                if let character, let glyph = glyphKeyCodes[character] {
                    keyCode = glyph
                    char = nil
                }
                result.append(MenuShortcut(
                    title: title,
                    character: char,
                    keyCode: keyCode,
                    modifiers: .fromAccessibilityMask(mask)
                ))
            }
            for submenu in children(of: item) {
                collect(menu: submenu, depth: depth + 1, into: &result)
            }
        }
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let array = value as? [AnyObject] else { return [] }
        return array.compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
        }
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func number(_ element: AXUIElement, _ attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.intValue
    }
}
