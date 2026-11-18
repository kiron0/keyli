import Foundation
import Carbon
import ApplicationServices
import AppKit

public struct InputSourceOption: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
}

public final class InputSourceService: ObservableObject {
    public static let shared = InputSourceService()

    @Published public private(set) var sources: [InputSourceOption] = []
    @Published public private(set) var currentId: String = ""

    private init() {
        refresh()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let service = Unmanaged<InputSourceService>.fromOpaque(observer).takeUnretainedValue()
                if Thread.isMainThread {
                    service.refresh()
                } else {
                    DispatchQueue.main.async { service.refresh() }
                }
            },
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDistributedCenter(), Unmanaged.passUnretained(self).toOpaque())
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func bool(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }

    private static func enabledKeyboardSources() -> [TISInputSource] {
        let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return list.filter { bool($0, kTISPropertyInputSourceIsSelectCapable) && bool($0, kTISPropertyInputSourceIsEnabled) }
    }

    public func refresh() {
        var seen = Set<String>()
        let options = InputSourceService.enabledKeyboardSources().compactMap { source -> InputSourceOption? in
            guard let id = InputSourceService.string(source, kTISPropertyInputSourceID),
                  let name = InputSourceService.string(source, kTISPropertyLocalizedName),
                  seen.insert(id).inserted else { return nil }
            return InputSourceOption(id: id, name: name)
        }
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let currentId = InputSourceService.string(current, kTISPropertyInputSourceID) ?? ""

        if sources != options { sources = options }
        if self.currentId != currentId { self.currentId = currentId }
    }

    @discardableResult
    public func select(id: String) -> Bool {
        guard let source = InputSourceService.enabledKeyboardSources().first(where: { InputSourceService.string($0, kTISPropertyInputSourceID) == id }) else {
            return false
        }
        let status = TISSelectInputSource(source)
        refresh()
        KeyboardLayoutManager.shared.reloadActiveLayout()
        return status == noErr
    }

    @discardableResult
    public func selectNext() -> Bool {
        refresh()
        guard sources.count > 1 else { return false }
        let index = sources.firstIndex(where: { $0.id == currentId }) ?? -1
        let next = sources[(index + 1) % sources.count]
        return select(id: next.id)
    }

    @discardableResult
    public func selectPrevious() -> Bool {
        refresh()
        guard sources.count > 1 else { return false }
        let index = sources.firstIndex(where: { $0.id == currentId }) ?? 0
        let previous = sources[(index + sources.count - 1) % sources.count]
        return select(id: previous.id)
    }

    public func icon(for id: String) -> NSImage? {
        guard let source = InputSourceService.enabledKeyboardSources().first(where: { InputSourceService.string($0, kTISPropertyInputSourceID) == id }) else {
            return nil
        }
        if let pointer = TISGetInputSourceProperty(source, InputSourceService.iconLabelsKey),
           let labels = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? [String: Any],
           let primary = labels["Primary"] as? String, !primary.isEmpty {
            return InputSourceService.labelBadge(primary)
        }
        if let pointer = TISGetInputSourceProperty(source, InputSourceService.iconImageKey),
           let shared = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? NSImage,
           let image = shared.copy() as? NSImage {
            image.size = NSSize(width: 16, height: 16)
            image.isTemplate = InputSourceService.bool(source, InputSourceService.iconShouldBeTemplateKey)
            return image
        }
        if let pointer = TISGetInputSourceProperty(source, kTISPropertyIconImageURL) {
            let url = Unmanaged<CFURL>.fromOpaque(pointer).takeUnretainedValue() as URL
            let candidates = [url] + ["pdf", "tiff", "png", "icns"].map { url.appendingPathExtension($0) }
            if let image = candidates.lazy.compactMap({ NSImage(contentsOf: $0) }).first {
                image.isTemplate = url.lastPathComponent.hasSuffix("Template")
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        }
        return nil
    }

    private static let iconLabelsKey = "TISPropertyInputSourceIconLabels" as CFString
    private static let iconImageKey = "TSMInputSourcePropertyIconImage" as CFString
    private static let iconShouldBeTemplateKey = "TSMInputSourcePropertyIconShouldBeTemplate" as CFString

    public static func labelBadge(_ label: String) -> NSImage {
        let height: CGFloat = 16
        let font = NSFont.systemFont(ofSize: label.count > 1 ? 10 : 11.5, weight: .semibold)
        let text = NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: NSColor.black])
        let textSize = text.size()
        let width = max(ceil(textSize.width) + 10, 22)
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4.5, yRadius: 4.5).fill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            text.draw(at: NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2 + 0.5))
            return true
        }
        image.isTemplate = true
        return image
    }

    public func showEmojiAndSymbols() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let candidate = FocusManager.shared.isTargetValid ? FocusManager.shared.targetApplication : NSWorkspace.shared.frontmostApplication
        guard let target = candidate, target.processIdentifier != ownPID else {
            KeyboardInputDispatcher.shared.postEmojiShortcut()
            return
        }
        let needsActivation = NSRunningApplication.current.isActive || !target.isActive
        if needsActivation {
            target.activate()
        }
        let pid = target.processIdentifier
        let delay: TimeInterval = needsActivation ? 0.12 : 0
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) {
            let pressed = PermissionsManager.canTypeNow && Self.pressEmojiMenuItem(pid: pid)
            if !pressed {
                DispatchQueue.main.async {
                    KeyboardInputDispatcher.shared.postEmojiShortcut()
                }
            }
        }
    }

    static func isEmojiMenuShortcut(character: String, modifiers: Int) -> Bool {
        let key = character.lowercased()
        let globe = 16
        let control = 4
        let noCommand = 8
        if key == "e" && modifiers & globe != 0 { return true }
        if key == " " && modifiers & control != 0 && modifiers & noCommand == 0 { return true }
        return false
    }

    static func pressEmojiMenuItem(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.4)
        func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
            var result: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success ? result : nil
        }
        func children(_ element: AXUIElement) -> [AXUIElement] {
            (value(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
        }
        guard let barValue = value(app, kAXMenuBarAttribute), CFGetTypeID(barValue) == AXUIElementGetTypeID() else { return false }
        let topItems = children(barValue as! AXUIElement)
        guard !topItems.isEmpty else { return false }
        let preferred = [3, 2, 4, 1].filter { $0 < topItems.count }
        let order = preferred + topItems.indices.filter { !preferred.contains($0) && $0 > 0 }
        for index in order {
            guard let menu = children(topItems[index]).first else { continue }
            for item in children(menu).reversed().prefix(4) {
                let character = (value(item, kAXMenuItemCmdCharAttribute) as? String) ?? ""
                let modifiers = (value(item, kAXMenuItemCmdModifiersAttribute) as? Int) ?? 0
                guard isEmojiMenuShortcut(character: character, modifiers: modifiers) else { continue }
                if (value(item, kAXEnabledAttribute) as? Bool) == false { return false }
                return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
            }
        }
        return false
    }

    public func openInputSourceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
