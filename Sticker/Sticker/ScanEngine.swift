import AVFoundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import SwiftUI
import Vision


enum ScanStep: Equatable {
    case camera
    case adjust
    case refine
    case result
    case edit
}

enum ScanProgress: String {
    case capturing = "Capturing photo…"
    case finding = "Finding object…"
    case cutting = "Cutting out object…"
}


final class ScanEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    @Published var step: ScanStep = .camera
    @Published var cameraReady = false
    @Published var cameraDenied = false
    @Published var isWorking = false
    @Published var scanProgress: ScanProgress?
    @Published var message: String?
    @Published var liveBounds: CGRect?
    @Published var frameSize = CGSize(width: 1080, height: 1920)
    @Published var zoomFactor = 1
    @Published var availableZoomFactors = [1]
    @Published var frozenImage: UIImage?
    @Published var isImportedPhoto = false
    @Published var cutoutImage: UIImage?
    @Published var editedImage: UIImage?
    @Published var selectedFilter: StickerFilter = .original
    @Published var filterPreviews: [StickerFilter: UIImage] = [:]
    @Published var selectedEffect: StickerEffect = .none
    @Published var effectAmount = 0.7
    @Published var effectSize = 0.5
    @Published var effectPreviews: [StickerEffect: UIImage] = [:]
    @Published var isRenderingFilter = false
    @Published var strokeStyle: StickerStrokeStyle = .none
    @Published var strokeSpacing: StickerStrokeSpacing = .attached
    @Published var strokeWidth = 0.45
    @Published var strokeGap = 0.35
    @Published var strokeColor = Style.brown
    @Published var stretchWidth = 1.0
    @Published var stretchHeight = 1.0
    @Published var refinementSource: UIImage?
    @Published var refinementMask: UIImage?
    @Published var refinementHighlight: UIImage?
    @Published var canUndoRefinement = false
    @Published var galleryThumbnail: UIImage?
    @Published var selection = CGRect(x: 0.22, y: 0.40, width: 0.60, height: 0.28)

    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let cameraQueue = DispatchQueue(label: "toto.camera", qos: .userInitiated)
    let ciContext = CIContext()
    let cutoutModel = ISNetCutout()
    nonisolated(unsafe) var lastFrame: CVPixelBuffer?
    var frozenFrame: CVPixelBuffer?
    nonisolated(unsafe) var lastAnalysis = Date.distantPast
    var isConfigured = false
    nonisolated(unsafe) var isAnalyzing = false
    nonisolated(unsafe) var shouldAnalyzeLive = true
    var cameraPosition: AVCaptureDevice.Position = .back
    var maskHistory: [UIImage] = []
    let editorQueue = DispatchQueue(label: "sticker.editor", qos: .userInitiated)
    var pendingEditorRender: DispatchWorkItem?
    var editorRenderRevision = 0
    var importRevision = 0

    func retake() {
        importRevision += 1
        cameraQueue.async { [weak self] in
            self?.frozenFrame = nil
            self?.shouldAnalyzeLive = true
        }
        cutoutImage = nil
        editedImage = nil
        selectedEffect = .none
        effectPreviews = [:]
        strokeStyle = .none
        strokeSpacing = .attached
        strokeColor = Style.brown
        stretchWidth = 1
        stretchHeight = 1
        refinementSource = nil
        refinementMask = nil
        refinementHighlight = nil
        maskHistory.removeAll()
        canUndoRefinement = false
        frozenImage = nil
        isImportedPhoto = false
        isWorking = false
        scanProgress = nil
        step = .camera
        message = nil
    }

    func clearMessage() { message = nil }

    func edit() {
        step = refinementMask == nil ? .adjust : .refine
        message = nil
    }

    func backToEdgeAdjust() {
        step = .adjust
        message = nil
    }

}
