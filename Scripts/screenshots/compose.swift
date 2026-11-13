import AppKit

func load(_ p: String) -> NSImage { NSImage(contentsOfFile: p)! }
func write(_ img: NSImage, _ path: String, jpeg: Bool) {
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    let data = jpeg ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])! : rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}
func pixelSize(_ img: NSImage) -> NSSize {
    let r = img.representations.first!
    return NSSize(width: r.pixelsWide, height: r.pixelsHigh)
}
func canvas(_ w: CGFloat, _ h: CGFloat, top: NSColor, bottom: NSColor, draw: (NSRect) -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    NSGradient(starting: top, ending: bottom)!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)
    draw(NSRect(x: 0, y: 0, width: w, height: h))
    img.unlockFocus()
    return img
}
let a = CommandLine.arguments
let shots = a[1], out = a[2]
let cream = NSColor(srgbRed: 0.95, green: 0.93, blue: 0.89, alpha: 1)
let sand = NSColor(srgbRed: 0.86, green: 0.82, blue: 0.75, alpha: 1)

let hero = load("\(shots)/keyboard.png")
let hs = pixelSize(hero)
let heroImg = canvas(2400, 1300, top: cream, bottom: sand) { r in
    let w: CGFloat = 2140, h = w * hs.height / hs.width
    hero.draw(in: NSRect(x: (r.width - w) / 2, y: (r.height - h) / 2, width: w, height: h))
}
write(heroImg, "\(out)/hero.jpg", jpeg: true)

let names = ["keyboard-porcelain", "keyboard-classic_retro", "keyboard-citrus_tide"]
let themesImg = canvas(2400, 1500, top: NSColor(srgbRed: 0.17, green: 0.17, blue: 0.19, alpha: 1), bottom: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)) { r in
    let w: CGFloat = 1300
    let positions: [(CGFloat, CGFloat)] = [(120, 820), (980, 540), (240, 120)]
    for (i, n) in names.enumerated() {
        let img = load("\(shots)/\(n).png")
        let s = pixelSize(img)
        let h = w * s.height / s.width
        img.draw(in: NSRect(x: positions[i].0, y: positions[i].1, width: w, height: h))
    }
}
write(themesImg, "\(out)/themes.jpg", jpeg: true)

for (n, file) in [("settings-themes", "settings.jpg"), ("theme-studio", "theme-studio.jpg")] {
    let img = load("\(shots)/\(n).png")
    let s = pixelSize(img)
    let W: CGFloat = 2400
    let w = min(W - 160, s.width), h = w * s.height / s.width
    let c = canvas(W, h + 160, top: cream, bottom: sand) { r in
        img.draw(in: NSRect(x: (r.width - w) / 2, y: 80, width: w, height: h))
    }
    write(c, "\(out)/\(file)", jpeg: true)
}
print("ok")
