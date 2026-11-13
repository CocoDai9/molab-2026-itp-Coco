import AVFoundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import SwiftUI
import Vision


enum StickerFilter: String, CaseIterable, Identifiable {
    case original = "Original"
    case warm = "Warm"
    case mono = "Mono"
    case vintage = "Vintage"
    case chrome = "Chrome"
    case noir = "Noir"
    case fade = "Fade"
    case tonal = "Tonal"

    var id: String { rawValue }

    var coreImageName: String? {
        switch self {
        case .original: nil
        case .warm: "CIPhotoEffectTransfer"
        case .mono: "CIPhotoEffectMono"
        case .vintage: "CIPhotoEffectInstant"
        case .chrome: "CIPhotoEffectChrome"
        case .noir: "CIPhotoEffectNoir"
        case .fade: "CIPhotoEffectFade"
        case .tonal: "CIPhotoEffectTonal"
        }
    }
}


extension ScanEngine {
    func openStickerEditor() {
        guard let cutoutImage else { return }
        if editedImage == nil { editedImage = cutoutImage }
        step = .edit
        message = nil
        guard filterPreviews.isEmpty || effectPreviews.isEmpty else { return }
        editorQueue.async { [weak self] in
            guard let self else { return }
            let previews = Dictionary(uniqueKeysWithValues: StickerFilter.allCases.compactMap { filter in
                self.renderFilter(filter, on: cutoutImage, maxDimension: 180).map { (filter, $0) }
            })
            let small = self.renderFilter(.original, on: cutoutImage, maxDimension: 120)
            let effects = Dictionary(uniqueKeysWithValues: StickerEffect.allCases.compactMap { effect in
                small.flatMap { StickerEffectRenderer.render($0, effect: effect, amount: 0.8, size: 0.5) }
                    .map { (effect, $0) }
            })
            DispatchQueue.main.async { [weak self] in
                self?.filterPreviews = previews
                self?.effectPreviews = effects
            }
        }
    }

    func closeStickerEditor() {
        step = .result
        message = nil
    }

    func selectFilter(_ filter: StickerFilter) {
        selectedFilter = filter
        renderEditorImage()
    }

    func selectEffect(_ effect: StickerEffect) {
        selectedEffect = effect
        renderEditorImage()
    }

    func setEffectAmount(_ value: Double) {
        effectAmount = min(1, max(0, value))
        renderEditorImage()
    }

    func setEffectSize(_ value: Double) {
        effectSize = min(1, max(0, value))
        renderEditorImage()
    }

    func selectStroke(_ style: StickerStrokeStyle) {
        strokeStyle = style
        renderEditorImage()
    }

    func setStrokeSpacing(_ spacing: StickerStrokeSpacing) {
        strokeSpacing = spacing
        renderEditorImage()
    }

    func setStrokeWidth(_ value: Double) {
        strokeWidth = min(1, max(0, value))
        renderEditorImage()
    }

    func setStrokeGap(_ value: Double) {
        strokeGap = min(1, max(0, value))
        renderEditorImage()
    }

    func setStrokeColor(_ value: Color) {
        strokeColor = value
        renderEditorImage()
    }

    func renderEditorImage() {
        guard let cutoutImage else { return }
        editorRenderRevision += 1
        let revision = editorRenderRevision
        let filter = selectedFilter
        let effect = selectedEffect
        let amount = effectAmount
        let size = effectSize
        let style = strokeStyle
        let spacing = strokeSpacing
        let strokeWidth = strokeWidth
        let strokeGap = strokeGap
        let strokeColor = UIColor(strokeColor)
        pendingEditorRender?.cancel()
        isRenderingFilter = true
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let filtered = self.renderFilter(filter, on: cutoutImage)
            let effected = filtered.flatMap {
                StickerEffectRenderer.render($0, effect: effect, amount: amount, size: size)
            }
            let rendered = effected.flatMap {
                StickerStrokeRenderer.render($0, style: style, spacing: spacing,
                                             width: strokeWidth, gap: strokeGap, color: strokeColor)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.editorRenderRevision == revision else { return }
                self.editedImage = rendered
                self.isRenderingFilter = false
                if rendered == nil { self.message = "Could not render this effect." }
            }
        }
        pendingEditorRender = item
        editorQueue.asyncAfter(deadline: .now() + 0.06, execute: item)
    }

    func savePNG() {
        guard step != .edit || !isRenderingFilter,
              let image = step == .edit ? editedImage : cutoutImage else { return }
        let output = step == .edit ? renderStretchedImage(image) : image
        guard let data = output?.pngData() else {
            message = "Could not save this sticker."
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self?.message = "Allow Photos access to save the PNG." }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = "public.png"
                request.addResource(with: .photo, data: data, options: options)
            }) { saved, error in
                DispatchQueue.main.async {
                    self?.message = saved
                        ? "Transparent PNG saved. Photos may display it on white."
                        : (error?.localizedDescription ?? "Could not save PNG")
                    if saved { self?.refreshGalleryThumbnail() }
                }
            }
        }
    }

    func renderStretchedImage(_ image: UIImage) -> UIImage? {
        guard stretchWidth != 1 || stretchHeight != 1 else { return image }
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let transformed = input.transformed(by: CGAffineTransform(
            scaleX: CGFloat(stretchWidth), y: CGFloat(stretchHeight)))
        guard let output = ciContext.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
    }

    func renderFilter(_ filter: StickerFilter, on image: UIImage,
                              maxDimension: CGFloat? = nil) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        var input = CIImage(cgImage: cgImage)
        if let maxDimension {
            let factor = min(1, maxDimension / max(input.extent.width, input.extent.height))
            input = input.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        }
        let output: CIImage
        if let name = filter.coreImageName {
            guard let effect = CIFilter(name: name) else { return nil }
            effect.setValue(input, forKey: kCIInputImageKey)
            guard let filtered = effect.outputImage else { return nil }
            output = filtered
        } else {
            output = input
        }
        guard let result = ciContext.createCGImage(output, from: input.extent) else { return nil }
        return UIImage(cgImage: result, scale: image.scale, orientation: image.imageOrientation)
    }

}
