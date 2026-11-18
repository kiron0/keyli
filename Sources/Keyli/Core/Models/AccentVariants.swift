import Foundation
import CoreGraphics

public enum AccentVariants {
    static let table: [Character: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
        "i": ["î", "ï", "í", "ī", "į", "ì"],
        "l": ["ł"],
        "n": ["ñ", "ń"],
        "o": ["ô", "ö", "ò", "ó", "œ", "ø", "ō", "õ"],
        "s": ["ß", "ś", "š"],
        "u": ["û", "ü", "ù", "ú", "ū"],
        "y": ["ÿ"],
        "z": ["ž", "ź", "ż"],
        "?": ["¿"],
        "!": ["¡"],
        "$": ["¢", "£", "€", "¥"],
        "-": ["–", "—"],
        "'": ["‘", "’"],
        "\"": ["“", "”", "«", "»"]
    ]

    public static func variants(for typed: String) -> [String] {
        guard typed.count == 1, let character = typed.first else { return [] }
        if let direct = table[character] {
            return direct
        }
        let lower = Character(character.lowercased())
        guard lower != character, let base = table[lower] else { return [] }
        return base.compactMap { variant in
            let upper = variant.uppercased()
            return upper.count == 1 ? upper : nil
        }
    }
}

public struct AccentPopupLayout: Equatable {
    public let optionSize: CGSize
    public let spacing: CGFloat
    public let padding: CGFloat
    public let frame: CGRect
    public let count: Int

    public init(count: Int, anchor: CGRect, bounds: CGRect, spacing: CGFloat = 3, padding: CGFloat = 4) {
        let side = max(24, min(anchor.width, anchor.height))
        let option = CGSize(width: side, height: side)
        let width = CGFloat(count) * option.width + CGFloat(max(0, count - 1)) * spacing + padding * 2
        let height = option.height + padding * 2
        var x = anchor.midX - width / 2
        x = min(max(bounds.minX, x), max(bounds.minX, bounds.maxX - width))
        var y = anchor.minY - height - 4
        if y < bounds.minY {
            y = anchor.maxY + 4
        }
        self.optionSize = option
        self.spacing = spacing
        self.padding = padding
        self.count = count
        self.frame = CGRect(x: x, y: y, width: width, height: height)
    }

    public func optionFrame(at index: Int) -> CGRect {
        CGRect(
            x: frame.minX + padding + CGFloat(index) * (optionSize.width + spacing),
            y: frame.minY + padding,
            width: optionSize.width,
            height: optionSize.height
        )
    }

    public func index(at point: CGPoint) -> Int? {
        guard frame.insetBy(dx: 0, dy: -8).contains(point) else { return nil }
        for index in 0..<count {
            let cell = optionFrame(at: index).insetBy(dx: -spacing / 2, dy: -(padding + 8))
            if cell.contains(point) { return index }
        }
        return nil
    }
}
