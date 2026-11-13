import AppKit

let args = CommandLine.arguments
let keyboardPath = args[1], iconPath = args[2], outPath = args[3]
let W: CGFloat = 2400, H: CGFloat = 1400

func c(_ hex: String, _ a: CGFloat = 1) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: String(hex.dropFirst())).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
func font(_ size: CGFloat, _ weight: NSFont.Weight, rounded: Bool = false) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if rounded, let d = base.fontDescriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size)! }
    return base
}
func text(_ s: String, _ f: NSFont, _ color: NSColor, kern: CGFloat = 0, at p: NSPoint, lineHeight: CGFloat? = nil, width: CGFloat? = nil) -> NSSize {
    let para = NSMutableParagraphStyle()
    if let lh = lineHeight { para.minimumLineHeight = lh; para.maximumLineHeight = lh }
    let attr = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color, .kern: kern, .paragraphStyle: para])
    if let w = width {
        let r = attr.boundingRect(with: NSSize(width: w, height: 2000), options: [.usesLineFragmentOrigin])
        attr.draw(with: NSRect(x: p.x, y: p.y - r.height, width: w, height: r.height), options: [.usesLineFragmentOrigin])
        return r.size
    }
    let size = attr.size()
    attr.draw(at: NSPoint(x: p.x, y: p.y - size.height))
    return size
}
func rounded(_ r: NSRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) }
func shadow(_ blur: CGFloat, _ dy: CGFloat, _ color: NSColor, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: -dy); s.shadowColor = color; s.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

NSGradient(colors: [c("#26272B"), c("#18191C"), c("#121315")], atLocations: [0, 0.6, 1], colorSpace: .sRGB)!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
NSGradient(colors: [c("#E8A33D", 0.32), c("#E8A33D", 0)])!.draw(fromCenter: NSPoint(x: 1700, y: 360), radius: 0, toCenter: NSPoint(x: 1700, y: 360), radius: 900, options: [])
NSGradient(colors: [c("#FFFFFF", 0.06), c("#FFFFFF", 0)])!.draw(fromCenter: NSPoint(x: 300, y: 1300), radius: 0, toCenter: NSPoint(x: 300, y: 1300), radius: 900, options: [])

var seed: UInt64 = 7
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 10000) / 10000 }
for _ in 0..<26000 {
    c(rnd() > 0.5 ? "#FFFFFF" : "#000000", 0.035).setFill()
    NSRect(x: rnd() * W, y: rnd() * H, width: 1.4, height: 1.4).fill()
}

let barH: CGFloat = 56
c("#000000", 0.28).setFill(); NSRect(x: 0, y: H - barH, width: W, height: barH).fill()
c("#FFFFFF", 0.06).setFill(); NSRect(x: 0, y: H - barH, width: W, height: 1).fill()
var menuX: CGFloat = 110
for (i, item) in ["Notes", "File", "Edit", "Format", "View", "Window", "Help"].enumerated() {
    let size = text(item, font(26, i == 0 ? .bold : .regular), c("#F2EEE6", i == 0 ? 1 : 0.85), at: NSPoint(x: menuX, y: H - 13))
    menuX += size.width + 42
}
_ = text("Fri 9:41 AM", font(26, .medium), c("#F2EEE6", 0.9), at: NSPoint(x: W - 230, y: H - 13))
let pill = NSRect(x: W - 330, y: H - barH + 9, width: 66, height: barH - 18)
c("#E8A33D", 0.22).setFill(); rounded(pill, 10).fill()
if let sym = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 26, weight: .semibold)) {
    let tinted = NSImage(size: sym.size, flipped: false) { r in sym.draw(in: r); c("#F5B54E").set(); r.fill(using: .sourceAtop); return true }
    tinted.draw(in: NSRect(x: pill.midX - sym.size.width / 2, y: pill.midY - sym.size.height / 2, width: sym.size.width, height: sym.size.height))
}
for (i, s) in ["wifi", "battery.75percent", "magnifyingglass"].enumerated() {
    if let sym = NSImage(systemSymbolName: s, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 24, weight: .medium)) {
        let tinted = NSImage(size: sym.size, flipped: false) { r in sym.draw(in: r); c("#F2EEE6", 0.85).set(); r.fill(using: .sourceAtop); return true }
        tinted.draw(at: NSPoint(x: W - 560 + CGFloat(i) * 70, y: H - barH / 2 - sym.size.height / 2), from: .zero, operation: .sourceOver, fraction: 1)
    }
}

