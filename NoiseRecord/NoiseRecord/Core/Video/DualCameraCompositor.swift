import CoreGraphics
import CoreVideo
import UIKit

enum DualCameraCompositor {
    private static let pipWidthRatio: CGFloat = 0.28
    private static let pipMarginRatio: CGFloat = 0.04
    private static let pipCornerRadiusRatio: CGFloat = 0.02

    /// Composites a mirrored front-camera PiP into the top-left of the back-camera frame.
    static func composite(back: CVPixelBuffer, front: CVPixelBuffer, into output: CVPixelBuffer) {
        let signpost = PerformanceSignpost.begin(.dualCameraComposite)
        defer { PerformanceSignpost.end(.dualCameraComposite, signpost) }

        copyPixelBuffer(from: back, to: output)

        guard let frontImage = cgImage(from: front, mirrored: true) else { return }

        CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []) }

        let width = CVPixelBufferGetWidth(output)
        let height = CVPixelBufferGetHeight(output)
        guard let baseAddress = CVPixelBufferGetBaseAddress(output) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(output)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let margin = CGFloat(width) * pipMarginRatio
        let pipWidth = CGFloat(width) * pipWidthRatio
        let pipHeight = pipWidth * CGFloat(frontImage.height) / CGFloat(frontImage.width)
        let pipRect = CGRect(x: margin, y: margin, width: pipWidth, height: pipHeight)
        let cornerRadius = CGFloat(width) * pipCornerRadiusRatio

        context.addPath(UIBezierPath(roundedRect: pipRect, cornerRadius: cornerRadius).cgPath)
        context.clip()
        context.draw(frontImage, in: pipRect)
        context.restoreGState()

        // Subtle border around PiP
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
        context.setLineWidth(max(2, CGFloat(width) * 0.003))
        context.addPath(UIBezierPath(roundedRect: pipRect, cornerRadius: cornerRadius).cgPath)
        context.strokePath()
        context.restoreGState()
    }

    private static func copyPixelBuffer(from source: CVPixelBuffer, to destination: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(destination, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }

        let rowCount = CVPixelBufferGetHeight(source)
        let copyBytes = min(
            CVPixelBufferGetBytesPerRow(source),
            CVPixelBufferGetBytesPerRow(destination)
        )
        guard let src = CVPixelBufferGetBaseAddress(source),
              let dst = CVPixelBufferGetBaseAddress(destination) else { return }

        for row in 0..<rowCount {
            memcpy(
                dst.advanced(by: row * CVPixelBufferGetBytesPerRow(destination)),
                src.advanced(by: row * CVPixelBufferGetBytesPerRow(source)),
                copyBytes
            )
        }
    }

    private static func cgImage(from pixelBuffer: CVPixelBuffer, mirrored: Bool) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), var image = context.makeImage() else { return nil }

        if mirrored {
            let flipContext = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
            flipContext?.translateBy(x: CGFloat(width), y: 0)
            flipContext?.scaleBy(x: -1, y: 1)
            flipContext?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            if let flipped = flipContext?.makeImage() {
                image = flipped
            }
        }
        return image
    }
}
