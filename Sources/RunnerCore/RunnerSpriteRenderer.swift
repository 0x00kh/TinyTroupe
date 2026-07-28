import AppKit

@MainActor
public enum RunnerSpriteRenderer {
    public static func images(
        for frames: [RunnerFrame],
        logicalPixelSize: CGFloat = 1.5,
        backingScale: Int = 2
    ) -> [NSImage] {
        precondition(logicalPixelSize > 0 && backingScale > 0)
        return frames.map {
            image(
                for: $0,
                logicalPixelSize: logicalPixelSize,
                backingScale: backingScale
            )
        }
    }

    public static func image(
        for frame: RunnerFrame,
        logicalPixelSize: CGFloat = 1.5,
        backingScale: Int = 2
    ) -> NSImage {
        precondition(logicalPixelSize > 0 && backingScale > 0)

        let pointSize = NSSize(
            width: CGFloat(frame.width) * logicalPixelSize,
            height: CGFloat(frame.height) * logicalPixelSize
        )
        let pixelsPerLogicalPixel = Int(
            (logicalPixelSize * CGFloat(backingScale)).rounded()
        )
        precondition(pixelsPerLogicalPixel > 0)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: frame.width * pixelsPerLogicalPixel,
            pixelsHigh: frame.height * pixelsPerLogicalPixel,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            preconditionFailure("Unable to allocate runner frame bitmap")
        }

        representation.size = pointSize

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: representation)
        context?.imageInterpolation = .none
        context?.shouldAntialias = false
        NSGraphicsContext.current = context

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: pointSize).fill()
        NSColor.black.setFill()

        for pixel in frame.pixels {
            NSRect(
                x: CGFloat(pixel.x) * logicalPixelSize,
                y: CGFloat(frame.height - pixel.y - 1) * logicalPixelSize,
                width: logicalPixelSize,
                height: logicalPixelSize
            ).fill()
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: pointSize)
        image.addRepresentation(representation)
        image.isTemplate = true
        return image
    }

    public static func horizontallyFlipped(_ images: [NSImage]) -> [NSImage] {
        images.map { image in
            horizontallyFlipped(image)
        }
    }

    public static func horizontallyFlipped(_ image: NSImage) -> NSImage {
        let pixelsWide = image.representations.map(\.pixelsWide).max()
            ?? max(Int(image.size.width.rounded()), 1)
        let pixelsHigh = image.representations.map(\.pixelsHigh).max()
            ?? max(Int(image.size.height.rounded()), 1)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            preconditionFailure("Unable to allocate mirrored runner bitmap")
        }

        representation.size = image.size

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: representation)
        context?.imageInterpolation = .none
        context?.shouldAntialias = false
        NSGraphicsContext.current = context

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        context?.cgContext.translateBy(x: image.size.width, y: 0)
        context?.cgContext.scaleBy(x: -1, y: 1)
        image.draw(
            in: NSRect(origin: .zero, size: image.size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.none]
        )

        NSGraphicsContext.restoreGraphicsState()

        let flipped = NSImage(size: image.size)
        flipped.addRepresentation(representation)
        flipped.isTemplate = image.isTemplate
        return flipped
    }
}
