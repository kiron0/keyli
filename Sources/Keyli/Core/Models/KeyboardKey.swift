import Foundation

public enum KeyKind: String, Codable, Equatable {
    case character
    case modifier
    case function
    case navigation
    case system
    case spacer
}

public enum ModifierType: String, Codable, Equatable {
    case shift
    case control
    case option
    case command
    case capsLock
    case fn
}

public enum KeySystemAction: String, Codable, Equatable {
    case brightnessDown
    case brightnessUp
    case missionControl
    case spotlight
    case previousTrack
    case playPause
    case nextTrack
    case mute
    case volumeDown
    case volumeUp
    case lockScreen
}

public struct KeyUnitFrame: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double = 1.0, height: Double = 1.0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct KeyLabels: Codable, Equatable {
    public var defaultLabel: String
    public var shiftLabel: String?
    public var optionLabel: String?
    public var shiftOptionLabel: String?

    public init(
        defaultLabel: String,
        shiftLabel: String? = nil,
        optionLabel: String? = nil,
        shiftOptionLabel: String? = nil
    ) {
        self.defaultLabel = defaultLabel
        self.shiftLabel = shiftLabel
        self.optionLabel = optionLabel
        self.shiftOptionLabel = shiftOptionLabel
    }
}

public struct KeyboardKey: Identifiable, Codable, Equatable {
    public var id: String
    public var keyCode: UInt16
    public var kind: KeyKind
    public var modifierType: ModifierType?
    public var unitFrame: KeyUnitFrame
    public var labels: KeyLabels
    public var symbolIcon: String?
    public var systemAction: KeySystemAction?
    public var topLeftExtension: Double?
    public var remap: RemapAction? = nil
    public var shortcutKeyCode: UInt16? = nil

    public init(
        id: String,
        keyCode: UInt16,
        kind: KeyKind = .character,
        modifierType: ModifierType? = nil,
        unitFrame: KeyUnitFrame,
        labels: KeyLabels,
        symbolIcon: String? = nil,
        systemAction: KeySystemAction? = nil,
        topLeftExtension: Double? = nil
    ) {
        self.id = id
        self.keyCode = keyCode
        self.kind = kind
        self.modifierType = modifierType
        self.unitFrame = unitFrame
        self.labels = labels
        self.symbolIcon = symbolIcon
        self.systemAction = systemAction
        self.topLeftExtension = topLeftExtension
    }

    public func displayedLabel(shift: Bool, option: Bool, capsLock: Bool = false) -> String {
        if option {
            if shift, let so = labels.shiftOptionLabel, !so.isEmpty {
                return so
            }
            if let o = labels.optionLabel, !o.isEmpty {
                return o
            }
        }

        let isLetter = labels.defaultLabel.count == 1 && (labels.defaultLabel.first?.isLetter == true)
        let effectiveShift = (capsLock && isLetter) ? !shift : shift

        if effectiveShift, let s = labels.shiftLabel, !s.isEmpty {
            return s
        }

        return labels.defaultLabel
    }
}
