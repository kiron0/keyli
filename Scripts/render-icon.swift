import AppKit
import CoreGraphics

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func hex(_ h: String, _ a: CGFloat = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: String(h.dropFirst())).scanHexInt64(&v)
    return CGColor(colorSpace: cs, components: [CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255, a])!
}

func superellipse(_ r: CGRect, n: CGFloat = 5.0) -> CGPath {
    let p = CGMutablePath()
    let a = r.width / 2, b = r.height / 2, cx = r.midX, cy = r.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * (c >= 0 ? 1 : -1) * pow(abs(c), 2 / n)
        let y = cy + b * (s >= 0 ? 1 : -1) * pow(abs(s), 2 / n)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let rad = min(radius, min(r.width, r.height) / 2)
    let k: CGFloat = 1.28
    let e = min(rad * k, min(r.width, r.height) / 2)
    p.move(to: CGPoint(x: r.minX + e, y: r.minY))
    p.addLine(to: CGPoint(x: r.maxX - e, y: r.minY))
    p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + e), control1: CGPoint(x: r.maxX - e + rad * 0.62, y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + e - rad * 0.62))
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - e))
    p.addCurve(to: CGPoint(x: r.maxX - e, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.maxY - e + rad * 0.62), control2: CGPoint(x: r.maxX - e + rad * 0.62, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX + e, y: r.maxY))
    p.addCurve(to: CGPoint(x: r.minX, y: r.maxY - e), control1: CGPoint(x: r.minX + e - rad * 0.62, y: r.maxY), control2: CGPoint(x: r.minX, y: r.maxY - e + rad * 0.62))
    p.addLine(to: CGPoint(x: r.minX, y: r.minY + e))
    p.addCurve(to: CGPoint(x: r.minX + e, y: r.minY), control1: CGPoint(x: r.minX, y: r.minY + e - rad * 0.62), control2: CGPoint(x: r.minX + e - rad * 0.62, y: r.minY))
    p.closeSubpath()
    return p
}

func linear(_ ctx: CGContext, _ colors: [CGColor], _ locs: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radial(_ ctx: CGContext, _ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsBeforeStartLocation])
}

let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)
ctx.interpolationQuality = .high
ctx.setShouldAntialias(true)

let amber = "#E8A33D"
let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let body = rounded(bodyRect, 148)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 36, color: hex("#000000", 0.42))
ctx.addPath(body)
ctx.setFillColor(hex("#202226"))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(body)
ctx.clip()
linear(ctx, [hex("#45484E"), hex("#2A2C31"), hex("#17181B")], [0, 0.45, 1], from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 924))

var seed: UInt64 = 0x4B45594C
func rnd() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((seed >> 33) % 10_000) / 10_000
}
for _ in 0..<900 {
    let y = 100 + rnd() * 824
    let alpha = 0.012 + rnd() * 0.03
    ctx.setStrokeColor(hex(rnd() > 0.5 ? "#FFFFFF" : "#000000", alpha))
    ctx.setLineWidth(0.6 + rnd() * 1.2)
    ctx.move(to: CGPoint(x: 100, y: y))
    ctx.addLine(to: CGPoint(x: 924, y: y + (rnd() - 0.5) * 2))
    ctx.strokePath()
}
radial(ctx, [hex("#FFFFFF", 0.16), hex("#FFFFFF", 0)], center: CGPoint(x: 300, y: 150), radius: 560)

let unit: CGFloat = 150
let gap: CGFloat = 22
for (ri, y) in [CGFloat(168), 168 + unit * 0.82 + gap].enumerated() {
    let count = ri == 0 ? 4 : 3
    let total = CGFloat(count) * unit + CGFloat(count - 1) * gap
    let startX = 512 - total / 2
    for i in 0..<count {
        let r = CGRect(x: startX + CGFloat(i) * (unit + gap), y: y, width: unit, height: unit * 0.82)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 26, color: hex(amber, 0.20))
        ctx.addPath(rounded(r, 24))
        ctx.setFillColor(hex("#1A1B1E"))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(rounded(r, 24))
        ctx.clip()
        linear(ctx, [hex("#2E3035"), hex("#222428")], [0, 1], from: CGPoint(x: r.midX, y: r.minY), to: CGPoint(x: r.midX, y: r.maxY))
        ctx.restoreGState()
        ctx.addPath(rounded(r.insetBy(dx: 1, dy: 1), 23))
        ctx.setStrokeColor(hex("#FFFFFF", 0.06))
        ctx.setLineWidth(2)
        ctx.strokePath()
    }
}
ctx.restoreGState()

