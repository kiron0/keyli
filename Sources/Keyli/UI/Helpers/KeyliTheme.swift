import SwiftUI

extension Color {
    private static let hexCacheLock = NSLock()
    private static var hexCache: [String: Color] = [:]

    public init(hex: String, defaultColor: Color = .primary) {
        Color.hexCacheLock.lock()
        let cached = Color.hexCache[hex]
        Color.hexCacheLock.unlock()
        if let cached = cached {
            self = cached
            return
        }
        self.init(uncachedHex: hex, defaultColor: defaultColor)
        if hex.count >= 6 {
            Color.hexCacheLock.lock()
            if Color.hexCache.count > 512 {
                Color.hexCache.removeAll()
            }
            Color.hexCache[hex] = self
            Color.hexCacheLock.unlock()
        }
    }

    private init(uncachedHex hex: String, defaultColor: Color) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }

        guard cleanHex.count == 6 || cleanHex.count == 8 else {
            self = defaultColor
            return
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)

        if cleanHex.count == 6 {
            let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x0000FF) / 255.0
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        } else {
            let r = Double((rgbValue & 0xFF000000) >> 24) / 255.0
            let g = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
            let b = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
            let a = Double(rgbValue & 0x000000FF) / 255.0
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        }
    }

    public func toHex() -> String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
