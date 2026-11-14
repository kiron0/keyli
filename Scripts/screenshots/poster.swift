import AppKit
import CoreText

let args = CommandLine.arguments
let variant = args[1], outPath = args[2], fontsDir = args[3], iconPath = args[4]
let W: CGFloat = 1680, H: CGFloat = 1050

for name in ["unbounded-latin-wght-normal", "onest-latin-wght-normal", "jetbrains-mono-latin-wght-normal"] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "\(fontsDir)/\(name).woff2") as CFURL, .process, nil)
}
func font(_ name: String, _ size: CGFloat) -> NSFont { NSFont(name: name, size: size) ?? .systemFont(ofSize: size) }
func c(_ hex: String, _ a: CGFloat = 1) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: String(hex.dropFirst())).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
@discardableResult
func text(_ s: String, _ f: NSFont, _ color: NSColor, x: CGFloat, top: CGFloat, kern: CGFloat = 0, width: CGFloat? = nil, lineHeight: CGFloat? = nil) -> NSSize {
    let para = NSMutableParagraphStyle()
    if let lh = lineHeight { para.minimumLineHeight = lh; para.maximumLineHeight = lh }
    let attr = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color, .kern: kern, .paragraphStyle: para])
    let size = width.map { attr.boundingRect(with: NSSize(width: $0, height: 2000), options: [.usesLineFragmentOrigin]).size } ?? attr.size()
    attr.draw(with: NSRect(x: x, y: H - top - size.height, width: width ?? size.width + 4, height: size.height), options: [.usesLineFragmentOrigin])
    return size
}
func blob(_ x: CGFloat, _ yTop: CGFloat, _ r: CGFloat, _ color: NSColor) {
    NSGradient(colors: [color, color.withAlphaComponent(0)])!.draw(fromCenter: NSPoint(x: x, y: H - yTop), radius: 0, toCenter: NSPoint(x: x, y: H - yTop), radius: r, options: [])
}
func rounded(_ r: NSRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) }

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * 2), pixelsHigh: Int(H * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(colors: [c("#2A1E17"), c("#1A1513"), c("#121012")], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -60)
blob(1380, 180, 700, c("#E8A33D", 0.55))
blob(1580, 620, 520, c("#C4502A", 0.55))
blob(980, 980, 620, c("#7A2E2A", 0.45))
blob(260, 120, 560, c("#F1D6A8", 0.22))
blob(540, 560, 480, c("#E8A33D", 0.16))
blob(80, 900, 420, c("#3B2F45", 0.55))

var seed: UInt64 = 11
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 10000) / 10000 }
for _ in 0..<60000 {
    c(rnd() > 0.5 ? "#FFFFFF" : "#000000", 0.04).setFill()
    NSRect(x: rnd() * W, y: rnd() * H, width: 0.8, height: 0.8).fill()
}

let ink = c("#F6F1E8")
let amber = c("#F2AE45")
let left: CGFloat = 96

func kicker(_ number: String, _ label: String, top: CGFloat) {
    let f = font("JetBrainsMonoRoman-Bold", 15)
    let numSize = NSAttributedString(string: number, attributes: [.font: f]).size()
    let chip = NSRect(x: left, y: H - top - 30, width: numSize.width + 22, height: 30)
    amber.setFill(); rounded(chip, 7).fill()
    text(number, f, c("#1F1A12"), x: left + 11, top: top + 6)
    text(label, font("JetBrainsMonoRoman-Medium", 16), amber, x: chip.maxX + 14, top: top + 5, kern: 2.4)
}

func headline(_ s: String, top: CGFloat, size: CGFloat = 54, color: NSColor = ink, width: CGFloat? = nil) {
    text(s, font("Unbounded-Regular_Bold", size), color, x: left, top: top, kern: -1.2, width: width, lineHeight: size * 1.16)
}

func body(_ s: String, top: CGFloat, width: CGFloat) {
    text(s, font("Onest-Regular", 21), ink.withAlphaComponent(0.74), x: left + 2, top: top, width: width, lineHeight: 31)
}

