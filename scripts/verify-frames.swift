import AppKit

@main
enum RunnerFrameVerifier {
    @MainActor
    static func main() throws {
        let frames = RunnerFrames.cat
        precondition(frames.count == 6)
        precondition(Set(frames.map(\.pixels)).count == frames.count)

        for frame in frames {
            precondition(frame.width == RunnerFrames.width)
            precondition(frame.height == RunnerFrames.height)
            precondition(!frame.pixels.isEmpty)
        }

        precondition(RunnerTimeline.frameDurationNanoseconds == 120_000_000)
        precondition(RunnerTimeline.frameIndex(elapsed: 0.72, frameCount: 6) == 0)

        let images = RunnerSpriteRenderer.images(for: frames)
        precondition(images.allSatisfy(\.isTemplate))

        let prostrationFrames = ProstrationFrames.all
        precondition(prostrationFrames.count == 8)
        precondition(Set(prostrationFrames.map(\.pixels)).count == 8)
        let prostrationImages = RunnerSpriteRenderer.images(
            for: prostrationFrames,
            logicalPixelSize: ProstrationFrames.logicalPixelSize
        )
        precondition(prostrationImages.allSatisfy(\.isTemplate))
        precondition(prostrationImages.allSatisfy {
            $0.size == NSSize(width: 22, height: 18)
        })

        let mirrorTestFrame = RunnerFrame(
            width: 3,
            height: 1,
            pixels: [Pixel(x: 0, y: 0)]
        )
        let mirrorTestImage = RunnerSpriteRenderer.image(
            for: mirrorTestFrame,
            logicalPixelSize: 1,
            backingScale: 1
        )
        let mirroredTestImage = RunnerSpriteRenderer.horizontallyFlipped(
            mirrorTestImage
        )
        let originalBitmap = mirrorTestImage.representations
            .compactMap { $0 as? NSBitmapImageRep }
            .first!
        let mirroredBitmap = mirroredTestImage.representations
            .compactMap { $0 as? NSBitmapImageRep }
            .first!
        precondition(originalBitmap.colorAt(x: 0, y: 0)!.alphaComponent > 0.9)
        precondition(originalBitmap.colorAt(x: 2, y: 0)!.alphaComponent < 0.1)
        precondition(mirroredBitmap.colorAt(x: 0, y: 0)!.alphaComponent < 0.1)
        precondition(mirroredBitmap.colorAt(x: 2, y: 0)!.alphaComponent > 0.9)

        let configurations = [
            RunnerConfiguration(
                runner: .prostration,
                isMirrored: false,
                isRunning: true
            ),
            RunnerConfiguration(
                runner: .pixelCat,
                isMirrored: true,
                isRunning: false
            ),
        ]
        let encodedConfigurations = try JSONEncoder().encode(configurations)
        let decodedConfigurations = try JSONDecoder().decode(
            [RunnerConfiguration].self,
            from: encodedConfigurations
        )
        precondition(decodedConfigurations == configurations)
        precondition(decodedConfigurations[0].id != decodedConfigurations[1].id)

        let outputPath = CommandLine.arguments.dropFirst().first
            ?? ".build/runner-frames.png"
        let prostrationOutputPath = CommandLine.arguments.dropFirst(2).first
            ?? ".build/prostration-frames.png"
        let mirroredOutputPath = CommandLine.arguments.dropFirst(3).first
            ?? ".build/prostration-frames-mirrored.png"
        try writePreview(images: images, outputPath: outputPath)
        try writePreview(images: prostrationImages, outputPath: prostrationOutputPath)
        try writePreview(
            images: RunnerSpriteRenderer.horizontallyFlipped(prostrationImages),
            outputPath: mirroredOutputPath
        )

        print("Verified 6 fixed-speed pixel cat frames: \(outputPath)")
        print("Verified 8 original prostration frames: \(prostrationOutputPath)")
        print("Verified bitmap mirroring: \(mirroredOutputPath)")
    }

    @MainActor
    private static func writePreview(
        images: [NSImage],
        outputPath: String
    ) throws {
        let scale: CGFloat = 4
        let gap: CGFloat = 3
        let frameWidth = images.map(\.size.width).max()! * scale
        let frameHeight = images.map(\.size.height).max()! * scale
        let sheetSize = NSSize(
            width: frameWidth * CGFloat(images.count)
                + gap * CGFloat(images.count - 1),
            height: frameHeight
        )
        let sheet = NSImage(size: sheetSize)

        sheet.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: sheetSize).fill()

        for (index, image) in images.enumerated() {
            image.draw(
                in: NSRect(
                    x: CGFloat(index) * (frameWidth + gap),
                    y: 0,
                    width: frameWidth,
                    height: frameHeight
                ),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none]
            )
        }
        sheet.unlockFocus()

        guard
            let tiff = sheet.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw VerificationError.couldNotEncodePreview
        }

        try png.write(
            to: URL(fileURLWithPath: outputPath),
            options: .atomic
        )
    }
}

private enum VerificationError: Error {
    case couldNotEncodePreview
}
