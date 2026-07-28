import Foundation

public struct Pixel: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct RunnerFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: Set<Pixel>

    public init(width: Int, height: Int, pixels: Set<Pixel>) {
        precondition(width > 0 && height > 0)
        precondition(pixels.allSatisfy { pixel in
            pixel.x >= 0 && pixel.x < width && pixel.y >= 0 && pixel.y < height
        })

        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

public enum RunnerFrames {
    public static let width = 22
    public static let height = 12

    public static let cat: [RunnerFrame] = [
        makeFrame(
            tail: pixels((1, 4), (2, 3), (3, 3), (4, 4), (5, 5)),
            legs: pixels((7, 8), (6, 9), (5, 10), (4, 10),
                         (16, 8), (17, 9), (18, 9), (19, 10), (20, 10))
        ),
        makeFrame(
            tail: pixels((1, 3), (2, 2), (3, 3), (4, 4), (5, 5)),
            legs: pixels((7, 8), (6, 9), (6, 10), (5, 10),
                         (16, 8), (17, 9), (18, 10), (19, 10))
        ),
        makeFrame(
            tail: pixels((1, 2), (2, 2), (3, 3), (4, 4), (5, 5)),
            legs: pixels((7, 8), (8, 9), (9, 9),
                         (15, 8), (14, 9), (13, 9))
        ),
        makeFrame(
            tail: pixels((1, 3), (2, 3), (3, 4), (4, 5), (5, 5)),
            legs: pixels((7, 8), (9, 9), (10, 9), (11, 10), (12, 10),
                         (15, 8), (14, 9), (14, 10), (13, 10))
        ),
        makeFrame(
            tail: pixels((1, 4), (2, 4), (3, 5), (4, 5), (5, 5)),
            legs: pixels((7, 8), (8, 9), (8, 10), (7, 10),
                         (16, 8), (17, 9), (17, 10), (18, 10))
        ),
        makeFrame(
            tail: pixels((1, 5), (2, 5), (3, 5), (4, 5), (5, 5)),
            legs: pixels((7, 8), (6, 9), (5, 9),
                         (15, 8), (16, 9), (17, 9))
        ),
    ]

    private static let body: Set<Pixel> = {
        var result = Set<Pixel>()
        result.formUnion(pixels((16, 1), (19, 1)))
        result.formUnion(pixels((15, 2), (16, 2), (18, 2), (19, 2)))
        result.formUnion(row(y: 3, x: 9...19))
        result.formUnion(row(y: 4, x: 7...20))
        result.remove(Pixel(x: 18, y: 4))
        result.formUnion(row(y: 5, x: 6...20))
        result.formUnion(row(y: 6, x: 5...19))
        result.formUnion(row(y: 7, x: 6...17))
        result.formUnion(pixels((8, 8), (9, 8), (15, 8), (16, 8)))
        return result
    }()

    private static func makeFrame(
        tail: Set<Pixel>,
        legs: Set<Pixel>
    ) -> RunnerFrame {
        RunnerFrame(
            width: width,
            height: height,
            pixels: body.union(tail).union(legs)
        )
    }

    private static func row(y: Int, x range: ClosedRange<Int>) -> Set<Pixel> {
        Set(range.map { Pixel(x: $0, y: y) })
    }

    private static func pixels(_ coordinates: (Int, Int)...) -> Set<Pixel> {
        Set(coordinates.map { Pixel(x: $0.0, y: $0.1) })
    }
}
