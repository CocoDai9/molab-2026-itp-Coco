import AVFoundation
import PhotosUI
import SwiftUI

struct ContentView: View {
    @StateObject var engine = ScanEngine()
    @State var importedPhoto: PhotosPickerItem?
    @State var showingIntro = false
    @State var refinementBrush: RefinementBrush = .add
    @State var refinementBrushSize = 28.0
    @State var editorZoomScale: CGFloat = 1
    @State var editorPinchStartScale: CGFloat = 1
    @State var editorIsPinching = false
    @State var editorPanel: EditorPanel = .filter

    var body: some View {
        Group {
            switch engine.step {
            case .camera: scanScreen(adjusting: false)
            case .adjust: scanScreen(adjusting: true)
            case .refine: refineScreen
            case .result: resultScreen
            case .edit: editScreen
            }
        }
        .preferredColorScheme(engine.step == .result || engine.step == .edit ? .light : .dark)
        .onAppear {
            engine.start()
            engine.refreshGalleryThumbnail()
        }
        .onDisappear { engine.stop() }
        .onChange(of: importedPhoto) { _, photo in
            guard let photo else { return }
            Task {
                if let data = try? await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    engine.importImage(image)
                }
            }
        }
        .alert("Sticker", isPresented: Binding(get: { engine.message != nil }, set: { if !$0 { engine.clearMessage() } })) {
            Button("OK") { engine.clearMessage() }
        } message: { Text(engine.message ?? "") }
        .fullScreenCover(isPresented: $showingIntro) {
            ZStack {
                Style.paper.ignoresSafeArea()
                VStack(spacing: 18) {
                    Text("Sticker").font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("Scan a little thing.").font(.system(size: 25, weight: .semibold))
                    Text("Find it, cut it out, keep it.").foregroundStyle(Style.muted)
                    Button("Start scanning") { showingIntro = false }
                        .buttonStyle(BrownButton()).padding(.top, 26)
                }
                .padding(32)
                .foregroundStyle(Style.brown)
            }
            .preferredColorScheme(.light)
        }
    }

}
