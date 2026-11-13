import AVFoundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import SwiftUI
import Vision


extension ScanEngine {
    func prepareRefinement() {
        guard !isWorking else { return }
        isWorking = true
        scanProgress = .cutting
        message = nil
        let selectedArea = selection
        cameraQueue.async { [weak self] in
            guard let self, let frame = self.frozenFrame else {
                DispatchQueue.main.async {
                    self?.isWorking = false
                    self?.scanProgress = nil
                }
                return
            }
            do {
                guard let source = self.makeImage(from: frame) else { throw ScanError.renderFailed }
                let mask: UIImage
                do {
                    mask = try self.cutoutModel.mask(for: source, selection: selectedArea)
                } catch {
                    // Keep the native Vision path available if the model cannot run.
                    let result = try self.segment(frame)
                    guard let match = self.bestInstance(in: result.observation, preferred: selectedArea) else {
                        throw error
                    }
                    let scaled = try result.observation.generateScaledMaskForImage(
                        forInstances: IndexSet(integer: match.label), from: result.handler
                    )
                    guard let visionMask = self.makeImage(from: scaled) else { throw error }
                    mask = visionMask
                }
                guard let constrainedMask = self.maskWithinSelection(mask, selection: selectedArea),
                      let highlight = self.composite(mask: constrainedMask, over: nil, highlight: true) else {
                    throw ScanError.renderFailed
                }
                DispatchQueue.main.async {
                    self.refinementSource = source
                    self.refinementMask = constrainedMask
                    self.refinementHighlight = highlight
                    self.maskHistory.removeAll()
                    self.canUndoRefinement = false
                    self.step = .refine
                    self.isWorking = false
                    self.scanProgress = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.message = error.localizedDescription
                    self.isWorking = false
                    self.scanProgress = nil
                }
            }
        }
    }

    /// Scan / 02 is the boundary for the automatic result, including the
    /// Vision fallback. The user can still add pixels manually in Scan / 03.
    func maskWithinSelection(_ mask: UIImage, selection: CGRect) -> UIImage? {
        guard let cgImage = mask.cgImage else { return nil }
        let selected = selection.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !selected.isNull, selected.width > 0, selected.height > 0 else { return nil }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let bounds = CGRect(origin: .zero, size: size)
        let selectedPixels = CGRect(x: selected.minX * size.width,
                                    y: selected.minY * size.height,
                                    width: selected.width * size.width,
                                    height: selected.height * size.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            UIColor.black.setFill()
            renderer.cgContext.fill(bounds)
            renderer.cgContext.clip(to: selectedPixels)
            mask.draw(in: bounds)
        }
    }

    func beginRefinementStroke() {
        guard let mask = refinementMask else { return }
        maskHistory.append(mask)
        if maskHistory.count > 12 { maskHistory.removeFirst() }
        canUndoRefinement = true
    }

