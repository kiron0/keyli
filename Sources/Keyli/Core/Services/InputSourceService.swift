import Foundation
import Carbon
import AppKit

public struct InputSourceOption: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
}

public final class InputSourceService: ObservableObject {
    public static let shared = InputSourceService()

    @Published public private(set) var sources: [InputSourceOption] = []
    @Published public private(set) var currentId: String = ""

    private var observer: NSObjectProtocol?

    private init() {
        refresh()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let observer = observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
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

    public func openInputSourceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
