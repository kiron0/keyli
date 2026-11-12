import Foundation

public enum GeometryType: String, Codable, CaseIterable {
    case ansi = "ansi"
    case iso = "iso"
    case jis = "jis"
    case compact = "compact"

    public var displayName: String {
        switch self {
        case .ansi: return "US ANSI (Standard)"
        case .iso: return "ISO (European)"
        case .jis: return "JIS (Japanese)"
        case .compact: return "Compact (60%)"
        }
    }
}

public struct KeyboardLayout: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var geometryType: GeometryType
    public var inputSourceId: String?
    public var inputSourceName: String?
    public var unitWidth: Double
    public var unitHeight: Double
    public var keys: [KeyboardKey]

    public init(
        id: String,
        name: String,
        geometryType: GeometryType,
        inputSourceId: String? = nil,
        inputSourceName: String? = nil,
        unitWidth: Double,
        unitHeight: Double,
        keys: [KeyboardKey]
    ) {
        self.id = id
        self.name = name
        self.geometryType = geometryType
        self.inputSourceId = inputSourceId
        self.inputSourceName = inputSourceName
        self.unitWidth = unitWidth
        self.unitHeight = unitHeight
        self.keys = keys
    }
}