let left: CGFloat = 150
let icon = NSImage(contentsOfFile: iconPath)!
shadow(30, 12, c("#000000", 0.45)) { icon.draw(in: NSRect(x: left - 18, y: H - 330, width: 190, height: 190)) }
_ = text("Keyli", font(64, .bold, rounded: true), c("#F2EEE6"), kern: -1, at: NSPoint(x: left + 196, y: H - 192))
_ = text("for macOS", font(30, .medium), c("#F2EEE6", 0.55), at: NSPoint(x: left + 200, y: H - 268))

_ = text("Type anywhere.", font(128, .bold), c("#F4F0E8"), kern: -4, at: NSPoint(x: left, y: H - 390))
_ = text("Keep your focus.", font(128, .bold), c("#F2AE45"), kern: -4, at: NSPoint(x: left, y: H - 535))
_ = text("A beautiful on-screen keyboard that lives in your menu bar. Click a key and it lands in the app you’re using, which never loses focus.", font(36, .regular), c("#F2EEE6", 0.68), at: NSPoint(x: left + 4, y: H - 700), lineHeight: 52, width: 900)

var chipX = left
for label in ["44 themes", "Every Mac layout", "Private & offline", "macOS 14+"] {
    let f = font(28, .semibold)
    let size = NSAttributedString(string: label, attributes: [.font: f]).size()
    let r = NSRect(x: chipX, y: H - 960, width: size.width + 52, height: 64)
    c("#FFFFFF", 0.07).setFill(); rounded(r, 32).fill()
    c("#FFFFFF", 0.12).setStroke(); let p = rounded(r.insetBy(dx: 0.75, dy: 0.75), 31.25); p.lineWidth = 1.5; p.stroke()
    _ = text(label, f, c("#F2EEE6", 0.86), at: NSPoint(x: chipX + 26, y: r.maxY - (64 - size.height) / 2))
    chipX += r.width + 16
}

let doc = NSRect(x: 1290, y: 620, width: 1000, height: 580)
shadow(60, 30, c("#000000", 0.5)) { c("#F6F3EE").setFill(); rounded(doc, 26).fill() }
c("#E9E4DC").setFill(); NSBezierPath(roundedRect: NSRect(x: doc.minX, y: doc.maxY - 64, width: doc.width, height: 64), xRadius: 26, yRadius: 26).fill()
NSRect(x: doc.minX, y: doc.maxY - 64, width: doc.width, height: 30).fill()
for (i, col) in ["#FF5F57", "#FEBC2E", "#28C840"].enumerated() {
    c(col).setFill(); NSBezierPath(ovalIn: NSRect(x: doc.minX + 28 + CGFloat(i) * 36, y: doc.maxY - 44, width: 24, height: 24)).fill()
}
_ = text("Notes", font(24, .semibold), c("#3A342C", 0.7), at: NSPoint(x: doc.midX - 34, y: doc.maxY - 18))
_ = text("Thursday standup", font(46, .bold), c("#2A251F"), at: NSPoint(x: doc.minX + 60, y: doc.maxY - 110))
_ = text("Typed with Keyli, straight into Notes.", font(34, .regular), c("#2A251F", 0.82), at: NSPoint(x: doc.minX + 60, y: doc.maxY - 190))
let lastLine = text("The cursor never left this window.", font(34, .regular), c("#2A251F", 0.82), at: NSPoint(x: doc.minX + 60, y: doc.maxY - 242))
c("#E8A33D").setFill(); rounded(NSRect(x: doc.minX + 60 + lastLine.width + 6, y: doc.maxY - 242 - lastLine.height + 2, width: 5, height: lastLine.height - 2), 2.5).fill()

let kb = NSImage(contentsOfFile: keyboardPath)!
let kbRep = kb.representations.first!
let kbW: CGFloat = 1420
let kbH = kbW * CGFloat(kbRep.pixelsHigh) / CGFloat(kbRep.pixelsWide)
kb.draw(in: NSRect(x: 1150, y: -kbH * 0.26, width: kbW, height: kbH))

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!.write(to: URL(fileURLWithPath: outPath))
print("ok")
