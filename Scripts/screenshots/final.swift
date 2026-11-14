import AppKit
let d = CommandLine.arguments[1], out = CommandLine.arguments[2]
let scale: CGFloat = 2
let cropTop: CGFloat = 34, cropBottom: CGFloat = 934
func cg(_ name: String) -> CGImage { NSImage(contentsOfFile: "\(d)/\(name)")!.cgImage(forProposedRect: nil, context: nil, hints: nil)! }
func save(_ ctx: CGContext, _ file: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: URL(fileURLWithPath: "\(out)/\(file)"))
}
func canvas(from base: CGImage) -> CGContext {
    let w = base.width, h = Int((cropBottom - cropTop) * scale)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let crop = base.cropping(to: CGRect(x: 0, y: cropTop * scale, width: CGFloat(w), height: CGFloat(h)))!
    ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx
}
func paste(_ ctx: CGContext, _ src: CGImage, _ r: CGRect) {
    let px = CGRect(x: r.minX * scale, y: r.minY * scale, width: r.width * scale, height: r.height * scale)
    let piece = src.cropping(to: px)!
    let destY = CGFloat(ctx.height) - (r.maxY - cropTop) * scale
    ctx.draw(piece, in: CGRect(x: px.minX, y: destY, width: px.width, height: px.height))
}
for (src, file) in [("cap_hero.png", "hero.jpg"), ("cap_settings.png", "settings.jpg"), ("cap_studio.png", "theme-studio.jpg")] {
    save(canvas(from: cg(src)), file)
}
let themes = canvas(from: cg("cap_theme_kiln.png"))
paste(themes, cg("cap_theme_riso_print.png"), CGRect(x: 862, y: 125, width: 818, height: 467))
paste(themes, cg("cap_theme_blacklight.png"), CGRect(x: 898, y: 509, width: 782, height: 425))
save(themes, "themes.jpg")
print("ok")
