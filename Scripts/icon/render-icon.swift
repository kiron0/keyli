import AppKit
import CoreGraphics

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func hex(_ h: String, _ a: CGFloat = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: String(h.dropFirst())).scanHexInt64(&v)
    return CGColor(colorSpace: cs, components: [CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255, a])!
}

func linear(_ ctx: CGContext, _ colors: [CGColor], _ locs: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radial(_ ctx: CGContext, _ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsBeforeStartLocation])
}

func squirclePath(_ file: String) -> CGPath {
    let p = CGMutablePath()
    let lines = try! String(contentsOfFile: file, encoding: .utf8).split(separator: "\n")
    for (i, line) in lines.enumerated() {
        let parts = line.split(separator: " ").map { CGFloat(Double($0)!) }
        let pt = CGPoint(x: parts[0], y: parts[1])
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

func roundedRect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

let args = CommandLine.arguments
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)
ctx.interpolationQuality = .high

let plate = squirclePath(args[1])

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 40, color: hex("#000000", 0.34))
ctx.addPath(plate)
ctx.setFillColor(hex("#26272B"))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(plate)
ctx.clip()
linear(ctx, [hex("#3C3D42"), hex("#2A2B2F"), hex("#1B1C1F")], [0, 0.5, 1], from: CGPoint(x: 280, y: 100), to: CGPoint(x: 744, y: 924))
radial(ctx, [hex("#FFFFFF", 0.16), hex("#FFFFFF", 0)], center: CGPoint(x: 290, y: 165), radius: 700)
radial(ctx, [hex("#E8A33D", 0.16), hex("#E8A33D", 0)], center: CGPoint(x: 618, y: 398), radius: 420)
ctx.setStrokeColor(hex("#FFFFFF", 0.05))
ctx.setLineWidth(2)
for r in [CGFloat(250), 350, 450] {
    ctx.addEllipse(in: CGRect(x: 470 - r - 28, y: 560 - r, width: r * 2, height: r * 2))
}
ctx.strokePath()
ctx.restoreGState()

let stemX: CGFloat = 344
let top: CGFloat = 258
let bottom: CGFloat = 766
let joint = CGPoint(x: stemX + 6, y: 600)
let key = CGRect(x: 526, y: 306, width: 184, height: 184)
let armEnd = CGPoint(x: key.minX + 44, y: key.maxY - 44)
let legStart = CGPoint(x: joint.x + (armEnd.x - joint.x) * 0.36, y: joint.y + (armEnd.y - joint.y) * 0.36)
let legEnd = CGPoint(x: 640, y: bottom)

let ink = CGMutablePath()
ink.move(to: CGPoint(x: stemX, y: top)); ink.addLine(to: CGPoint(x: stemX, y: bottom))
ink.move(to: joint); ink.addLine(to: armEnd)
ink.move(to: legStart); ink.addLine(to: legEnd)
let inkShape = ink.copy(strokingWithWidth: 92, lineCap: .round, lineJoin: .round, miterLimit: 10)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 36, color: hex("#000000", 0.42))
ctx.addPath(inkShape)
ctx.setFillColor(hex("#F4F1EB"))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(inkShape)
ctx.clip()
linear(ctx, [hex("#FFFFFF"), hex("#E7E2D9")], [0, 1], from: CGPoint(x: 512, y: top), to: CGPoint(x: 512, y: bottom))
ctx.restoreGState()

let keyPath = roundedRect(key, 50)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 60, color: hex("#F5A524", 0.55))
ctx.addPath(keyPath)
ctx.setFillColor(hex("#E8A33D"))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 26, color: hex("#3A2100", 0.45))
ctx.addPath(keyPath)
ctx.setFillColor(hex("#E8A33D"))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(keyPath)
ctx.clip()
linear(ctx, [hex("#FFD27A"), hex("#F2AE45"), hex("#D98A1F")], [0, 0.55, 1], from: CGPoint(x: key.midX, y: key.minY), to: CGPoint(x: key.midX, y: key.maxY))
radial(ctx, [hex("#FFFFFF", 0.35), hex("#FFFFFF", 0)], center: CGPoint(x: key.minX + 50, y: key.minY + 34), radius: 150)
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(roundedRect(key.insetBy(dx: 2, dy: 2), 48))
ctx.setStrokeColor(hex("#FFFFFF", 0.45))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

ctx.saveGState()
let rimTransform = CGAffineTransform(translationX: 512, y: 512).scaledBy(x: 0.994, y: 0.994).translatedBy(x: -512, y: -512)
ctx.addPath(plate.copy(using: [rimTransform])!)
ctx.setLineWidth(5)
ctx.replacePathWithStrokedPath()
ctx.clip()
linear(ctx, [hex("#FFFFFF", 0.42), hex("#FFFFFF", 0.06), hex("#FFFFFF", 0.14)], [0, 0.4, 1], from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 924))
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
