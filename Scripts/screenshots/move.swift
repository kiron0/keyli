import CoreGraphics
let a = CommandLine.arguments.dropFirst().map { Double($0)! }
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: a[0], y: a[1]), mouseButton: .left)!.post(tap: .cghidEventTap)
