import AVFoundation
import PhotosUI
import SwiftUI

extension ContentView {
    var resultScreen: some View {
        GeometryReader { geometry in
            let previewSize = geometry.size.width - 86
            VStack(spacing: 0) {
                HStack {
                    Button { engine.edit() } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Button("Save") { engine.savePNG() }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Style.muted)
                .padding(.leading, 26)
                .padding(.trailing, 33)
                .padding(.top, 76)

                Spacer().frame(height: max(80, geometry.size.height * 0.13))
                Checkerboard()
                    .frame(width: previewSize, height: previewSize)
                    .overlay {
                        if let image = engine.cutoutImage {
                            Image(uiImage: image).resizable().scaledToFit().padding(30)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Style.brown.opacity(0.28), lineWidth: 0.8))
                Spacer().frame(height: 57)
                Button("Edit") {
                    editorPanel = .filter
                    engine.openStickerEditor()
                }
                    .buttonStyle(BrownButton())
                    .padding(.horizontal, 43)
                Button("Retake") { engine.retake() }
                    .font(.system(size: 16)).foregroundStyle(Style.muted)
                    .frame(height: 70)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Style.paper.ignoresSafeArea())
        }
        .ignoresSafeArea()
    }

}

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile = size.width / 7.4
            for y in 0...Int(ceil(size.height / tile)) {
                for x in 0...Int(ceil(size.width / tile)) where (x + y).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(x) * tile, y: CGFloat(y) * tile, width: tile, height: tile)),
                                 with: .color(Color(red: 0.90, green: 0.88, blue: 0.85)))
                }
            }
        }.background(.white)
    }
}

