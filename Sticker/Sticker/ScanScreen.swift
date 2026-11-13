import AVFoundation
import PhotosUI
import SwiftUI

extension ContentView {
    func scanScreen(adjusting: Bool) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let photoViewport = CGRect(x: 0, y: 104, width: size.width,
                                       height: max(1, size.height - 104))
            ZStack {
                if adjusting, let image = engine.frozenImage {
                    if engine.isImportedPhoto {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(width: photoViewport.width, height: photoViewport.height)
                            .position(x: photoViewport.midX, y: photoViewport.midY)
                    } else {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: size.width, height: size.height).clipped()
                    }
                } else {
                    CameraPreview(session: engine.session)
                    if !engine.cameraReady {
                        Image("ScanSample").resizable().scaledToFill()
                            .frame(width: size.width, height: size.height).clipped()
                    }
                }

                VStack(spacing: 0) {
                    Color.black.opacity(0.5).frame(height: 104)
                    Spacer()
                    if !adjusting {
                        Color.black.opacity(0.5).frame(height: 145)
                    }
                }
                .allowsHitTesting(false)

                if adjusting {
                    AdjustGuide(rect: $engine.selection, source: engine.frozenImage?.size ?? size,
                                viewport: engine.isImportedPhoto ? photoViewport.size : size,
                                origin: engine.isImportedPhoto ? photoViewport.origin : .zero,
                                fit: engine.isImportedPhoto)
                } else if let bounds = engine.liveBounds {
                    CornerGuide().stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: mapped(bounds, source: engine.frameSize, viewport: size).width,
                               height: mapped(bounds, source: engine.frameSize, viewport: size).height)
                        .position(x: mapped(bounds, source: engine.frameSize, viewport: size).midX,
                                  y: mapped(bounds, source: engine.frameSize, viewport: size).midY)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    if adjusting {
                        HStack {
                            Button { engine.retake() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 21, weight: .medium))
                                    .frame(width: 44, height: 42)
                            }
                            .accessibilityLabel("Back to camera")
                            Spacer()
                            Button("Done") { engine.prepareRefinement() }
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 48, height: 42, alignment: .trailing)
                                .disabled(engine.isWorking)
                                .accessibilityLabel("Done adjusting selection")
                        }
                        .foregroundStyle(.white)
                        .padding(.leading, 16)
                        .padding(.trailing, 29)
                        .padding(.top, 62)
                    } else {
                        HStack {
                            Button { showingIntro = true } label: {
                                Image(systemName: "xmark").font(.system(size: 23))
                                    .frame(width: 44, height: 44)
                            }
                            Spacer()
                            Text("Scan an object")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Color.clear.frame(width: 44, height: 44)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 57)
                    }

                    Spacer()
                    if !adjusting {
                        HStack {
                            PhotosPicker(selection: $importedPhoto, matching: .images) {
                                Group {
                                    if let image = engine.galleryThumbnail {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(.black.opacity(0.55))
                                    }
                                }
                                .frame(width: 45, height: 45)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(3)
                                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .frame(width: 66, height: 66)
                            Spacer()
                            Button { engine.freeze() } label: {
                                ZStack {
                                    Circle().stroke(.white, lineWidth: 3).frame(width: 62, height: 62)
                                    Circle().fill(.white).frame(width: 52, height: 52)
                                }.frame(width: 72, height: 72)
                            }
                            .disabled(engine.isWorking || !engine.cameraReady)
                            .accessibilityLabel("Scan object")
                            Spacer()
                            Button { engine.flipCamera() } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 39, height: 39)
                                    .background(.black.opacity(0.5), in: Circle())
                            }
                            .frame(width: 66, height: 66)
                            .accessibilityLabel("Flip camera")
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 36)
                    }
                }

                if !adjusting {
                    Button {
                        let options = engine.availableZoomFactors
                        guard let index = options.firstIndex(of: engine.zoomFactor), !options.isEmpty else { return }
                        engine.setZoom(options[(index + 1) % options.count])
                    } label: {
                        Text("\(engine.zoomFactor)X")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 31)
                            .background(Color(red: 45/255, green: 39/255, blue: 35/255).opacity(0.67),
                                        in: Capsule())
                            .frame(width: 66, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(!engine.cameraReady || engine.availableZoomFactors.count < 2)
                    .accessibilityLabel("\(engine.zoomFactor) times zoom. Tap to switch zoom.")
                    .position(x: size.width / 2, y: size.height - 183)
                }

                if engine.isWorking {
                    ProgressView(engine.scanProgress?.rawValue ?? "Working…")
                        .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                if engine.cameraDenied && !adjusting {
                    VStack(spacing: 14) {
                        Image(systemName: "camera.fill").font(.title)
                        Text("Allow camera access in Settings to scan objects.").multilineTextAlignment(.center)
                        PhotosPicker("Import a photo instead", selection: $importedPhoto, matching: .images)
                    }
                    .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(32)
                }
            }
            .frame(width: size.width, height: size.height)
            .background(.black)
            .coordinateSpace(name: "scan")
        }
        .ignoresSafeArea()
    }

}

