import AppKit
@testable import RunnerCore
import XCTest

final class RunnerFramesTests: XCTestCase {
    func testCatAnimationHasSixDistinctFrames() {
        XCTAssertEqual(RunnerFrames.cat.count, 6)
        XCTAssertEqual(Set(RunnerFrames.cat.map(\.pixels)).count, 6)
    }

    func testProstrationAnimationHasEightDistinctFrames() {
        XCTAssertEqual(ProstrationFrames.all.count, 8)
        XCTAssertEqual(Set(ProstrationFrames.all.map(\.pixels)).count, 8)
    }

    func testProstrationMovesFromKneelingToForeheadDown() throws {
        let kneeling = try XCTUnwrap(pixelBounds(of: ProstrationFrames.all[0]))
        let foreheadDown = try XCTUnwrap(pixelBounds(of: ProstrationFrames.all[4]))

        XCTAssertGreaterThan(kneeling.height, foreheadDown.height)
        XCTAssertLessThan(kneeling.width, foreheadDown.width)
        XCTAssertLessThan(kneeling.minY, foreheadDown.minY)
        XCTAssertEqual(foreheadDown.maxY, ProstrationFrames.height - 2)
    }

    func testRunnerKindsIncludePixelCatAndProstration() {
        XCTAssertEqual(RunnerKind.allCases, [.pixelCat, .prostration])
        XCTAssertEqual(RunnerKind.pixelCat.displayName, "像素猫")
        XCTAssertEqual(RunnerKind.prostration.displayName, "日式跪拜")
        XCTAssertEqual(RunnerKind.prostration.rawValue, "bowing")
    }

    func testMultipleRunnerConfigurationsRoundTripThroughJSON() throws {
        let configurations = [
            RunnerConfiguration(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                runner: .prostration,
                isMirrored: false,
                isRunning: true
            ),
            RunnerConfiguration(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                runner: .pixelCat,
                isMirrored: true,
                isRunning: false
            ),
        ]

        let data = try JSONEncoder().encode(configurations)
        let decoded = try JSONDecoder().decode(
            [RunnerConfiguration].self,
            from: data
        )

        XCTAssertEqual(decoded, configurations)
        XCTAssertNotEqual(decoded[0].id, decoded[1].id)
    }

    @MainActor
    func testHorizontalFlipMovesOpaquePixelsToTheOppositeEdge() throws {
        let frame = RunnerFrame(
            width: 3,
            height: 1,
            pixels: [Pixel(x: 0, y: 0)]
        )
        let image = RunnerSpriteRenderer.image(
            for: frame,
            logicalPixelSize: 1,
            backingScale: 1
        )
        let mirrored = RunnerSpriteRenderer.horizontallyFlipped(image)

        let originalBitmap = try XCTUnwrap(
            image.representations.compactMap { $0 as? NSBitmapImageRep }.first
        )
        let mirroredBitmap = try XCTUnwrap(
            mirrored.representations.compactMap { $0 as? NSBitmapImageRep }.first
        )

        XCTAssertEqual(mirrored.size, image.size)
        XCTAssertTrue(mirrored.isTemplate)
        XCTAssertGreaterThan(try XCTUnwrap(originalBitmap.colorAt(x: 0, y: 0)).alphaComponent, 0.9)
        XCTAssertLessThan(try XCTUnwrap(originalBitmap.colorAt(x: 2, y: 0)).alphaComponent, 0.1)
        XCTAssertLessThan(try XCTUnwrap(mirroredBitmap.colorAt(x: 0, y: 0)).alphaComponent, 0.1)
        XCTAssertGreaterThan(try XCTUnwrap(mirroredBitmap.colorAt(x: 2, y: 0)).alphaComponent, 0.9)
    }

    func testEveryPixelStaysInsideFrameBounds() {
        for frame in RunnerFrames.cat {
            XCTAssertEqual(frame.width, RunnerFrames.width)
            XCTAssertEqual(frame.height, RunnerFrames.height)
            XCTAssertFalse(frame.pixels.isEmpty)

            for pixel in frame.pixels {
                XCTAssertGreaterThanOrEqual(pixel.x, 0)
                XCTAssertLessThan(pixel.x, frame.width)
                XCTAssertGreaterThanOrEqual(pixel.y, 0)
                XCTAssertLessThan(pixel.y, frame.height)
            }
        }
    }

    func testEveryProstrationPixelStaysInsideFrameBounds() {
        for frame in ProstrationFrames.all {
            XCTAssertEqual(frame.width, ProstrationFrames.width)
            XCTAssertEqual(frame.height, ProstrationFrames.height)
            XCTAssertFalse(frame.pixels.isEmpty)

            for pixel in frame.pixels {
                XCTAssertGreaterThanOrEqual(pixel.x, 0)
                XCTAssertLessThan(pixel.x, frame.width)
                XCTAssertGreaterThanOrEqual(pixel.y, 0)
                XCTAssertLessThan(pixel.y, frame.height)
            }
        }
    }

    @MainActor
    func testRenderedProstrationFramesMatchTheMenuBarHeight() {
        let images = RunnerSpriteRenderer.images(
            for: ProstrationFrames.all,
            logicalPixelSize: ProstrationFrames.logicalPixelSize
        )

        XCTAssertEqual(images.count, 8)
        XCTAssertTrue(images.allSatisfy(\.isTemplate))
        XCTAssertTrue(images.allSatisfy {
            $0.size == NSSize(
                width: 22,
                height: 18
            )
        })
        XCTAssertTrue(images.allSatisfy { image in
            image.representations.contains { representation in
                representation.pixelsWide == ProstrationFrames.width
                    && representation.pixelsHigh == ProstrationFrames.height
            }
        })
    }

    @MainActor
    func testRenderedFramesAreTemplateImagesWithRetinaRepresentations() {
        let images = RunnerSpriteRenderer.images(
            for: RunnerFrames.cat,
            logicalPixelSize: 1.5,
            backingScale: 2
        )

        XCTAssertEqual(images.count, RunnerFrames.cat.count)

        for image in images {
            XCTAssertTrue(image.isTemplate)
            XCTAssertEqual(image.size.width, CGFloat(RunnerFrames.width) * 1.5)
            XCTAssertEqual(image.size.height, CGFloat(RunnerFrames.height) * 1.5)

            let bitmap = image.representations.compactMap {
                $0 as? NSBitmapImageRep
            }.first
            XCTAssertEqual(bitmap?.pixelsWide, RunnerFrames.width * 3)
            XCTAssertEqual(bitmap?.pixelsHigh, RunnerFrames.height * 3)
            XCTAssertNotNil(bitmap?.representation(using: .png, properties: [:]))
        }
    }

    private func pixelBounds(of frame: RunnerFrame) -> (
        width: Int,
        height: Int,
        minY: Int,
        maxY: Int
    )? {
        guard let minX = frame.pixels.map(\.x).min(),
              let maxX = frame.pixels.map(\.x).max(),
              let minY = frame.pixels.map(\.y).min(),
              let maxY = frame.pixels.map(\.y).max()
        else {
            return nil
        }

        return (
            width: maxX - minX + 1,
            height: maxY - minY + 1,
            minY: minY,
            maxY: maxY
        )
    }
}
