@testable import RunnerCore
import XCTest

final class RunnerTimelineTests: XCTestCase {
    func testTimelineUsesFixedFrameDuration() {
        XCTAssertEqual(RunnerTimeline.frameDuration, 0.12)
        XCTAssertEqual(RunnerTimeline.frameDurationNanoseconds, 120_000_000)
    }

    func testTimelineAdvancesAndWrapsAtFixedIntervals() {
        XCTAssertEqual(RunnerTimeline.frameIndex(elapsed: 0, frameCount: 6), 0)
        XCTAssertEqual(RunnerTimeline.frameIndex(elapsed: 0.119, frameCount: 6), 0)
        XCTAssertEqual(RunnerTimeline.frameIndex(elapsed: 0.12, frameCount: 6), 1)
        XCTAssertEqual(RunnerTimeline.frameIndex(elapsed: 0.6, frameCount: 6), 5)
        XCTAssertEqual(RunnerTimeline.frameIndex(elapsed: 0.72, frameCount: 6), 0)
    }

    func testTimelineHandlesAnEmptySequence() {
        XCTAssertEqual(RunnerTimeline.frameIndex(elapsed: 10, frameCount: 0), 0)
    }
}
