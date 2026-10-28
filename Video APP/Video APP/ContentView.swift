import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = camera.previewImage {
                GeometryReader { geometry in
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else {
                Text(camera.message)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            VStack {
                HStack {
                    if camera.isRecording {
                        Text(String(format: "● REC %02d:%02d", camera.recordingSeconds / 60, camera.recordingSeconds % 60))
                            .font(.subheadline.monospacedDigit().bold())
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.red, in: Capsule())
                    }
                    Spacer()
                    Button {
                        camera.flipCamera()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title2)
                            Text(camera.isFrontCamera ? "Front" : "Back")
                                .font(.caption2)
                        }
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!camera.isReady || camera.isRecording)
                    .accessibilityLabel("Switch camera")
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Spacer()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(VideoFilter.allCases) { filter in
                            Button(filter.rawValue) {
                                camera.selectFilter(filter)
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(camera.selectedFilter == filter ? .blue : .black.opacity(0.6))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .foregroundStyle(.white)

                if camera.selectedFilter == .bloom {
                    HStack {
                        Text("Glow")
                        Slider(value: Binding(
                            get: { camera.bloomIntensity },
                            set: { camera.setBloomIntensity($0) }
                        ), in: 0...2)
                        Text(camera.bloomIntensity.formatted(.number.precision(.fractionLength(1))))
                            .monospacedDigit()
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                Button {
                    camera.toggleRecording()
                } label: {
                    Circle()
                        .fill(camera.isRecording ? .red : .white)
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(.white, lineWidth: 3).padding(-7))
                }
                .disabled(!camera.isReady)
                .padding(.top, 22)

                Text(camera.message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.top, 12)
            }
            .padding(.bottom, 30)
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}

#Preview {
    ContentView()
}
