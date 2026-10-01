import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var photos: [UIImage?] = [nil, nil]
    @State private var uploadDates: [Date?] = [nil, nil]
    @State private var selectedSlot = 0
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showLibrary = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                photoSlot(0)
                photoSlot(1)
            }
            .padding()
            .navigationTitle("My Photos")
            .photosPicker(
                isPresented: $showLibrary,
                selection: $selectedPhoto,
                matching: .images
            )
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photos[selectedSlot] = image
                        uploadDates[selectedSlot] = Date()
                    }
                    selectedPhoto = nil
                }
            }
        }
    }

    @ViewBuilder
    private func photoSlot(_ index: Int) -> some View {
        if let photo = photos[index], let date = uploadDates[index] {
            NavigationLink(destination: PhotoDetailView(photo: photo, uploadDate: date)) {
                VStack {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    Text("Photo \(index + 1) — Tap to view")
                        .font(.headline)
                }
                .foregroundStyle(.primary)
            }
        } else {
            Button {
                selectedSlot = index
                showLibrary = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 44))
                    Text("Add Photo \(index + 1)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

struct PhotoDetailView: View {
    let photo: UIImage
    let uploadDate: Date

    var body: some View {
        VStack(spacing: 24) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Text("Uploaded \(uploadDate.formatted(date: .abbreviated, time: .standard))")

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("\(Int(context.date.timeIntervalSince(uploadDate))) seconds ago")
                    .font(.title2.bold())
            }
        }
        .padding()
        .navigationTitle("Photo Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
