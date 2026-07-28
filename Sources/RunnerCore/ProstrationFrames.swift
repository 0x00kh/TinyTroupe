import Foundation

public enum ProstrationFrames {
    public static let width = 44
    public static let height = 36
    public static let logicalPixelSize: CGFloat = 0.5

    public static let all: [RunnerFrame] = poses.map(makeFrame)

    private static let poses: [Pose] = [
        Pose(
            head: Point(20, 8), face: Point(15.5, 8.5),
            shoulder: Point(22, 14), hip: Point(27, 25),
            elbow: Point(18, 20), hand: Point(15, 26),
            knee: Point(17, 30), heel: Point(29, 31), toe: Point(37, 32)
        ),
        Pose(
            head: Point(17.5, 10), face: Point(13, 11),
            shoulder: Point(21, 15), hip: Point(27.5, 25),
            elbow: Point(16, 21.5), hand: Point(11.5, 28.5),
            knee: Point(17, 30), heel: Point(29, 31), toe: Point(37, 32)
        ),
        Pose(
            head: Point(14, 14), face: Point(9.5, 15.5),
            shoulder: Point(19.5, 18), hip: Point(28, 25.5),
            elbow: Point(14, 23.5), hand: Point(8, 31),
            knee: Point(18, 30.5), heel: Point(30, 31), toe: Point(38, 32)
        ),
        Pose(
            head: Point(10.5, 20.5), face: Point(6, 23),
            shoulder: Point(17, 22), hip: Point(28.5, 26),
            elbow: Point(12, 27), hand: Point(5, 32),
            knee: Point(20, 31), heel: Point(31, 31), toe: Point(39, 32)
        ),
        Pose(
            head: Point(8, 27), face: Point(3.5, 31.5),
            shoulder: Point(16, 25), hip: Point(29, 27),
            elbow: Point(11.5, 29), hand: Point(5, 32),
            knee: Point(22, 31), heel: Point(31, 31), toe: Point(39, 32)
        ),
        Pose(
            head: Point(8.5, 27.5), face: Point(3.5, 32),
            shoulder: Point(16.5, 26), hip: Point(29, 27.5),
            elbow: Point(12, 30), hand: Point(5.5, 32.5),
            knee: Point(22.5, 31.5), heel: Point(31.5, 31.5), toe: Point(39.5, 32.5)
        ),
        Pose(
            head: Point(11.5, 19), face: Point(7, 21.5),
            shoulder: Point(18, 21), hip: Point(28.5, 26),
            elbow: Point(13, 26.5), hand: Point(6, 32),
            knee: Point(20, 31), heel: Point(31, 31), toe: Point(39, 32)
        ),
        Pose(
            head: Point(17, 10.5), face: Point(12.5, 11.5),
            shoulder: Point(21, 15), hip: Point(27.5, 25),
            elbow: Point(15.5, 22), hand: Point(11.5, 29),
            knee: Point(17.5, 30), heel: Point(29.5, 31), toe: Point(37.5, 32)
        ),
    ]

    private static func makeFrame(_ pose: Pose) -> RunnerFrame {
        var canvas = Canvas(width: width, height: height)

        canvas.fillCapsule(from: pose.shoulder, to: pose.hip, radius: 4.2)
        canvas.fillEllipse(center: pose.hip, radiusX: 5, radiusY: 4.2)

        canvas.fillCapsule(from: pose.hip, to: pose.knee, radius: 4)
        canvas.fillCapsule(from: pose.knee, to: pose.heel, radius: 3.2)
        canvas.fillCapsule(from: pose.heel, to: pose.toe, radius: 2.4)

        canvas.fillCapsule(
            from: Point(pose.shoulder.x + 1, pose.shoulder.y + 0.5),
            to: Point(pose.elbow.x + 1, pose.elbow.y + 0.5),
            radius: 1.5
        )
        canvas.fillCapsule(
            from: Point(pose.elbow.x + 1, pose.elbow.y + 0.5),
            to: Point(pose.hand.x + 1.5, pose.hand.y + 0.5),
            radius: 1.5
        )
        canvas.fillCapsule(from: pose.shoulder, to: pose.elbow, radius: 1.8)
        canvas.fillCapsule(from: pose.elbow, to: pose.hand, radius: 1.8)
        canvas.fillEllipse(center: pose.hand, radiusX: 2.8, radiusY: 1.5)

        let neck = Point(
            (pose.head.x + pose.shoulder.x) / 2,
            (pose.head.y + pose.shoulder.y) / 2
        )
        canvas.fillCapsule(from: neck, to: pose.shoulder, radius: 2.2)
        canvas.fillEllipse(center: pose.head, radiusX: 5, radiusY: 5.2)
        canvas.fillEllipse(center: pose.face, radiusX: 2.1, radiusY: 1.7)

        return RunnerFrame(width: width, height: height, pixels: canvas.pixels)
    }
}

private struct Pose {
    let head: Point
    let face: Point
    let shoulder: Point
    let hip: Point
    let elbow: Point
    let hand: Point
    let knee: Point
    let heel: Point
    let toe: Point
}

private struct Point {
    let x: Double
    let y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

private struct Canvas {
    let width: Int
    let height: Int
    var pixels = Set<Pixel>()

    mutating func fillEllipse(
        center: Point,
        radiusX: Double,
        radiusY: Double
    ) {
        fillBounds(
            minX: center.x - radiusX,
            maxX: center.x + radiusX,
            minY: center.y - radiusY,
            maxY: center.y + radiusY
        ) { point in
            let x = (point.x - center.x) / radiusX
            let y = (point.y - center.y) / radiusY
            return x * x + y * y <= 1
        }
    }

    mutating func fillCapsule(from start: Point, to end: Point, radius: Double) {
        fillBounds(
            minX: min(start.x, end.x) - radius,
            maxX: max(start.x, end.x) + radius,
            minY: min(start.y, end.y) - radius,
            maxY: max(start.y, end.y) + radius
        ) { point in
            squaredDistance(from: point, toSegmentFrom: start, to: end)
                <= radius * radius
        }
    }

    private mutating func fillBounds(
        minX: Double,
        maxX: Double,
        minY: Double,
        maxY: Double,
        contains: (Point) -> Bool
    ) {
        let xRange = clippedRange(minimum: minX, maximum: maxX, limit: width)
        let yRange = clippedRange(minimum: minY, maximum: maxY, limit: height)

        for y in yRange {
            for x in xRange where contains(Point(Double(x) + 0.5, Double(y) + 0.5)) {
                pixels.insert(Pixel(x: x, y: y))
            }
        }
    }

    private func clippedRange(
        minimum: Double,
        maximum: Double,
        limit: Int
    ) -> ClosedRange<Int> {
        let lower = max(Int(minimum.rounded(.down)), 0)
        let upper = min(Int(maximum.rounded(.up)), limit - 1)
        return lower...upper
    }
}

private func squaredDistance(
    from point: Point,
    toSegmentFrom start: Point,
    to end: Point
) -> Double {
    let segmentX = end.x - start.x
    let segmentY = end.y - start.y
    let lengthSquared = segmentX * segmentX + segmentY * segmentY

    guard lengthSquared > 0 else {
        let x = point.x - start.x
        let y = point.y - start.y
        return x * x + y * y
    }

    let projection = (
        (point.x - start.x) * segmentX
            + (point.y - start.y) * segmentY
    ) / lengthSquared
    let t = min(max(projection, 0), 1)
    let closestX = start.x + t * segmentX
    let closestY = start.y + t * segmentY
    let x = point.x - closestX
    let y = point.y - closestY
    return x * x + y * y
}
