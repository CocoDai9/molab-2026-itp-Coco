import SwiftUI
import AudioToolbox

struct Mode: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let soundID: SystemSoundID
}

struct ContentView: View {
    let modes = [
        Mode(name: "Work", icon: "laptopcomputer", color: .blue, soundID: 1005),
        Mode(name: "Gym", icon: "figure.strengthtraining.traditional", color: .orange, soundID: 1022),
        Mode(name: "Sleep", icon: "moon.fill", color: .purple, soundID: 1103)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pick a Mode")
                    .font(.largeTitle.bold())

                Text("Choose a sound for your moment")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)

                ForEach(modes) { mode in
                    NavigationLink {
                        PlayerView(mode: mode)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundStyle(mode.color)
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Circle()
                                        .stroke(mode.color, lineWidth: 2)
                                }

                            Text(mode.name)
                                .font(.title2.bold())

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct PlayerView: View {
    let mode: Mode
    @State private var playCount = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: mode.icon)
                .font(.system(size: 72))
                .foregroundStyle(mode.color)
                .frame(width: 160, height: 160)
                .overlay {
                    Circle()
                        .stroke(mode.color, lineWidth: 3)
                }

            Text(mode.name)
                .font(.largeTitle.bold())

            Button {
                AudioServicesPlaySystemSound(mode.soundID)
                playCount += 1
            } label: {
                Label("Play Sound", systemImage: "play.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(mode.color)

            Text("Played \(playCount) times")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle(mode.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
