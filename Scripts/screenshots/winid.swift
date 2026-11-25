import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
var best: (Int, Double)?
for w in list where (w[kCGWindowOwnerName as String] as? String) == CommandLine.arguments[1] {
    let b = w[kCGWindowBounds as String] as! [String: Double]
    let area = b["Width"]! * b["Height"]!
    if best == nil || area > best!.1 { best = (w[kCGWindowNumber as String] as! Int, area) }
}
if let best { print(best.0) }