struct AdjustGuide: View {
    @Binding var rect: CGRect
    let source: CGSize
    let viewport: CGSize
    let origin: CGPoint
    let fit: Bool
    @State private var dragStartRect: CGRect?

    var body: some View {
        let visible = mapped(rect, source: source, viewport: viewport,
                             fit: fit, origin: origin)
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color(red: 1, green: 244/255, blue: 217/255), lineWidth: 2)
            .frame(width: visible.width, height: visible.height)
            .position(x: visible.midX, y: visible.midY)
        ForEach(0..<4, id: \.self) { corner in
            Circle().fill(.white).frame(width: 8, height: 8)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .position(x: corner.isMultiple(of: 2) ? visible.minX : visible.maxX,
                          y: corner < 2 ? visible.minY : visible.maxY)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("scan")).onChanged { gesture in
                    let start = dragStartRect ?? rect
                    if dragStartRect == nil { dragStartRect = start }
                    let startPoint = unmapped(gesture.startLocation, source: source,
                                              viewport: viewport, fit: fit, origin: origin)
                    let currentPoint = unmapped(gesture.location, source: source,
                                                viewport: viewport, fit: fit, origin: origin)
                    let dx = currentPoint.x - startPoint.x
                    let dy = currentPoint.y - startPoint.y
                    let minimumSide: CGFloat = 0.1
                    let left = corner.isMultiple(of: 2)
                        ? min(max(start.minX + dx, 0), start.maxX - minimumSide)
                        : start.minX
                    let right = corner.isMultiple(of: 2)
                        ? start.maxX
                        : max(min(start.maxX + dx, 1), start.minX + minimumSide)
                    let top = corner < 2
                        ? min(max(start.minY + dy, 0), start.maxY - minimumSide)
                        : start.minY
                    let bottom = corner < 2
                        ? start.maxY
                        : max(min(start.maxY + dy, 1), start.minY + minimumSide)
                    rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                }.onEnded { _ in dragStartRect = nil })
        }
    }
}

struct CornerGuide: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let a: CGFloat = 36
        let r: CGFloat = 10
        path.move(to: CGPoint(x: rect.minX, y: rect.minY+a))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY+r))
        path.addQuadCurve(to: CGPoint(x: rect.minX+r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX+a, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX-a, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX-r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY+r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY+a))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY-a))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY-r))
        path.addQuadCurve(to: CGPoint(x: rect.minX+r, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX+a, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX-a, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX-r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY-r), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY-a))
        return path
    }
}

func mapped(_ rect: CGRect, source: CGSize, viewport: CGSize,
            fit: Bool = false, origin: CGPoint = .zero) -> CGRect {
    guard source.width > 0, source.height > 0 else { return .zero }
    let scale = fit ? min(viewport.width/source.width, viewport.height/source.height)
                    : max(viewport.width/source.width, viewport.height/source.height)
    let size = CGSize(width: source.width*scale, height: source.height*scale)
    return CGRect(x: origin.x+(viewport.width-size.width)/2+rect.minX*size.width,
                  y: origin.y+(viewport.height-size.height)/2+rect.minY*size.height,
                  width: rect.width*size.width, height: rect.height*size.height)
}

func unmapped(_ point: CGPoint, source: CGSize, viewport: CGSize,
              fit: Bool = false, origin: CGPoint = .zero) -> CGPoint {
    guard source.width > 0, source.height > 0 else { return .zero }
    let scale = fit ? min(viewport.width/source.width, viewport.height/source.height)
                    : max(viewport.width/source.width, viewport.height/source.height)
    let size = CGSize(width: source.width*scale, height: source.height*scale)
    let imageOrigin = CGPoint(x: origin.x+(viewport.width-size.width)/2,
                              y: origin.y+(viewport.height-size.height)/2)
    return CGPoint(x: (point.x-imageOrigin.x)/size.width,
                   y: (point.y-imageOrigin.y)/size.height)
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

#Preview { ContentView() }
