import SwiftUI
import Photos
import PhotosUI
import Combine

@MainActor
final class PhotoLibrary: NSObject, ObservableObject {
    @Published var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    func requestAccess() {
        Task {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
    }
}

struct ContentView: View {
    @StateObject private var library = PhotoLibrary()
    @AppStorage("showPhotoNumbers") private var showPhotoNumbers = true
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
    }

    private var eventList: some View {
        ScrollView {
            VStack(spacing: 20) {
                Toggle("Show Photo Numbers", isOn: $showPhotoNumbers)

                EventCard(
                    title: "Boston Trip",
                    showPhotoNumber: showPhotoNumbers,
                    selection: $tripItems
                )

                EventCard(
                    title: "Birthday Dinner",
                    showPhotoNumber: showPhotoNumbers,
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
    let showPhotoNumber: Bool
    @Binding var selection: [PhotosPickerItem]
    @State private var images: [UIImage] = []
    @State private var selectedIndex = 0
    @State private var showingPhoto = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    if showPhotoNumber {
                        Text("\(images.count) \(images.count == 1 ? "photo" : "photos")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                PhotosPicker(
                    selection: $selection,
                    maxSelectionCount: 12,
                    matching: .images
                ) {
                    Label("Add Photos", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if images.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.12))
                    .frame(height: 110)
                    .overlay {
                        Text("No photos yet")
                            .foregroundStyle(.secondary)
                    }
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(images.indices, id: \.self) { index in
                        Button {
                            selectedIndex = index
                            showingPhoto = true
                        } label: {
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: selection) { _, newItems in
            load(newItems)
        }
        .fullScreenCover(isPresented: $showingPhoto) {
            photoViewer
        }
    }

    private var photoViewer: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                Text("\(selectedIndex + 1) / \(images.count)")
                Spacer()
                Button("Done") { showingPhoto = false }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding()
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
            images = loaded
        }
    }
}

#Preview {
    ContentView()
}
