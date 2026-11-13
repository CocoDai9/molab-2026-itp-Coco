import AVFoundation
import PhotosUI
import SwiftUI

enum EditorPanel: String {
    case filter = "Filter"
    case stretch = "Stretch"
    case effect = "Effect"
    case stroke = "Stroke"
}


extension ContentView {
    var editScreen: some View {
        GeometryReader { geometry in
            let panelHeight: CGFloat = editorPanel == .stroke ? 354 : editorPanel == .effect ? 300 : 250
            let topGap: CGFloat = editorPanel == .stroke ? 35 : 55
            let previewHeight = min(382, max(160, geometry.size.height - 104 - topGap - panelHeight - 8))
            VStack(spacing: 0) {
                HStack {
                    Button { engine.closeStickerEditor() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 36)
                    }
                    Spacer()
                    Text("Edit sticker")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button("Save") { engine.savePNG() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 63, height: 32)
                        .background(Style.brown, in: RoundedRectangle(cornerRadius: 10))
                        .disabled(engine.isRenderingFilter || engine.editedImage == nil)
                        .opacity(engine.isRenderingFilter || engine.editedImage == nil ? 0.55 : 1)
                }
                .foregroundStyle(Style.ink)
                .padding(.leading, 16)
                .padding(.trailing, 24)
                .padding(.bottom, 7)
                .frame(height: 104, alignment: .bottom)

                Spacer().frame(height: topGap)

                ZStack {
                    EditorCheckerboard()
                    if let image = engine.editedImage ?? engine.cutoutImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(21)
                            .scaleEffect(x: engine.stretchWidth, y: engine.stretchHeight)
                            .scaleEffect(editorZoomScale)
                    }
                    if engine.isRenderingFilter {
                        ProgressView()
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                }
                .frame(height: previewHeight)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Style.brown.opacity(0.2), lineWidth: 1))
                .contentShape(Rectangle())
                .gesture(MagnificationGesture().onChanged { amount in
                    if !editorIsPinching {
                        editorIsPinching = true
                        editorPinchStartScale = editorZoomScale
                    }
                    editorZoomScale = min(max(editorPinchStartScale * amount, 1), 4)
                }.onEnded { _ in editorIsPinching = false })
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    Rectangle().fill(Style.brown.opacity(0.15))
                        .frame(height: 1)
                        .padding(.horizontal, 24)