let skirt = CGRect(x: 512 - 250, y: 380, width: 500, height: 460)
let top = CGRect(x: skirt.minX + 46, y: skirt.minY + 26, width: skirt.width - 92, height: skirt.height - 112)

ctx.saveGState()
ctx.addPath(body)
ctx.clip()
radial(ctx, [hex(amber, 0.55), hex(amber, 0)], center: CGPoint(x: 512, y: skirt.maxY + 10), radius: 300)
ctx.restoreGState()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 26), blur: 44, color: hex("#000000", 0.6))
ctx.addPath(rounded(skirt, 96))
ctx.setFillColor(hex("#141518"))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(rounded(skirt, 96))
ctx.clip()
linear(ctx, [hex("#34373C"), hex("#1E2024"), hex("#121315")], [0, 0.55, 1], from: CGPoint(x: 512, y: skirt.minY), to: CGPoint(x: 512, y: skirt.maxY))
linear(ctx, [hex("#000000", 0.35), hex("#000000", 0), hex("#000000", 0), hex("#000000", 0.35)], [0, 0.18, 0.82, 1], from: CGPoint(x: skirt.minX, y: 0), to: CGPoint(x: skirt.maxX, y: 0))
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(rounded(skirt.insetBy(dx: 1.5, dy: 1.5), 95))
ctx.setStrokeColor(hex("#FFFFFF", 0.10))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 14, color: hex("#000000", 0.45))
ctx.addPath(rounded(top, 74))
ctx.setFillColor(hex("#3A3D43"))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(rounded(top, 74))
ctx.clip()
linear(ctx, [hex("#474A51"), hex("#33363B"), hex("#2B2D32")], [0, 0.5, 1], from: CGPoint(x: 512, y: top.minY), to: CGPoint(x: 512, y: top.maxY))
radial(ctx, [hex("#FFFFFF", 0.10), hex("#FFFFFF", 0)], center: CGPoint(x: top.minX + 110, y: top.minY + 60), radius: 260)
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(rounded(top.insetBy(dx: 1.5, dy: 1.5), 73))
ctx.clip()
ctx.addPath(rounded(top.insetBy(dx: 1.5, dy: 1.5), 73))
ctx.setStrokeColor(hex("#FFFFFF", 0.18))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

let glyph = CGMutablePath()
let gx0 = top.minX + 118, gy0 = top.minY + 86, gy1 = top.maxY - 86
let gx1 = top.maxX - 112
let gMid = (gy0 + gy1) / 2 + 6
let joint = CGPoint(x: gx0 + 8, y: gMid)
glyph.move(to: CGPoint(x: gx0, y: gy0)); glyph.addLine(to: CGPoint(x: gx0, y: gy1))
glyph.move(to: CGPoint(x: gx1, y: gy0)); glyph.addLine(to: joint)
let branch = CGPoint(x: joint.x + (gx1 - joint.x) * 0.32, y: joint.y + (gy0 - joint.y) * 0.32)
glyph.move(to: branch); glyph.addLine(to: CGPoint(x: gx1 + 6, y: gy1))
let stroked = glyph.copy(strokingWithWidth: 52, lineCap: .round, lineJoin: .round, miterLimit: 10)

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 34, color: hex("#FFB547", 0.75))
ctx.addPath(stroked)
ctx.setFillColor(hex("#F2A93B"))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(stroked)
ctx.clip()
linear(ctx, [hex("#FFD58A"), hex("#F2A93B"), hex("#E08A1E")], [0, 0.5, 1], from: CGPoint(x: gx0, y: gy0), to: CGPoint(x: gx1, y: gy1))
ctx.restoreGState()

ctx.saveGState()
let rim = rounded(bodyRect.insetBy(dx: 2, dy: 2), 146)
ctx.addPath(rim)
ctx.setLineWidth(4)
ctx.replacePathWithStrokedPath()
ctx.clip()
linear(ctx, [hex("#FFFFFF", 0.32), hex("#FFFFFF", 0.05), hex("#FFFFFF", 0.10)], [0, 0.45, 1], from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 924))
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let out = CommandLine.arguments[1]
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