    func paintRefinement(from start: CGPoint, to end: CGPoint, canvasSize: CGSize,
                         brushSize: CGFloat, protectedTopHeight: CGFloat,
                         zoomScale: CGFloat, adding: Bool) {
        guard let current = refinementMask, canvasSize.width > 0, canvasSize.height > 0,
              zoomScale > 0 else { return }
        let imageSize = current.size
        let scale = max(canvasSize.width / imageSize.width,
                        canvasSize.height / imageSize.height)
        let insetX = (imageSize.width * scale - canvasSize.width) / 2
        let insetY = (imageSize.height * scale - canvasSize.height) / 2
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        func imagePoint(_ screenPoint: CGPoint) -> CGPoint {
            let unzoomedX = canvasCenter.x + (screenPoint.x - canvasCenter.x) / zoomScale
            let unzoomedY = canvasCenter.y + (screenPoint.y - canvasCenter.y) / zoomScale
            return CGPoint(x: (unzoomedX + insetX) / scale,
                           y: (unzoomedY + insetY) / scale)
        }
        let from = imagePoint(start)
        let to = imagePoint(end)
        let diameter = brushSize / (scale * zoomScale)
        let protectedImageY = min(max(imagePoint(CGPoint(x: 0, y: protectedTopHeight)).y, 0), imageSize.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let updated = UIGraphicsImageRenderer(size: imageSize, format: format).image { renderer in
            current.draw(in: CGRect(origin: .zero, size: imageSize))
            let context = renderer.cgContext
            context.clip(to: CGRect(x: 0, y: protectedImageY,
                                    width: imageSize.width,
                                    height: imageSize.height - protectedImageY))
            context.setStrokeColor(adding ? UIColor.white.cgColor : UIColor.black.cgColor)
            context.setFillColor(adding ? UIColor.white.cgColor : UIColor.black.cgColor)
            context.setLineWidth(diameter)
            context.setLineCap(.round)
            context.move(to: from)
            context.addLine(to: to)
            context.strokePath()
            context.fillEllipse(in: CGRect(x: to.x - diameter / 2, y: to.y - diameter / 2,
                                           width: diameter, height: diameter))
        }
        refinementMask = updated
        refinementHighlight = composite(mask: updated, over: nil, highlight: true)
    }

    func undoRefinementStroke() {
        guard let previous = maskHistory.popLast() else { return }
        refinementMask = previous
        refinementHighlight = composite(mask: previous, over: nil, highlight: true)
        canUndoRefinement = !maskHistory.isEmpty
    }

    func finishRefinement() {
        guard let source = refinementSource, let mask = refinementMask, !isWorking else { return }
        isWorking = true
        cameraQueue.async { [weak self] in
            guard let self else { return }
            let output = self.smoothStickerMask(mask)
                .flatMap { self.composite(mask: $0, over: source, highlight: false) }
                .flatMap(self.trimTransparentEdges)
            DispatchQueue.main.async {
                self.isWorking = false
                if let output {
                    self.cutoutImage = output
                    self.editedImage = output
                    self.selectedFilter = .original
                    self.filterPreviews = [:]
                    self.selectedEffect = .none
                    self.effectAmount = 0.7
                    self.effectSize = 0.5
                    self.effectPreviews = [:]
                    self.strokeStyle = .none
                    self.strokeSpacing = .attached
                    self.strokeColor = Style.brown
                    self.strokeWidth = 0.45
                    self.strokeGap = 0.35
                    self.stretchWidth = 1
                    self.stretchHeight = 1
                    self.step = .result
                } else {
                    self.message = ScanError.renderFailed.localizedDescription
                }
            }
        }
    }

    func composite(mask: UIImage, over source: UIImage?, highlight: Bool) -> UIImage? {
        guard let maskCG = mask.cgImage else { return nil }
        let maskCI = CIImage(cgImage: maskCG)
        let extent = maskCI.extent
        let foreground: CIImage
        if highlight {
            foreground = CIImage(color: CIColor(red: 0.96, green: 0.43, blue: 0.18, alpha: 0.52))
                .cropped(to: extent)
        } else {
            guard let sourceCG = source?.cgImage else { return nil }
            foreground = CIImage(cgImage: sourceCG).cropped(to: extent)
        }
        let filter = CIFilter.blendWithMask()
        filter.inputImage = foreground
        filter.backgroundImage = CIImage(color: .clear).cropped(to: extent)
        filter.maskImage = maskCI
        guard let result = filter.outputImage,
              let cgImage = ciContext.createCGImage(result, from: extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func smoothStickerMask(_ mask: UIImage) -> UIImage? {
        guard let cgImage = mask.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let source = CIImage(cgImage: cgImage)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = source
        // The Vision mask is upscaled from a smaller segmentation map. Smooth its
        // contour before remapping opacity so those enlarged steps do not survive.
        blur.radius = 2.5
        guard let smoothedMask = blur.outputImage?.cropped(to: source.extent) else { return nil }
        ciContext.render(smoothedMask, toBitmap: &pixels,
                         rowBytes: bytesPerRow,
                         bounds: CGRect(x: 0, y: 0, width: width, height: height),
                         format: .RGBA8, colorSpace: colorSpace)

        // Keep a real antialiased transition instead of hardening the blurred mask
        // into a nearly binary edge. The interior remains fully opaque.
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let luminance = (0.2126 * Double(pixels[offset]) +
                             0.7152 * Double(pixels[offset + 1]) +
                             0.0722 * Double(pixels[offset + 2])) / 255
            let position = min(1, max(0, (luminance - 0.20) / 0.60))
            let smoothed = position * position * (3 - 2 * position)
            let level = UInt8((smoothed * 255).rounded())
            pixels[offset] = level
            pixels[offset + 1] = level
            pixels[offset + 2] = level
            pixels[offset + 3] = 255
        }

        let image = CIImage(bitmapData: Data(pixels), bytesPerRow: bytesPerRow,
                            size: CGSize(width: width, height: height),
                            format: .RGBA8, colorSpace: colorSpace)
        guard let output = ciContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: output)
    }

    func trimTransparentEdges(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let bounds: CGRect? = pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                                              CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            var minX = width, minY = height, maxX = -1, maxY = -1
            let pixelBytes = bytes.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width where pixelBytes[y * bytesPerRow + x * 4 + 3] > 8 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            let padding = max(12, Int(Double(max(width, height)) * 0.015))
            let left = max(0, minX - padding)
            let top = max(0, minY - padding)
            let right = min(width, maxX + padding + 1)
            let bottom = min(height, maxY + padding + 1)
            return CGRect(x: left, y: top, width: right - left, height: bottom - top)
        }
        guard let bounds, let cropped = cgImage.cropping(to: bounds) else { return nil }
        return UIImage(cgImage: cropped)
    }

}

enum ScanError: LocalizedError {
    case noObject
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .noObject: "No object found in the selected area. Adjust the edges and try again."
        case .renderFailed: "Could not render the cutout. Please try again."
        }
    }
}
