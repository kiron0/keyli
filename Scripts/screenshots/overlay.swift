import AppKit
let a = CommandLine.arguments
let base = NSImage(contentsOfFile: a[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let ctx = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
var i = 3
while i + 4 < a.count {
    let win = NSImage(contentsOfFile: a[i])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let x = Double(a[i+1])!, top = Double(a[i+2])!, w = Double(a[i+3])!, h = Double(a[i+4])!
    let rep = NSBitmapImageRep(cgImage: win)
    var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
    for yy in stride(from: 0, to: rep.pixelsHigh, by: 1) { for xx in stride(from: 0, to: rep.pixelsWide, by: 1) where rep.colorAt(x: xx, y: yy)!.alphaComponent > 0.97 {
        minX = min(minX, xx); maxX = max(maxX, xx); minY = min(minY, yy); maxY = max(maxY, yy) } }
    let sx = Double(maxX - minX + 1) / (w * 2), sy = Double(maxY - minY + 1) / (h * 2)
    let ox = x * 2 - Double(minX), oyTop = (top - 34) * 2 - Double(minY)
    let destY = Double(base.height) - oyTop - Double(win.height)
    ctx.draw(win, in: CGRect(x: ox, y: destY, width: Double(win.width), height: Double(win.height)))
    print("placed \(a[i]) scale \(sx) \(sy)")
    i += 5
}
let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