switch variant {
case "hero":
    if let icon = NSImage(contentsOfFile: iconPath) {
        icon.draw(in: NSRect(x: left - 14, y: H - 96 - 118, width: 118, height: 118))
    }
    text("Keyli", font("Unbounded-Regular_SemiBold", 34), ink, x: left + 118, top: 120, kern: -0.6)
    text("for macOS", font("Onest-Medium", 18), ink.withAlphaComponent(0.6), x: left + 120, top: 166)
    headline("Type anywhere.", top: 262, size: 66)
    headline("Keep your focus.", top: 340, size: 66, color: amber)
    body("An on-screen keyboard that lives in your menu bar. Click a key and it lands in the app you’re using, which never loses focus.", top: 444, width: 600)
    var chipX = left
    for label in ["52 themes", "Every Mac layout", "Private & offline", "macOS 14+"] {
        let f = font("Onest-SemiBold", 17)
        let sz = NSAttributedString(string: label, attributes: [.font: f]).size()
        let r = NSRect(x: chipX, y: H - 590 - 40, width: sz.width + 32, height: 40)
        c("#FFFFFF", 0.09).setFill(); rounded(r, 20).fill()
        c("#FFFFFF", 0.16).setStroke(); let p = rounded(r.insetBy(dx: 0.5, dy: 0.5), 19.5); p.lineWidth = 1; p.stroke()
        text(label, f, ink.withAlphaComponent(0.9), x: chipX + 16, top: 590 + (40 - sz.height) / 2)
        chipX += r.width + 10
    }
    let doc = NSRect(x: 860, y: H - 90 - 330, width: 700, height: 330)
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowBlurRadius = 40; sh.shadowOffset = NSSize(width: 0, height: -18); sh.shadowColor = c("#000000", 0.45); sh.set()
    c("#F7F4EF").setFill(); rounded(doc, 16).fill()
    NSGraphicsContext.restoreGraphicsState()
    for (i, col) in ["#FF5F57", "#FEBC2E", "#28C840"].enumerated() {
        c(col).setFill(); NSBezierPath(ovalIn: NSRect(x: doc.minX + 18 + CGFloat(i) * 22, y: doc.maxY - 26, width: 13, height: 13)).fill()
    }
    text("Untitled", font("Onest-SemiBold", 15), c("#3A342C", 0.6), x: doc.midX - 26, top: 90 + 12)
    text("Thursday standup", font("Onest-Bold", 30), c("#231F1A"), x: doc.minX + 40, top: 90 + 66)
    text("Typed with Keyli, straight into TextEdit.", font("Onest-Regular", 21), c("#231F1A", 0.82), x: doc.minX + 40, top: 90 + 122)
    let last = text("The cursor never left this window.", font("Onest-Regular", 21), c("#231F1A", 0.82), x: doc.minX + 40, top: 90 + 154)
    c("#E8A33D").setFill(); rounded(NSRect(x: doc.minX + 40 + last.width + 5, y: H - 90 - 154 - last.height + 1, width: 3, height: last.height - 2), 1.5).fill()
case "themes":
    kicker("01", "THEMES", top: 822)
    headline("52 looks. One click.", top: 866)
case "studio":
    kicker("02", "THEME STUDIO", top: 822)
    headline("Make every key yours.", top: 866)
case "keyboard":
    kicker("04", "FLOATING KEYBOARD", top: 822)
    headline("Floats above your work.", top: 866)
case "settings":
    kicker("03", "SETTINGS", top: 822)
    headline("Native, calm, organized.", top: 866)
case "sounds":
    kicker("05", "KEY SOUNDS", top: 822)
    headline("Hear every key you press.", top: 866)
case "shortcuts":
    kicker("06", "SHORTCUTS", top: 822)
    headline("Every action, one keystroke.", top: 866)
default:
    break
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("ok \(variant)")