                    HStack(spacing: 0) {
                        ForEach(["Filter", "Stretch", "Effect", "Stroke"], id: \.self) { tab in
                            Button {
                                editorPanel = EditorPanel(rawValue: tab) ?? .filter
                            } label: {
                                VStack(spacing: 8) {
                                    Text(tab)
                                        .font(.system(size: 14, weight: editorPanel.rawValue == tab ? .semibold : .medium))
                                        .foregroundStyle(editorPanel.rawValue == tab ? Style.brown : Style.editorMuted)
                                    Capsule()
                                        .fill(editorPanel.rawValue == tab ? Style.brown : .clear)
                                        .frame(width: 36, height: 3)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(editorPanel.rawValue == tab ? .isSelected : [])
                        }
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 24)

                    HStack {
                        Text(editorPanel == .filter ? "FILTERS" : editorPanel == .stretch ? "STRETCH" : editorPanel == .effect ? "EFFECTS" : "STROKE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Style.brown)
                        Spacer()
                        if editorPanel == .filter {
                            Text("8 looks  ·  swipe")
                                .font(.system(size: 11))
                                .foregroundStyle(Style.editorMuted)
                        } else if editorPanel == .effect {
                            Text("6 effects  ·  swipe")
                                .font(.system(size: 11))
                                .foregroundStyle(Style.editorMuted)
                        } else if editorPanel == .stretch {
                            Button("Reset") {
                                engine.stretchWidth = 1
                                engine.stretchHeight = 1
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Style.brown)
                            .accessibilityLabel("Reset sticker stretch")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 11)

                    if editorPanel == .filter {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StickerFilter.allCases) { filter in
                                    Button { engine.selectFilter(filter) } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(filterPreviewColor(filter))
                                                if let image = engine.filterPreviews[filter] ?? engine.cutoutImage {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .padding(4)
                                                }
                                            }
                                            .frame(width: 82, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(engine.selectedFilter == filter ? Style.brown : Style.brown.opacity(0.18),
                                                        lineWidth: engine.selectedFilter == filter ? 2 : 1))
                                            Text(filter.rawValue)
                                                .font(.system(size: 12, weight: engine.selectedFilter == filter ? .semibold : .regular))
                                                .foregroundStyle(engine.selectedFilter == filter ? Style.brown : Style.ink)
                                        }
                                        .frame(width: 82)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(engine.selectedFilter == filter ? .isSelected : [])
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 12)
                    } else if editorPanel == .stretch {
                        VStack(spacing: 12) {
                            StretchControl(title: "Width", value: $engine.stretchWidth)
                            StretchControl(title: "Height", value: $engine.stretchHeight)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        Text("100% = original size")
                            .font(.system(size: 11))
                            .foregroundStyle(Style.editorMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    } else if editorPanel == .effect {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StickerEffect.allCases) { effect in
                                    Button { engine.selectEffect(effect) } label: {
                                        VStack(spacing: 5) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(red: 0.94, green: 0.91, blue: 0.87))
                                                if let image = engine.effectPreviews[effect] ?? engine.cutoutImage {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .padding(4)
                                                }
                                            }
                                            .frame(width: 74, height: 62)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(engine.selectedEffect == effect ? Style.brown : Style.brown.opacity(0.18),
                                                        lineWidth: engine.selectedEffect == effect ? 2 : 1))
                                            Text(effect.rawValue)
                                                .font(.system(size: 10, weight: engine.selectedEffect == effect ? .semibold : .regular))
                                                .foregroundStyle(engine.selectedEffect == effect ? Style.brown : Style.ink)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                        }
                                        .frame(width: 80)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(engine.selectedEffect == effect ? .isSelected : [])
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 10)
                        EffectSlider(title: "Amount", value: Binding(
                            get: { engine.effectAmount }, set: { engine.setEffectAmount($0) }))
                            .disabled(engine.selectedEffect == .none)
                            .opacity(engine.selectedEffect == .none ? 0.45 : 1)
                            .padding(.horizontal, 24)
                            .padding(.top, 7)
                        EffectSlider(title: "Size", value: Binding(
                            get: { engine.effectSize }, set: { engine.setEffectSize($0) }))
                            .disabled(!engine.selectedEffect.hasSize)
                            .opacity(engine.selectedEffect.hasSize ? 1 : 0.45)
                            .padding(.horizontal, 24)
                    } else {
                        StrokeEditorPanel(engine: engine)
                            .padding(.top, 8)
                    }
                    Spacer(minLength: 16)
                }
                .frame(height: panelHeight)
                .background(Style.paper)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Style.paper.ignoresSafeArea())
        }
        .ignoresSafeArea()
    }

    func filterPreviewColor(_ filter: StickerFilter) -> Color {
        switch filter {
        case .original: Color(red: 0.96, green: 0.93, blue: 0.90)
        case .warm: Color(red: 0.92, green: 0.82, blue: 0.75)
        case .mono, .noir, .tonal: Color(red: 0.87, green: 0.86, blue: 0.85)
        case .vintage, .fade: Color(red: 0.91, green: 0.86, blue: 0.77)
        case .chrome: Color(red: 0.91, green: 0.90, blue: 0.86)
        }
    }
}

struct EffectSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 55, alignment: .leading)
            Slider(value: $value, in: 0...1)
                .tint(Style.brown)
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
        .foregroundStyle(Style.ink)
        .accessibilityElement(children: .combine)
    }
}

struct StretchControl: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Style.ink)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Style.brown)
            }
            .frame(height: 20)
            StretchScaleSlider(title: title, value: $value)
        }
    }
}

struct StretchScaleSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(1, geometry.size.width - 20)
            let centerX = geometry.size.width / 2
            let thumbX = 10 + trackWidth * (value - 0.5)
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color(red: 0.85, green: 0.82, blue: 0.78))
                    .frame(width: trackWidth, height: 4)
                    .position(x: centerX, y: 13)
                Capsule()
                    .fill(Style.brown)
                    .frame(width: abs(thumbX - centerX), height: 4)
                    .position(x: (thumbX + centerX) / 2, y: 13)
                Capsule()
                    .fill(Style.editorMuted)
                    .frame(width: 2, height: 14)
                    .position(x: centerX, y: 13)
                Circle()
                    .fill(Style.brown)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Style.paper, lineWidth: 2))
                    .position(x: thumbX, y: 13)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                value = min(1.5, max(0.5, 0.5 + (gesture.location.x - 10) / trackWidth))
            })
        }
        .frame(height: 26)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) stretch")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1.5, value + 0.05)
            case .decrement: value = max(0.5, value - 0.05)
            @unknown default: break
            }
        }
    }
}

struct EditorCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 36
            for y in 0...Int(ceil(size.height / tile)) {
                for x in 0...Int(ceil(size.width / tile)) where (x + y).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(x) * tile, y: CGFloat(y) * tile,
                                             width: tile, height: tile)),
                                 with: .color(Color(red: 0.93, green: 0.92, blue: 0.90)))
                }
            }
        }
        .background(Color(red: 0.985, green: 0.98, blue: 0.969))
    }
}

