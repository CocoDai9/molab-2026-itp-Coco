import CoreGraphics
import UIKit

enum StickerEffect: String, CaseIterable, Identifiable {
    case none = "None"
    case dots = "Halftone Dots"
    case lines = "Halftone Lines"
    case pixel = "Pixel"
    case stamp = "Stamp"
    case grain = "Grain"
    case rgbShift = "RGB Shift"

    var id: String { rawValue }
    var hasSize: Bool { self == .dots || self == .lines || self == .pixel }
}

enum StickerEffectRenderer {
    static func render(_ image: UIImage, effect: StickerEffect,
                       amount: Double, size: Double) -> UIImage? {
        guard effect != .none, amount > 0, let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        let rowBytes = width * 4
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var input = [UInt8](repeating: 0, count: rowBytes * height)
        let decoded = input.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: rowBytes,
                                          space: space, bitmapInfo: info) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard decoded else { return nil }
        var output = input
        let strength = min(1, max(0, amount))
        let cell = max(3, Int((4 + size * 22).rounded()))
        let shift = max(1, Int((2 + strength * 11).rounded()))

        func color(_ x: Int, _ y: Int) -> (Double, Double, Double, Double) {
            let xx = min(width - 1, max(0, x))
            let yy = min(height - 1, max(0, y))
            let index = yy * rowBytes + xx * 4
            let alpha = Double(input[index + 3]) / 255
            guard alpha > 0 else { return (0, 0, 0, 0) }
            return (min(255, Double(input[index]) / alpha),
                    min(255, Double(input[index + 1]) / alpha),
                    min(255, Double(input[index + 2]) / alpha), alpha)
        }
        func clamp(_ value: Double) -> UInt8 { UInt8(min(255, max(0, value)).rounded()) }
        func luminance(_ c: (Double, Double, Double, Double)) -> Double {
            (0.2126 * c.0 + 0.7152 * c.1 + 0.0722 * c.2) / 255
        }
        for y in 0..<height {
            for x in 0..<width {
                let index = y * rowBytes + x * 4
                let original = color(x, y)
                guard original.3 > 0 else { continue }
                var red = original.0, green = original.1, blue = original.2
                var alpha = original.3
                switch effect {
                case .none: break
                case .dots:
                    let centerX = (x / cell) * cell + cell / 2
                    let centerY = (y / cell) * cell + cell / 2
                    let sampled = color(centerX, centerY)
                    let sample = sampled.3 > 0 ? sampled : original
                    let radius = Double(cell) * (0.13 + 0.39 * (1 - luminance(sample)))
                    let distance = hypot(Double(x - centerX), Double(y - centerY))
                    let coverage = min(1, max(0, radius - distance + 0.5))
                    alpha *= 1 - strength + strength * coverage
                    red = sample.0; green = sample.1; blue = sample.2
                case .lines:
                    let sampled = color((x / cell) * cell + cell / 2, y)
                    let sample = sampled.3 > 0 ? sampled : original
                    let phase = Double((x + y) % cell)
                    let distance = min(phase, Double(cell) - phase)
                    let halfWidth = Double(cell) * (0.09 + 0.36 * (1 - luminance(sample)))
                    let coverage = min(1, max(0, halfWidth - distance + 0.5))
                    alpha *= 1 - strength + strength * coverage
                case .pixel:
                    let sampled = color((x / cell) * cell + cell / 2,
                                        (y / cell) * cell + cell / 2)
                    let sample = sampled.3 > 0 ? sampled : original
                    red += (sample.0 - red) * strength
                    green += (sample.1 - green) * strength
                    blue += (sample.2 - blue) * strength
                case .stamp:
                    let ink = luminance(original) < 0.56 ? 1.0 : 0.0
                    alpha *= 1 - strength + strength * ink
                    red += (123 - red) * strength
                    green += (70 - green) * strength
                    blue += (48 - blue) * strength
                case .grain:
                    let hash = UInt64(x) &* 73856093 ^ UInt64(y) &* 19349663
                    let noise = (Double(hash % 1009) / 1008 - 0.5) * 100 * strength
                    red += noise; green += noise; blue += noise
                case .rgbShift:
                    let r = color(x - shift, y)
                    let b = color(x + shift, y)
                    red += ((r.3 > 0 ? r.0 : red) - red) * strength
                    blue += ((b.3 > 0 ? b.2 : blue) - blue) * strength
                }
                output[index] = clamp(red * alpha)
                output[index + 1] = clamp(green * alpha)
                output[index + 2] = clamp(blue * alpha)
                output[index + 3] = clamp(alpha * 255)
            }
        }
        let rendered = output.withUnsafeMutableBytes { bytes -> CGImage? in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: rowBytes,
                                          space: space, bitmapInfo: info) else { return nil }
            return context.makeImage()
        }
        guard let rendered else { return nil }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }
}
