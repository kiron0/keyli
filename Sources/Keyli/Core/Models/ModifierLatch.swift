import Foundation

public enum ModifierLevel: Equatable {
    case off
    case once
    case locked
}

public enum ModifierPress: Equatable {
    case click
    case sequence
}

public struct ModifierPressRecord: Equatable {
    public var at: TimeInterval
    public var from: ModifierLevel
    public var to: ModifierLevel

    public init(at: TimeInterval, from: ModifierLevel, to: ModifierLevel) {
        self.at = at
        self.from = from
        self.to = to
    }
}

public enum ModifierLatch {
    public static let lockable: [ModifierType] = [.shift, .control, .option, .command]
    public static let holdToLock: TimeInterval = 0.5

    public static func isLockable(_ type: ModifierType) -> Bool {
        lockable.contains(type)
    }

    public static func next(
        current: ModifierLevel,
        press: ModifierPress,
        now: TimeInterval,
        last: ModifierPressRecord?,
        doubleClickInterval: TimeInterval,
        oneShot: Bool
    ) -> ModifierLevel {
        guard oneShot else {
            return current == .off ? .locked : .off
        }
        let isQuickRepeat = last.map { now - $0.at <= doubleClickInterval } ?? false
        switch (current, press) {
        case (.locked, _):
            return .off
        case (.once, .sequence):
            return .locked
        case (.once, .click):
            return isQuickRepeat && last?.to == .once ? .locked : .off
        case (.off, .click):
            return isQuickRepeat && last?.from == .locked && last?.to == .off ? .off : .once
        case (.off, .sequence):
            return .once
        }
    }

    public static func symbol(_ type: ModifierType) -> String {
        switch type {
        case .shift: return "⇧"
        case .control: return "⌃"
        case .option: return "⌥"
        case .command: return "⌘"
        case .capsLock: return "⇪"
        case .fn: return "fn"
        }
    }

    public static func name(_ type: ModifierType) -> String {
        switch type {
        case .shift: return "Shift"
        case .control: return "Control"
        case .option: return "Option"
        case .command: return "Command"
        case .capsLock: return "Caps Lock"
        case .fn: return "fn"
        }
    }
}
