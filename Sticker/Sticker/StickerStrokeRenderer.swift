import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum StickerStrokeStyle: String, CaseIterable, Identifiable {
    case none = "None"
    case solid = "Solid"
    case crayon = "Crayon"
    case paper = "Paper"
    case dots = "Dots"
    case plaid = "Plaid"
    case foil = "Foil"

    var id: String { rawValue }
}

enum StickerStrokeSpacing: String, CaseIterable {
    case attached = "Touching"
    case spaced = "With gap"
}

/// Expands the cutout alpha to make an outside-only outline. The inner area
/// remains the original image; in gap mode the pixels between them stay clear.
enum StickerStrokeRenderer {
    static func render(_ image: UIImage, style: StickerStrokeStyle,
                       spacing: StickerStrokeSpacing, width: Double,
                       gap: Double, color: UIColor) -> UIImage? {
        guard style != .none else { return image }
        guard let source = image.cgImage else { return nil }
        let sourceWidth = source.width
        let sourceHeight = source.height
        let shortSide = Double(min(sourceWidth, sourceHeight))
        let strokeRadius = Int(min(90, max(4, shortSide * (0.015 + 0.05 * width))).rounded())
        let gapRadius = spacing == .spaced
            ? Int(min(38, max(2, shortSide * (0.006 + 0.016 * gap))).rounded()) : 0
        let padding = strokeRadius + gapRadius + 4
        let outputWidth = sourceWidth + padding * 2
        let outputHeight = sourceHeight + padding * 2
        let sourceRowBytes = sourceWidth * 4
        let outputRowBytes = outputWidth * 4
        let rgb = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue

        var sourcePixels = [UInt8](repeating: 0, count: sourceRowBytes * sourceHeight)
        let decoded = sourcePixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress,
                                          width: sourceWidth, height: sourceHeight,
                                          bitsPerComponent: 8, bytesPerRow: sourceRowBytes,
                                          space: rgb, bitmapInfo: bitmapInfo) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0,
                                            width: sourceWidth, height: sourceHeight))
            return true
        }
        guard decoded else { return nil }

        var originalMask = [UInt8](repeating: 0, count: outputWidth * outputHeight)
        for y in 0..<sourceHeight {
            let sourceRow = y * sourceRowBytes
            let maskRow = (y + padding) * outputWidth + padding
            for x in 0..<sourceWidth {
                originalMask[maskRow + x] = sourcePixels[sourceRow + x * 4 + 3]
            }
        }

        let gray = CGColorSpaceCreateDeviceGray()
        let extent = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        let maskImage = CIImage(bitmapData: Data(originalMask), bytesPerRow: outputWidth,
                                size: extent.size, format: .L8, colorSpace: gray)
        let context = CIContext(options: [.workingColorSpace: gray])
        func dilated(_ radius: Int) -> [UInt8]? {
            if radius == 0 { return originalMask }
            let filter = CIFilter.morphologyMaximum()
            filter.inputImage = maskImage
            filter.radius = Float(radius)
            guard let image = filter.outputImage?.cropped(to: extent) else { return nil }
            var pixels = [UInt8](repeating: 0, count: outputWidth * outputHeight)
            context.render(image, toBitmap: &pixels, rowBytes: outputWidth,
                           bounds: extent, format: .L8, colorSpace: gray)
            return pixels
        }
        guard let outerMask = dilated(strokeRadius + gapRadius),
              let innerMask = dilated(gapRadius) else { return nil }

        let components = color.rgba
        // The source cutout has a soft alpha fringe. Compress that fringe to a
        // narrow antialiased edge so the outline itself reads as solid ink.
        let coverage = (0...255).map { value -> Double in
            let t = min(1, max(0, (Double(value) / 255 - 0.38) / 0.24))
            return t * t * (3 - 2 * t)
        }
        var output = [UInt8](repeating: 0, count: outputRowBytes * outputHeight)
        for y in 0..<sourceHeight {
            let sourceRow = y * sourceRowBytes
            let destinationRow = (y + padding) * outputRowBytes + padding * 4
            for byte in 0..<sourceRowBytes {
                output[destinationRow + byte] = sourcePixels[sourceRow + byte]
            }
        }
        for y in 0..<outputHeight {
            let row = y * outputRowBytes
            let maskRow = y * outputWidth
            for x in 0..<outputWidth {
                let index = row + x * 4
                let maskIndex = maskRow + x
                let ring = coverage[Int(outerMask[maskIndex])] *
                    (1 - coverage[Int(innerMask[maskIndex])])
                if ring == 0 { continue }
                let texture = sample(style: style, x: x, y: y)
                let strokeAlpha = ring * components.alpha
                let objectAlpha = Double(output[index + 3]) / 255
                let behind = strokeAlpha * (1 - objectAlpha)
                let finalAlpha = objectAlpha + behind
                if finalAlpha == 0 { continue }
                for channel in 0..<3 {
                    let object = Double(output[index + channel]) / 255
                    let stroke = texture.whiteDot ? 1 : components.channels[channel] * texture.lightness
                    output[index + channel] = UInt8(min(255, max(0,
                        (object + stroke * behind) * 255)).rounded())
                }
                output[index + 3] = UInt8(min(255, finalAlpha * 255).rounded())
            }
        }
        let rendered = output.withUnsafeMutableBytes { bytes -> CGImage? in
            guard let context = CGContext(data: bytes.baseAddress, width: outputWidth,
                                          height: outputHeight, bitsPerComponent: 8,
                                          bytesPerRow: outputRowBytes, space: rgb,
                                          bitmapInfo: bitmapInfo) else { return nil }
            return context.makeImage()
        }
        return rendered.map { UIImage(cgImage: $0, scale: image.scale, orientation: image.imageOrientation) }
    }

    private static func sample(style: StickerStrokeStyle, x: Int, y: Int)
        -> (lightness: Double, whiteDot: Bool) {
        let noise = Double((UInt64(x) &* 73_856_093 ^ UInt64(y) &* 19_349_663) % 997) / 996
        switch style {
        case .none, .solid:
            return (1, false)
        case .crayon:
            let stroke = 0.78 + 0.22 * sin(Double(x) * 0.19 + Double(y) * 0.43)
            return (0.60 + 0.30 * stroke + 0.20 * noise, false)
        case .paper:
            let fibers = 0.93 + 0.07 * sin(Double(x) * 0.7 + Double(y) * 0.06)
            return (fibers * (0.91 + 0.13 * noise), false)
        case .dots:
            let period = 18
            let dx = (x % period) - period / 2
            let dy = (y % period) - period / 2
            return (1, dx * dx + dy * dy < 20)
        case .plaid:
            let vertical = x % 17 < 3
            let horizontal = y % 19 < 3
            return (vertical || horizontal ? 0.72 : 1.08, false)
        case .foil:
            let fold = 0.82 + 0.2 * sin(Double(x) * 0.08 + Double(y) * 0.13)
            return (fold * (0.88 + 0.22 * noise), false)
        }
    }
}

private extension UIColor {
    var rgba: (channels: [Double], alpha: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let converted = getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        if !converted { return ([1, 0.68, 0.70], 1) }
        return ([Double(red), Double(green), Double(blue)], Double(alpha))
    }
}
