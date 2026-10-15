import SwiftUI
import Photos
import PhotosUI
import Combine

@MainActor
final class PhotoLibrary: NSObject, ObservableObject {
    @Published var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    func refreshAccess() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccess() {
        Task {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = PhotoLibrary()
    @State private var tripItems: [PhotosPickerItem] = []
    @State private var dinnerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Group {
                switch library.status {
                case .authorized, .limited:
                    eventList
                case .notDetermined:
                    permissionView
                default:
                    deniedView
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { library.refreshAccess() }
        }
    }

    private var eventList: some View {
        ScrollView {
            VStack(spacing: 20) {
                EventCard(
                    title: "Boston Trip",
                    selection: $tripItems
                )

                EventCard(
                    title: "Birthday Dinner",
                    selection: $dinnerItems
                )
            }
            .padding()
        }
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
            Text("Connect your photo library")
                .font(.title3.bold())
            Text("Allow access, then add photos to two events.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Allow Photo Access") { library.requestAccess() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("Photo Access Needed", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("Enable photo access in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

struct EventCard: View {
    let title: String
    @Binding var selection: [PhotosPickerItem]
    @State private var pickedImages: [UIImage] = []
    @State private var captionedImages: [UIImage] = []
    @State private var selectedIndex = 0
    @State private var showingPhoto = false
    @State private var showingEvent = false
    @State private var caption = ""
    @State private var isSaving = false
    @State private var showingSaveError = false
    @State private var saveError = ""

    private var images: [UIImage] { pickedImages + captionedImages }
    var body: some View {
        Button { showingEvent = true } label: { previewCard }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $showingEvent) { eventPage }
        .onChange(of: selection) { _, newItems in
            load(newItems)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                let width = (geometry.size.width - 8) / 3
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { slot in
                        let index = images.count - min(images.count, 3) + slot
                        Group {
                            if index < images.count {
                                Image(uiImage: images[index])
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color.gray.opacity(0.12)
                                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                            }
                        }
                        .frame(width: width, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(height: 96)
        }
        .padding()
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var eventPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PhotosPicker(selection: $selection, maxSelectionCount: 12, matching: .images) {
                    Label("Add Photos", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                if images.isEmpty {
                    ContentUnavailableView("No photos yet", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                        ForEach(images.indices, id: \.self) { index in
                            Button {
                                selectedIndex = index
                                showingPhoto = true
                            } label: {
                                Image(uiImage: images[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 110)
                                    .clipped()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .fullScreenCover(isPresented: $showingPhoto) { photoViewer }
    }

    private var photoViewer: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("\(selectedIndex + 1) / \(images.count)")
                    Spacer()
                    Button("Done") { showingPhoto = false }
                }
                .foregroundStyle(.white)
                .padding()

                TabView(selection: $selectedIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        captionPreview(images[index], at: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 12) {
                    TextField("Write a caption", text: $caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .submitLabel(.done)
                    Button(isSaving ? "Saving…" : "Save to Photos") { saveCaptionedPhoto() }
                        .buttonStyle(.borderedProminent)
                        .disabled(caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
                .padding()
            }
        }
        .onChange(of: selectedIndex) { _, _ in caption = "" }
        .onChange(of: caption) { _, newValue in
            if newValue.count > 100 { caption = String(newValue.prefix(100)) }
        }
        .alert("Could not save photo", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError)
        }
    }

    private func captionPreview(_ image: UIImage, at index: Int) -> some View {
        GeometryReader { geometry in
            let imageRatio = image.size.width / max(image.size.height, 1)
            let viewRatio = geometry.size.width / max(geometry.size.height, 1)
            let width = imageRatio > viewRatio ? geometry.size.width : geometry.size.height * imageRatio
            let height = imageRatio > viewRatio ? geometry.size.width / imageRatio : geometry.size.height

            ZStack(alignment: .bottom) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                if index == selectedIndex && !caption.isEmpty {
                    Text(caption)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.65))
                }
            }
            .frame(width: width, height: height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    private func load(_ items: [PhotosPickerItem]) {
        Task {
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image)
                }
            }
            pickedImages = loaded
        }
    }

    private func saveCaptionedPhoto() {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, images.indices.contains(selectedIndex) else { return }
        let result = renderCaption(text, on: images[selectedIndex])
        isSaving = true
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: result)
                }
                captionedImages.append(result)
                caption = ""
                showingPhoto = false
            } catch {
                saveError = error.localizedDescription
                showingSaveError = true
            }
            isSaving = false
        }
    }

    private func renderCaption(_ text: String, on image: UIImage) -> UIImage {
        let size = image.size
        let padding = max(16, size.width * 0.04)
        let font = UIFont.boldSystemFont(ofSize: max(18, min(size.width * 0.05, size.height * 0.08)))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let textWidth = size.width - padding * 2
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: textWidth, height: size.height * 0.4),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let barHeight = min(size.height, ceil(bounds.height) + padding * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
            UIColor.black.withAlphaComponent(0.65).setFill()
            context.fill(CGRect(x: 0, y: size.height - barHeight, width: size.width, height: barHeight))
            (text as NSString).draw(
                in: CGRect(x: padding, y: size.height - barHeight + padding,
                           width: textWidth, height: barHeight - padding * 2),
                withAttributes: attributes
            )
        }
    }

}

#Preview { ContentView() }

#Preview("Event photos") {
    NavigationStack {
        EventCard(title: "Boston Trip", selection: .constant([]))
            .padding()
    }
}
