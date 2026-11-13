import AVFoundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import SwiftUI
import Vision


extension ScanEngine {
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                if allowed { self?.configureAndStart() }
                else { DispatchQueue.main.async { self?.cameraDenied = true } }
            }
        default:
            cameraDenied = true
        }
    }

    func configureAndStart() {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                defer { self.session.commitConfiguration() }
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: camera),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { self.message = "Camera unavailable" }
                    return
                }
                self.session.addInput(input)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                guard self.session.canAddOutput(output) else {
                    DispatchQueue.main.async { self.message = "Camera unavailable" }
                    return
                }
                self.session.addOutput(output)
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                output.setSampleBufferDelegate(self, queue: self.cameraQueue)
                guard self.session.canAddOutput(self.photoOutput) else {
                    DispatchQueue.main.async { self.message = "Camera unavailable" }
                    return
                }
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                self.isConfigured = true
            }
            if let device = (self.session.inputs.first as? AVCaptureDeviceInput)?.device {
                self.publishZoomOptions(for: device)
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.cameraReady = self.session.isRunning }
        }
    }

    func stop() {
        cameraQueue.async { [weak self] in self?.session.stopRunning() }
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = buffer
        guard shouldAnalyzeLive else { return }
        guard Date().timeIntervalSince(lastAnalysis) > 0.65, !isAnalyzing else { return }
        lastAnalysis = Date()
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try segment(buffer)
            let bounds = bestInstance(in: result.observation, preferred: nil)?.bounds
            let measuredSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
            DispatchQueue.main.async { [weak self] in
                guard self?.step == .camera else { return }
                self?.frameSize = measuredSize
                self?.liveBounds = bounds
            }
        } catch {
            DispatchQueue.main.async { [weak self] in self?.liveBounds = nil }
        }
    }

    func freeze() {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            self.shouldAnalyzeLive = false
            DispatchQueue.main.async {
                self.isWorking = true
                self.scanProgress = .capturing
            }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.photoQualityPrioritization = .quality
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let photoData = photo.fileDataRepresentation()
        let captureError = error?.localizedDescription
        cameraQueue.async { [weak self] in
            guard let self else { return }
            let fullPhoto = photoData.flatMap(UIImage.init(data:))
            let image = fullPhoto.flatMap(self.normalizedPhoto) ?? self.lastFrame.flatMap(self.makeImage)
            guard let image else {
                DispatchQueue.main.async {
                    self.message = captureError ?? "Could not capture this object."
                    self.isWorking = false
                    self.scanProgress = nil
                    self.shouldAnalyzeLive = true
                }
                return
            }
            guard let buffer = self.pixelBuffer(for: image) else {
                DispatchQueue.main.async {
                    self.isWorking = false
                    self.scanProgress = nil
                    self.message = "Could not prepare this photo."
                }
                return
            }
            self.frozenFrame = buffer
            DispatchQueue.main.async {
                self.frozenImage = image
                self.isImportedPhoto = false
                self.selection = self.liveBounds ?? CGRect(x: 0.22, y: 0.40, width: 0.60, height: 0.28)
                self.step = .adjust
                self.message = nil
                self.isWorking = false
                self.scanProgress = nil
            }
        }
    }

    func normalizedPhoto(_ image: UIImage) -> UIImage {
        let targetAspect = frameSize.width / max(frameSize.height, 1)
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        let ratio = size.width / size.height
        let crop: CGRect
        if ratio > targetAspect {
            let width = size.height * targetAspect
            crop = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / targetAspect
            crop = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        }
        guard let cg = upright.cgImage?.cropping(to: crop.integral) else { return upright }
        let cropped = UIImage(cgImage: cg)
        let scale = min(1, 3000 / max(cropped.size.width, cropped.size.height))
        guard scale < 1 else { return cropped }
        let reducedSize = CGSize(width: cropped.size.width * scale, height: cropped.size.height * scale)
        return UIGraphicsImageRenderer(size: reducedSize, format: format).image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: reducedSize))
        }
    }

    func pixelBuffer(for image: UIImage) -> CVPixelBuffer? {
        guard let cg = image.cgImage else { return nil }
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, cg.width, cg.height,
                            kCVPixelFormatType_32BGRA, attributes, &buffer)
        guard let buffer else { return nil }
        ciContext.render(CIImage(cgImage: cg), to: buffer)
        return buffer
    }

    func flipCamera() {
        cameraQueue.async { [weak self] in
            guard let self, self.isConfigured else { return }
            let next: AVCaptureDevice.Position = self.cameraPosition == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: next),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            let oldInput = self.session.inputs.first
            if let oldInput { self.session.removeInput(oldInput) }
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.cameraPosition = next
            } else if let oldInput, self.session.canAddInput(oldInput) {
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()
            if self.cameraPosition == next {
                if (try? device.lockForConfiguration()) != nil {
                    device.videoZoomFactor = max(1, device.minAvailableVideoZoomFactor)
                    device.unlockForConfiguration()
                }
                self.publishZoomOptions(for: device)
            }
        }
    }

    func setZoom(_ factor: Int) {
        guard (1...3).contains(factor), step == .camera else { return }
        cameraQueue.async { [weak self] in
            guard let self,
                  let device = (self.session.inputs.first as? AVCaptureDeviceInput)?.device,
                  CGFloat(factor) >= device.minAvailableVideoZoomFactor,
                  CGFloat(factor) <= device.maxAvailableVideoZoomFactor else { return }
            do {
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: CGFloat(factor), withRate: 6)
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.zoomFactor = factor }
            } catch {
                DispatchQueue.main.async { self.message = "Could not change zoom." }
            }
        }
    }

    func publishZoomOptions(for device: AVCaptureDevice) {
        let options = (1...3).filter {
            CGFloat($0) >= device.minAvailableVideoZoomFactor &&
            CGFloat($0) <= device.maxAvailableVideoZoomFactor
        }
        let selected = Int(device.videoZoomFactor.rounded())
        DispatchQueue.main.async {
            self.availableZoomFactors = options
            self.zoomFactor = options.contains(selected) ? selected : (options.first ?? 1)
        }
    }

    func refreshGalleryThumbnail() {
        let access = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch access {
        case .authorized, .limited:
            fetchLatestGalleryThumbnail()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                if status == .authorized || status == .limited {
                    self?.fetchLatestGalleryThumbnail()
                }
            }
        default:
            galleryThumbnail = nil
        }
    }

    func fetchLatestGalleryThumbnail() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 1
            let assets = PHAsset.fetchAssets(with: .image, options: options)
            guard let asset = assets.firstObject else {
                DispatchQueue.main.async { self?.galleryThumbnail = nil }
                return
            }
            let requestOptions = PHImageRequestOptions()
            requestOptions.deliveryMode = .opportunistic
            requestOptions.resizeMode = .fast
            requestOptions.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 180, height: 180),
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, _ in
                guard let image else { return }
                DispatchQueue.main.async { self?.galleryThumbnail = image }
            }
        }
    }

    func importImage(_ image: UIImage) {
        let maxSide: CGFloat = 3000
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let normalized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let ciImage = CIImage(image: normalized) else {
            message = "Could not open that image."
            return
        }
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32BGRA, attributes, &buffer)
        guard let buffer else { message = "Could not open that image."; return }
        ciContext.render(ciImage, to: buffer)
        importRevision += 1
        let revision = importRevision
        isWorking = true
        scanProgress = .finding
        cameraQueue.async { [weak self] in
            guard let self else { return }
            self.frozenFrame = buffer
            self.shouldAnalyzeLive = false
            let detected = (try? self.segment(buffer))
                .flatMap { self.bestInstance(in: $0.observation, preferred: nil)?.bounds }
            DispatchQueue.main.async {
                guard self.importRevision == revision,
                      self.step == .adjust, self.isImportedPhoto else { return }
                if let detected {
                    let margin: CGFloat = 0.08
                    let left = max(0, detected.minX - margin)
                    let top = max(0, detected.minY - margin)
                    let right = min(1, detected.maxX + margin)
                    let bottom = min(1, detected.maxY + margin)
                    self.selection = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                }
                self.isWorking = false
                self.scanProgress = nil
            }
        }
        frozenImage = normalized
        isImportedPhoto = true
        galleryThumbnail = normalized
        selection = CGRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90)
        step = .adjust
    }

    nonisolated func segment(_ frame: CVPixelBuffer) throws -> (observation: VNInstanceMaskObservation, handler: VNImageRequestHandler) {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: .up)
        try handler.perform([request])
        guard let observation = request.results?.first else { throw ScanError.noObject }
        return (observation, handler)
    }

    func makeImage(from buffer: CVPixelBuffer) -> UIImage? {
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func makeImage(from buffer: CVPixelBuffer, crop: CGRect) -> UIImage? {
        let image = CIImage(cvPixelBuffer: buffer)
        let extent = image.extent
        let cropRect = CGRect(x: crop.minX * extent.width,
                              y: (1 - crop.maxY) * extent.height,
                              width: crop.width * extent.width,
                              height: crop.height * extent.height).intersection(extent).integral
        guard !cropRect.isEmpty else { return nil }
        guard let cgImage = ciContext.createCGImage(image, from: cropRect) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    nonisolated func bestInstance(in observation: VNInstanceMaskObservation, preferred: CGRect?) -> (label: Int, bounds: CGRect)? {
        let mask = observation.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var boxes = [Int: (minX: Int, minY: Int, maxX: Int, maxY: Int, count: Int, overlap: Int)]()
        for y in 0..<height {
            for x in 0..<width {
                let label = Int(pixels[y * stride + x])
                guard label != 0 else { continue }
                let inside = preferred.map { $0.contains(CGPoint(x: (CGFloat(x) + 0.5) / CGFloat(width), y: (CGFloat(y) + 0.5) / CGFloat(height))) } ?? false
                var box = boxes[label] ?? (x, y, x, y, 0, 0)
                box.minX = min(box.minX, x)
                box.minY = min(box.minY, y)
                box.maxX = max(box.maxX, x)
                box.maxY = max(box.maxY, y)
                box.count += 1
                if inside { box.overlap += 1 }
                boxes[label] = box
            }
        }
        let ranked = boxes.filter { $0.value.count > width * height / 300 }
        let chosen = ranked.max { lhs, rhs in
            if preferred != nil { return lhs.value.overlap < rhs.value.overlap }
            return lhs.value.count < rhs.value.count
        }
        guard let chosen, preferred == nil || chosen.value.overlap > 0 else { return nil }
        let box = chosen.value
        let rect = CGRect(x: CGFloat(box.minX) / CGFloat(width), y: CGFloat(box.minY) / CGFloat(height), width: CGFloat(box.maxX - box.minX + 1) / CGFloat(width), height: CGFloat(box.maxY - box.minY + 1) / CGFloat(height))
        return (chosen.key, rect)
    }
}
