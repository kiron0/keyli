import Testing
import Foundation
import CoreGraphics
@testable import Keyli

@Suite("Long-press accents")
struct AccentVariantsTests {
    @Test func lowercaseLettersHaveVariants() {
        #expect(AccentVariants.variants(for: "e").contains("é"))
        #expect(AccentVariants.variants(for: "n") == ["ñ", "ń"])
    }

    @Test func uppercaseFollowsShiftAndDropsMultiCharacterForms() {
        #expect(AccentVariants.variants(for: "E").contains("É"))
        #expect(AccentVariants.variants(for: "E").allSatisfy { $0 == $0.uppercased() })
        #expect(AccentVariants.variants(for: "S") == ["Ś", "Š"])
    }

    @Test func otherInputHasNone() {
        #expect(AccentVariants.variants(for: "b").isEmpty)
        #expect(AccentVariants.variants(for: "ab").isEmpty)
        #expect(AccentVariants.variants(for: "").isEmpty)
        #expect(AccentVariants.variants(for: "5").isEmpty)
    }

    @Test func popupSitsAboveKeyAndStaysInBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
        let anchor = CGRect(x: 2, y: 100, width: 30, height: 30)
        let layout = AccentPopupLayout(count: 8, anchor: anchor, bounds: bounds)
        #expect(layout.frame.maxY <= anchor.minY)
        #expect(layout.frame.minX >= bounds.minX)
        #expect(layout.frame.maxX <= bounds.maxX)
    }

    @Test func popupFlipsBelowWhenNoRoomAbove() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
        let anchor = CGRect(x: 100, y: 5, width: 30, height: 30)
        let layout = AccentPopupLayout(count: 3, anchor: anchor, bounds: bounds)
        #expect(layout.frame.minY >= anchor.maxY)
    }

    @Test func hitTestingFindsOptions() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
        let anchor = CGRect(x: 150, y: 100, width: 30, height: 30)
        let layout = AccentPopupLayout(count: 4, anchor: anchor, bounds: bounds)
        for index in 0..<4 {
            let cell = layout.optionFrame(at: index)
            #expect(layout.index(at: CGPoint(x: cell.midX, y: cell.midY)) == index)
        }
        #expect(layout.index(at: CGPoint(x: anchor.midX, y: anchor.maxY + 20)) == nil)
    }

    @Test func enabledByDefaultAndDecodesMissingKey() throws {
        #expect(KeyliConfig().accentPopupEnabled)
        let decoded = try JSONDecoder().decode(KeyliConfig.self, from: Data("{}".utf8))
        #expect(decoded.accentPopupEnabled)
    }
}
