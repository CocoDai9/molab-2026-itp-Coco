import AVFoundation
import Combine
import CoreImage
import Photos
import SwiftUI

enum VideoFilter: String, CaseIterable, Identifiable {
    case normal = "Original"
    case mono = "Mono"
    case comic = "Comic"
    case sepia = "Sepia"
    case bloom = "Bloom"

    var id: Self { self }

    func apply(to image: CIImage, intensity: Double) -> CIImage {
        switch self {
        case .normal: image
        case .mono: image.applyingFilter("CIPhotoEffectMono")
        case .comic: image.applyingFilter("CIComicEffect")
        case .sepia: image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.8])
        case .bloom: image.applyingFilter("CIBloom", parameters: [
            kCIInputIntensityKey: intensity,
            kCIInputRadiusKey: 15.0
        ])
        }
    }
}

final class CameraModel: NSObject, ObservableObject {
    @Published var previewImage: CGImage?
    @Published var selectedFilter: VideoFilter = .normal
    @Published var bloomIntensity = 1.0
    @Published var isRecording = false
    @Published var isReady = false
    @Published var isFrontCamera = false
    @Published var recordingSeconds = 0
    @Published var message = "Waiting for camera…"

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "VideoApp.session")
    private let videoQueue = DispatchQueue(label: "VideoApp.frames")
    private let context = CIContext()

    // Access these values only on videoQueue.
    private var filter: VideoFilter = .normal
    private var filterIntensity = 1.0
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var wantsRecording = false
    private var recordingTimer: Timer?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configure()
                } else {
                    DispatchQueue.main.async { self?.message = "Enable camera access in Settings." }
                }
            }
        default:
            message = "Enable camera access in Settings."
        }
    }

    private func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.inputs.isEmpty else {
                self.session.startRunning()
                return
            }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async { self.message = "No camera available. Use an iPhone." }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.videoQueue)
            guard self.session.canAddInput(input), self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.message = "Cannot start camera." }
                return
            }
            self.session.addInput(input)
            self.session.addOutput(output)
            if let connection = output.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isReady = true
                self.message = "Choose a filter and tap to record"
            }
        }
    }

    func stop() {
        if isRecording { toggleRecording() }
        sessionQueue.async { [weak self] in self?.session.stopRunning() }
    }

    func selectFilter(_ newFilter: VideoFilter) {
        selectedFilter = newFilter
        videoQueue.async { [weak self] in self?.filter = newFilter }
    }

    func setBloomIntensity(_ value: Double) {
        bloomIntensity = value
        videoQueue.async { [weak self] in self?.filterIntensity = value }
    }

    func flipCamera() {
        guard isReady, !isRecording else { return }
        sessionQueue.async { [weak self] in
            guard let self,
                  let oldInput = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first else { return }

            let newPosition: AVCaptureDevice.Position = oldInput.device.position == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            self.session.beginConfiguration()
            self.session.removeInput(oldInput)
            let switched = self.session.canAddInput(newInput)
            if switched {
                self.session.addInput(newInput)
            } else {
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                if switched { self.isFrontCamera = newPosition == .front }
            }
        }
    }

    func toggleRecording() {
        guard isReady else { return }
        if isRecording {
            isRecording = false
            recordingTimer?.invalidate()
            recordingTimer = nil
            message = "Saving video…"
            videoQueue.async { [weak self] in self?.finishRecording() }
        } else {
            isRecording = true
            recordingSeconds = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.recordingSeconds += 1
            }
            message = "Recording… tap to stop"
            videoQueue.async { [weak self] in self?.wantsRecording = true }
        }
    }

    private func beginRecording(with buffer: CVPixelBuffer, at time: CMTime) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)

        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ])
            input.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ])
            guard writer.canAdd(input) else { throw RecordingError.cannotAddInput }
            writer.add(input)
            guard writer.startWriting() else { throw writer.error ?? RecordingError.cannotStart }
            writer.startSession(atSourceTime: time)
            self.writer = writer
            writerInput = input
            self.adaptor = adaptor
            outputURL = url
        } catch {
            wantsRecording = false
            DispatchQueue.main.async {
                self.isRecording = false
                self.recordingTimer?.invalidate()
                self.recordingTimer = nil
                self.message = "Recording failed: \(error.localizedDescription)"
            }
        }
    }

    private func finishRecording() {
        wantsRecording = false
        guard let writer, let writerInput, let outputURL else {
            DispatchQueue.main.async { self.message = "No video captured. Try again." }
            return
        }
        writerInput.markAsFinished()
        writer.finishWriting { [weak self] in
            guard let self else { return }
            if writer.status == .completed {
                self.saveToPhotos(outputURL)
            } else {
                DispatchQueue.main.async { self.message = "Could not finish video." }
            }
        }
        self.writer = nil
        self.writerInput = nil
        adaptor = nil
        self.outputURL = nil
    }

    private func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard let self else { return }
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self.message = "Allow Photos access to save the video." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { saved, error in
                DispatchQueue.main.async {
                    self.message = saved ? "Saved to Photos" : "Save failed: \(error?.localizedDescription ?? "unknown error")"
                }
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private enum RecordingError: Error {
        case cannotAddInput, cannotStart
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let source = CIImage(cvPixelBuffer: buffer)
        let image = filter.apply(to: source, intensity: filterIntensity).cropped(to: source.extent)

        if let preview = context.createCGImage(image, from: source.extent) {
            DispatchQueue.main.async { self.previewImage = preview }
        }

        guard wantsRecording else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if writer == nil { beginRecording(with: buffer, at: time) }
        guard let writerInput, writerInput.isReadyForMoreMediaData,
              let adaptor, let pool = adaptor.pixelBufferPool else { return }

        var renderedBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &renderedBuffer) == kCVReturnSuccess,
              let renderedBuffer else { return }
        context.render(image, to: renderedBuffer)
        adaptor.append(renderedBuffer, withPresentationTime: time)
    }
}
