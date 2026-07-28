import Foundation

public enum RunnerTimeline {
    public static let frameDuration: TimeInterval = 0.12
    public static let frameDurationNanoseconds: UInt64 = 120_000_000

    public static func frameIndex(
        elapsed: TimeInterval,
        frameCount: Int
    ) -> Int {
        guard frameCount > 0, elapsed > 0 else {
            return 0
        }

        let elapsedNanoseconds = UInt64(
            (elapsed * 1_000_000_000).rounded()
        )
        return Int(elapsedNanoseconds / frameDurationNanoseconds) % frameCount
    }
}
