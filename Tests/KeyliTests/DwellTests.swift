import Testing
import Foundation
@testable import Keyli

@Suite("Hover to Type")
struct DwellTests {
    @Test func firesOnceAfterDuration() {
        var tracker = DwellTracker()
        tracker.hover("k_0", at: 10)
        #expect(tracker.tick(at: 10.5, duration: 1) == nil)
        #expect(abs(tracker.progress(at: 10.5, duration: 1) - 0.5) < 0.001)
        #expect(tracker.tick(at: 11.0, duration: 1) == "k_0")
        #expect(tracker.tick(at: 12.5, duration: 1) == nil)
        #expect(tracker.progress(at: 12.5, duration: 1) == 0)
    }

    @Test func movingRestartsAndReturningCanFireAgain() {
        var tracker = DwellTracker()
        tracker.hover("k_0", at: 0)
        _ = tracker.tick(at: 1, duration: 1)
        tracker.hover("k_1", at: 1.2)
        #expect(tracker.tick(at: 1.9, duration: 1) == nil)
        #expect(tracker.tick(at: 2.2, duration: 1) == "k_1")
        tracker.hover("k_0", at: 3)
        #expect(tracker.tick(at: 4, duration: 1) == "k_0")
    }

    @Test func leavingCancels() {
        var tracker = DwellTracker()
        tracker.hover("k_0", at: 0)
        tracker.hover(nil, at: 0.5)
        #expect(tracker.tick(at: 5, duration: 1) == nil)
        #expect(KeyliConfig().dwellEnabled == false)
        #expect(KeyliConfig().dwellDuration == 1.0)
    }
}
