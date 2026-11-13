import AppKit
import CoreGraphics

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func hex(_ h: String, _ a: CGFloat = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: String(h.dropFirst())).scanHexInt64(&v)
    return CGColor(colorSpace: cs, components: [CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255, a])!
}
func linear(_ c: CGContext, _ colors: [CGColor], _ locs: [CGFloat], _ a: CGPoint, _ b: CGPoint) {
    c.drawLinearGradient(CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func radial(_ c: CGContext, _ colors: [CGColor], _ p: CGPoint, _ r: CGFloat) {
    c.drawRadialGradient(CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!, startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: [.drawsBeforeStartLocation])
}
func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }
func squircle(_ file: String) -> CGPath {
    let p = CGMutablePath()
    for (i, l) in try! String(contentsOfFile: file, encoding: .utf8).split(separator: "\n").enumerated() {
        let v = l.split(separator: " ").map { CGFloat(Double($0)!) }
        i == 0 ? p.move(to: CGPoint(x: v[0], y: v[1])) : p.addLine(to: CGPoint(x: v[0], y: v[1]))
    }
    p.closeSubpath(); return p
}
func newCtx() -> CGContext {
    let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: S); c.scaleBy(x: 1, y: -1); return c
}
func save(_ c: CGContext, _ path: String) {
    try! NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
let plate = squircle(CommandLine.arguments[1])
let outPath = CommandLine.arguments[2]

func base(_ c: CGContext, top: String, bottom: String) {
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: 14), blur: 40, color: hex("#000000", 0.32))
    c.addPath(plate); c.setFillColor(hex(bottom)); c.fillPath(); c.restoreGState()
    c.saveGState(); c.addPath(plate); c.clip()
    linear(c, [hex(top), hex(bottom)], [0, 1], CGPoint(x: 512, y: 100), CGPoint(x: 512, y: 924))
    radial(c, [hex("#FFFFFF", 0.14), hex("#FFFFFF", 0)], CGPoint(x: 300, y: 160), 650)
    c.restoreGState()
}
func rim(_ c: CGContext) {
    c.saveGState()
    c.addPath(plate.copy(using: [CGAffineTransform(translationX: 512, y: 512).scaledBy(x: 0.994, y: 0.994).translatedBy(x: -512, y: -512)])!)
    c.setLineWidth(5); c.replacePathWithStrokedPath(); c.clip()
    linear(c, [hex("#FFFFFF", 0.40), hex("#FFFFFF", 0.05), hex("#FFFFFF", 0.12)], [0, 0.4, 1], CGPoint(x: 512, y: 100), CGPoint(x: 512, y: 924))
    c.restoreGState()
}
func cursor(_ c: CGContext, tip: CGPoint, scale: CGFloat) {
    let p = CGMutablePath()
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 300), (72, 232), (122, 346), (176, 322), (126, 210), (222, 210)]
    for (i, q) in pts.enumerated() {
        let pt = CGPoint(x: tip.x + q.0 * scale, y: tip.y + q.1 * scale)
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: 12), blur: 22, color: hex("#000000", 0.45))
    c.addPath(p); c.setFillColor(hex("#111214")); c.fillPath(); c.restoreGState()
    c.saveGState(); c.addPath(p); c.setStrokeColor(hex("#FFFFFF")); c.setLineWidth(18 * scale); c.setLineJoin(.round); c.strokePath(); c.restoreGState()
}

do {
    let c = newCtx()
    base(c, top: "#F3EFE7", bottom: "#D9D2C4")
    let panel = CGRect(x: 196, y: 318, width: 632, height: 388)
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: 30), blur: 60, color: hex("#3B2A12", 0.35))
    c.addPath(rr(panel, 64)); c.setFillColor(hex("#26272B")); c.fillPath(); c.restoreGState()
    c.saveGState(); c.addPath(rr(panel, 64)); c.clip()
    linear(c, [hex("#3A3B40"), hex("#1E1F23")], [0, 1], CGPoint(x: 512, y: panel.minY), CGPoint(x: 512, y: panel.maxY))
    c.restoreGState()
    let k: CGFloat = 92, g: CGFloat = 18
    let rowsX: [CGFloat] = [0, 26, 52]
    for r in 0..<2 {
        let count = 5
        let total = CGFloat(count) * k + CGFloat(count - 1) * g
        let x0 = panel.midX - total / 2 + rowsX[r] * 0
        for i in 0..<count {
            let rect = CGRect(x: x0 + CGFloat(i) * (k + g), y: panel.minY + 52 + CGFloat(r) * (k + g), width: k, height: k * 0.86)
            let lit = r == 0 && i == 3
            c.saveGState()
            if lit { c.setShadow(offset: .zero, blur: 40, color: hex("#F5A524", 0.6)) }
            c.addPath(rr(rect, 22)); c.setFillColor(lit ? hex("#E8A33D") : hex("#FFFFFF", 0.13)); c.fillPath(); c.restoreGState()
        }
    }
    let barWidth = 3 * k + 2 * g
    let bar = CGRect(x: panel.midX - barWidth / 2, y: panel.minY + 52 + 2 * (k + g), width: barWidth, height: k * 0.86)
    c.addPath(rr(bar, 22)); c.setFillColor(hex("#FFFFFF", 0.13)); c.fillPath()
    c.addPath(rr(panel.insetBy(dx: 1.5, dy: 1.5), 63)); c.setStrokeColor(hex("#FFFFFF", 0.14)); c.setLineWidth(3); c.strokePath()
    let caret = CGRect(x: 488, y: 180, width: 48, height: 112)
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: 8), blur: 16, color: hex("#3B2A12", 0.3))
    c.addPath(rr(caret, 24)); c.setFillColor(hex("#E8A33D")); c.fillPath(); c.restoreGState()
    rim(c); save(c, outPath)
}

print("wrote \(outPath)")
