import SwiftUI

struct StrokeEditorPanel: View {
    @ObservedObject var engine: ScanEngine

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(StickerStrokeSpacing.allCases, id: \.self) { spacing in
                    Button { engine.setStrokeSpacing(spacing) } label: {
                        Text(spacing.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(engine.strokeSpacing == spacing ? .white : Style.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(engine.strokeSpacing == spacing ? Style.brown : .white,
                                        in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(engine.strokeSpacing == spacing ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)
            .disabled(engine.strokeStyle == .none)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StickerStrokeStyle.allCases) { style in
                        Button { engine.selectStroke(style) } label: {
                            VStack(spacing: 4) {
                                StrokeStyleSwatch(style: style, color: engine.strokeColor)
                                    .frame(width: 72, height: 42)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9)
                                        .stroke(engine.strokeStyle == style ? Style.brown : Style.brown.opacity(0.18),
                                                lineWidth: engine.strokeStyle == style ? 2 : 1))
                                Text(style.rawValue)
                                    .font(.system(size: 11, weight: engine.strokeStyle == style ? .semibold : .regular))
                                    .foregroundStyle(engine.strokeStyle == style ? Style.brown : Style.ink)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(engine.strokeStyle == style ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 24)
            }

            EffectSlider(title: "Width", value: Binding(
                get: { engine.strokeWidth }, set: { engine.setStrokeWidth($0) }))
                .padding(.horizontal, 24)
                .disabled(engine.strokeStyle == .none)

            EffectSlider(title: "Gap", value: Binding(
                get: { engine.strokeGap }, set: { engine.setStrokeGap($0) }))
                .padding(.horizontal, 24)
                .disabled(engine.strokeStyle == .none || engine.strokeSpacing == .attached)
                .opacity(engine.strokeSpacing == .spaced ? 1 : 0.45)

            ColorPicker("Color", selection: Binding(
                get: { engine.strokeColor }, set: { engine.setStrokeColor($0) }),
                        supportsOpacity: false)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Style.ink)
                .padding(.horizontal, 24)
                .disabled(engine.strokeStyle == .none)
        }
    }
}

private struct StrokeStyleSwatch: View {
    let style: StickerStrokeStyle
    let color: Color

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .color(.white))
            if style == .none {
                var slash = Path()
                slash.move(to: CGPoint(x: 16, y: 31))
                slash.addLine(to: CGPoint(x: 56, y: 10))
                context.stroke(slash, with: .color(Style.editorMuted), lineWidth: 2)
                return
            }
            let band = Path(roundedRect: bounds.insetBy(dx: 7, dy: 8), cornerRadius: 6)
            context.fill(band, with: .color(color))
            switch style {
            case .crayon:
                for index in 0..<12 {
                    var mark = Path()
                    let x = CGFloat(index * 7)
                    mark.move(to: CGPoint(x: x, y: 10))
                    mark.addLine(to: CGPoint(x: x + 16, y: 31))
                    context.stroke(mark, with: .color(.white.opacity(index.isMultiple(of: 3) ? 0.55 : 0.22)), lineWidth: 1)
                }
            case .paper:
                for index in 0..<28 {
                    let x = CGFloat((index * 37) % 63 + 6)
                    let y = CGFloat((index * 19) % 24 + 8)
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                                 with: .color(.white.opacity(0.5)))
                }
            case .dots:
                for y in stride(from: 13, through: 29, by: 10) {
                    for x in stride(from: 13, through: 63, by: 11) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 4)),
                                     with: .color(.white))
                    }
                }
            case .plaid:
                for x in stride(from: 14, through: 68, by: 12) {
                    context.fill(Path(CGRect(x: x, y: 8, width: 2, height: 26)),
                                 with: .color(.white.opacity(0.55)))
                }
                for y in stride(from: 13, through: 30, by: 11) {
                    context.fill(Path(CGRect(x: 7, y: y, width: 58, height: 2)),
                                 with: .color(.white.opacity(0.55)))
                }
            case .foil:
                for index in 0..<8 {
                    let x = CGFloat(index * 11)
                    var shine = Path()
                    shine.move(to: CGPoint(x: x, y: 8))
                    shine.addLine(to: CGPoint(x: x + 15, y: 34))
                    context.stroke(shine, with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.7 : 0.25)), lineWidth: 2)
                }
            case .none, .solid: break
            }
        }
    }
}
