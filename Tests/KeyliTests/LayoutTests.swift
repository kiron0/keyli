import Testing
import Foundation
@testable import Keyli

@Suite("Keyboard Layout Tests", .serialized)
struct LayoutTests {
    @Test("ANSI Layout Generation")
    func testAnsiLayoutGeneration() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        #expect(layout.geometryType == .ansi)
        #expect(!layout.keys.isEmpty)

        let keyCodes = Set(layout.keys.map { $0.keyCode })
        #expect(keyCodes.contains(0)) // 'a'
        #expect(keyCodes.contains(12)) // 'q'
        #expect(keyCodes.contains(49)) // Space
        #expect(keyCodes.contains(36)) // Return
        #expect(keyCodes.contains(51)) // Delete
    }

    @Test("Test Every Key in ANSI Layout")
    func testEveryKeyInAnsiLayout() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        #expect(layout.keys.count >= 70)

        for key in layout.keys {
            // Frame validation
            #expect(key.unitFrame.x >= 0.0)
            #expect(key.unitFrame.y >= 0.0)
            #expect(key.unitFrame.width > 0.0)
            #expect(key.unitFrame.height > 0.0)

            // Labels validation
            #expect(!key.labels.defaultLabel.isEmpty || key.symbolIcon != nil)

            // Displayed label resolution
            let normalLabel = key.displayedLabel(shift: false, option: false, capsLock: false)
            #expect(!normalLabel.isEmpty)

            let shiftLabel = key.displayedLabel(shift: true, option: false, capsLock: false)
            #expect(!shiftLabel.isEmpty)

            let optLabel = key.displayedLabel(shift: false, option: true, capsLock: false)
            #expect(!optLabel.isEmpty)
        }
    }

    @Test("ISO Layout Generation")
    func testIsoLayoutGeneration() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .iso)
        #expect(layout.geometryType == .iso)
        let keyCodes = Set(layout.keys.map { $0.keyCode })
        #expect(keyCodes.contains(10)) // Extra ISO key
    }

    @Test("JIS Layout Generation")
    func testJisLayoutGeneration() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .jis)
        #expect(layout.geometryType == .jis)
        let keyCodes = Set(layout.keys.map { $0.keyCode })
        #expect(keyCodes.contains(102)) // Eisu
        #expect(keyCodes.contains(104)) // Kana
    }

    @Test("Compact Layout Generation")
    func testCompactLayoutGeneration() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .compact)
        #expect(layout.geometryType == .compact)
        #expect(layout.unitHeight < 6.0)
    }

    @Test("Every Geometry Stays Inside Its Unit Grid Without Overlaps")
    func testKeysFitGridWithoutOverlap() {
        for geometry in GeometryType.allCases {
            let layout = KeyboardLayoutManager.shared.generateLayout(geometry: geometry)
            let epsilon = 0.0001

            for key in layout.keys {
                #expect(key.unitFrame.x + key.unitFrame.width <= layout.unitWidth + epsilon)
                #expect(key.unitFrame.y + key.unitFrame.height <= layout.unitHeight + epsilon)
            }

            for (index, a) in layout.keys.enumerated() {
                for b in layout.keys[(index + 1)...] {
                    let overlapX = min(a.unitFrame.x + a.unitFrame.width, b.unitFrame.x + b.unitFrame.width) - max(a.unitFrame.x, b.unitFrame.x)
                    let overlapY = min(a.unitFrame.y + a.unitFrame.height, b.unitFrame.y + b.unitFrame.height) - max(a.unitFrame.y, b.unitFrame.y)
                    #expect(!(overlapX > epsilon && overlapY > epsilon), "\(geometry.rawValue): \(a.id) overlaps \(b.id)")
                }
            }
        }
    }

    @Test("Top Row Spans The Full Keyboard Width")
    func testTopRowSpansFullWidth() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        let topRow = layout.keys.filter { $0.unitFrame.y == 0 }
        let minX = topRow.map { $0.unitFrame.x }.min() ?? 1
        let maxX = topRow.map { $0.unitFrame.x + $0.unitFrame.width }.max() ?? 0
        #expect(topRow.count == 14)
        #expect(minX == 0)
        #expect(abs(maxX - layout.unitWidth) < 0.0001)
    }

    @Test("Panel Size Keeps Keys Square At Any Width")
    func testPanelSizeKeepsKeyboardAspect() {
        for geometry in GeometryType.allCases {
            let layout = KeyboardLayoutManager.shared.generateLayout(geometry: geometry)
            for width in [620.0, 820.0, 1200.0] {
                let height = KeyliConstants.panelHeight(forWidth: width, layout: layout)
                let unitW = (width - KeyliConstants.keyboardHorizontalPadding) / layout.unitWidth
                let unitH = (height - KeyliConstants.keyboardChromeHeight) / layout.unitHeight
                #expect(abs(unitW - unitH) < 0.2)
                #expect(abs(KeyliConstants.panelWidth(forHeight: height, layout: layout) - width) <= 2)
            }
        }
    }

    @Test("Key IDs Are Unique")
    func testKeyIdsAreUnique() {
        let layout = KeyboardLayoutManager.shared.generateLayout(geometry: .ansi)
        let ids = layout.keys.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
}
