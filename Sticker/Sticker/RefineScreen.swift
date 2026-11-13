import AVFoundation
import PhotosUI
import SwiftUI

enum RefinementBrush: String, CaseIterable {
    case add = "Add"
    case erase = "Erase"
}


extension ContentView {
    var refineScreen: some View {
        GeometryReader { geometry in
            ZStack {
                RefinementCanvas(engine: engine, brush: refinementBrush,
                                 brushSize: refinementBrushSize)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                VStack(spacing: 0) {
                    Color.black.opacity(0.5).frame(height: Style.refinementProtectedTopHeight)
                    Spacer()
                }

                VStack(spacing: 0) {
                    HStack {
                        Button { engine.backToEdgeAdjust() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Back to edge adjust")
                        Spacer()
                        Button("Done") { engine.finishRefinement() }
                            .font(.system(size: 16, weight: .bold))
                            .frame(minWidth: 48, minHeight: 44)
                            .disabled(engine.isWorking || engine.refinementMask == nil)
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 16)
                    .padding(.trailing, 30)
                    .padding(.top, 64)

                    Text("paint to add or erase the highlighted area")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.horizontal, 43)
                        .padding(.top, 26)

                    Spacer()

                    HStack {
                        ForEach(RefinementBrush.allCases, id: \.self) { mode in
                            Button { refinementBrush = mode } label: {
                                Text(mode.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 115, height: 33)
                                    .background(refinementBrush == mode ? Style.brown : .black.opacity(0.5),
                                                in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(refinementBrush == mode ? .isSelected : [])
                            if mode == .add { Spacer().frame(width: 16) }
                        }
                        Spacer(minLength: 8)
                        Button { engine.undoRefinementStroke() } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 35, height: 35)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!engine.canUndoRefinement)
                        .opacity(engine.canUndoRefinement ? 1 : 0.55)
                        .accessibilityLabel("Undo brush stroke")
                    }
                    .padding(.horizontal, 43)

                    HStack(spacing: 6) {
                        Text("Brush size")
                            .font(.system(size: 13, weight: .semibold))
                            .fixedSize()
                        Slider(value: $refinementBrushSize, in: 10...64)
                            .tint(Style.brown)
                            .accessibilityLabel("Brush size")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 43)
                    .padding(.top, 30)
                    .padding(.bottom, 83)
                }
                if engine.isWorking {
                    ProgressView("Making your sticker…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

}

struct RefinementCanvas: View {
    @ObservedObject var engine: ScanEngine
    let brush: RefinementBrush
    let brushSize: Double
    @State private var previousPoint: CGPoint?
    @State private var zoomScale: CGFloat = 1
    @State private var pinchStartScale: CGFloat = 1
    @State private var isPinching = false

    var body: some View {
        GeometryReader { geometry in
            if let source = engine.refinementSource {
                ZStack {
                    ZStack {
                        Image(uiImage: source)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        if let highlight = engine.refinementHighlight {
                            Image(uiImage: highlight)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(zoomScale)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 8).onChanged { gesture in
                    guard !isPinching else { return }
                    guard gesture.startLocation.y >= Style.refinementProtectedTopHeight else { return }
                    let point = CGPoint(x: min(max(gesture.location.x, 0), geometry.size.width),
                                        y: min(max(gesture.location.y, 0), geometry.size.height))
                    guard point.y >= Style.refinementProtectedTopHeight else {
                        previousPoint = nil
                        return
                    }
                    if previousPoint == nil { engine.beginRefinementStroke() }
                    engine.paintRefinement(from: previousPoint ?? point, to: point,
                                           canvasSize: geometry.size, brushSize: brushSize,
                                           protectedTopHeight: Style.refinementProtectedTopHeight,
                                           zoomScale: zoomScale,
                                           adding: brush == .add)
                    previousPoint = point
                }.onEnded { _ in previousPoint = nil })
                .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                    guard !isPinching,
                          tap.location.y >= Style.refinementProtectedTopHeight else { return }
                    engine.beginRefinementStroke()
                    engine.paintRefinement(from: tap.location, to: tap.location,
                                           canvasSize: geometry.size, brushSize: brushSize,
                                           protectedTopHeight: Style.refinementProtectedTopHeight,
                                           zoomScale: zoomScale,
                                           adding: brush == .add)
                })
                .simultaneousGesture(MagnificationGesture().onChanged { magnification in
                    if !isPinching {
                        isPinching = true
                        pinchStartScale = zoomScale
                        previousPoint = nil
                    }
                    zoomScale = min(max(pinchStartScale * magnification, 1), 4)
                }.onEnded { _ in
                    isPinching = false
                    previousPoint = nil
                })
                .accessibilityLabel("Detected object mask. Drag to \(brush == .add ? "add" : "erase") highlighted areas.")
            }
        }
    }
}

