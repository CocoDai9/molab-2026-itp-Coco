import CoreGraphics
import Foundation
import UIKit

/// Runs the bundled ISNet model only on the user's Scan / 02 selection.
/// Live camera detection stays in Vision; this runs once before brush refinement.
final class ISNetCutout {
    private let side = 1024
    private var environment: ORTEnv?
    private var session: ORTSession?

    func mask(for image: UIImage, selection: CGRect) throws -> UIImage {
        guard let source = image.cgImage else { throw CutoutError.invalidImage }
        let width = source.width
        let height = source.height
        let selected = selection.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !selected.isNull, selected.width > 0, selected.height > 0 else {
            throw CutoutError.invalidImage
        }
        let selectedPixels = CGRect(x: selected.minX * CGFloat(width),
                                    y: selected.minY * CGFloat(height),
                                    width: selected.width * CGFloat(width),
                                    height: selected.height * CGFloat(height))
        let crop = selectedPixels.integral.intersection(
            CGRect(x: 0, y: 0, width: width, height: height))
        guard let cropped = source.cropping(to: crop) else { throw CutoutError.invalidImage }
        let input = try tensor(from: UIImage(cgImage: cropped))

        if session == nil {
            guard let path = Bundle.main.path(forResource: "isnet-general-use", ofType: "onnx") else {
                throw CutoutError.modelMissing
            }
            let env = try ORTEnv(loggingLevel: .warning)
            let options = try ORTSessionOptions()
            try options.setIntraOpNumThreads(2)
            environment = env
            session = try ORTSession(env: env, modelPath: path, sessionOptions: options)
        }
        let value = try ORTValue(tensorData: NSMutableData(data: input.withUnsafeBufferPointer { Data(buffer: $0) }),
                                 elementType: .float, shape: [1, 3, 1024, 1024])
        let outputs = try session!.run(withInputs: ["input_image": value],
                                       outputNames: ["output_image"], runOptions: nil)
        guard let output = outputs["output_image"] else { throw CutoutError.invalidOutput }
        let data = try output.tensorData() as Data
        guard data.count == side * side * MemoryLayout<Float>.size else { throw CutoutError.invalidOutput }

        let floats = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        guard let low = floats.min(), let high = floats.max(), high > low else {
            throw CutoutError.invalidOutput
        }
        var gray = [UInt8](repeating: 0, count: side * side)
        for index in gray.indices {
            let alpha = max(0, min(1, (floats[index] - low) / (high - low)))
            gray[index] = UInt8((alpha * 255).rounded())
        }
        let provider = CGDataProvider(data: Data(gray) as CFData)!
        guard let maskCG = CGImage(width: side, height: side, bitsPerComponent: 8,
                                   bitsPerPixel: 8, bytesPerRow: side,
                                   space: CGColorSpaceCreateDeviceGray(),
                                   bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                                   decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw CutoutError.invalidOutput
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { renderer in
            UIColor.black.setFill()
            renderer.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            renderer.cgContext.interpolationQuality = .high
            renderer.cgContext.clip(to: selectedPixels)
            UIImage(cgImage: maskCG).draw(in: crop)
        }
    }

    private func tensor(from image: UIImage) throws -> [Float] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { renderer in
            renderer.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let cg = resized.cgImage else { throw CutoutError.invalidImage }
        let rowBytes = side * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * side)
        guard let context = CGContext(data: &pixels, width: side, height: side,
                                      bitsPerComponent: 8, bytesPerRow: rowBytes,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CutoutError.invalidImage
        }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        var brightest: UInt8 = 1
        for index in 0..<(side * side) {
            let offset = index * 4
            brightest = max(brightest, pixels[offset], pixels[offset + 1], pixels[offset + 2])
        }
        let divisor = Float(brightest)
        let plane = side * side
        var tensor = [Float](repeating: 0, count: plane * 3)
        for index in 0..<plane {
            let offset = index * 4
            tensor[index] = Float(pixels[offset]) / divisor - 0.5
            tensor[plane + index] = Float(pixels[offset + 1]) / divisor - 0.5
            tensor[2 * plane + index] = Float(pixels[offset + 2]) / divisor - 0.5
        }
        return tensor
    }
}

private enum CutoutError: LocalizedError {
    case invalidImage, invalidOutput, modelMissing

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Could not read the selected image."
        case .invalidOutput: "Could not make a cutout mask."
        case .modelMissing: "The cutout model is missing from the app."
        }
    }
}
