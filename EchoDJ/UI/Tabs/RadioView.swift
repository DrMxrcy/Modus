import SwiftUI

struct RadioView: View {
    @ObservedObject var environment = AppEnvironment.shared
    @State private var valenceLevel: Double = 0.5
    @State private var energyLevel: Double = 0.5

    var body: some View {
        ZStack {
            VibeVisualizer(energy: energyLevel, valence: valenceLevel)

            VStack(spacing: 30) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .overlay(Text("Album Artwork Proxy"))

                VStack(spacing: 8) {
                    Text("Station Seed Title")
                        .font(.title2.bold())
                    Text("Echo DJ Station Active")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("VIBE TUNER: \(Int(valenceLevel * 100))%")
                        .font(.caption.bold())
                    Slider(value: $valenceLevel, in: 0...1) { _ in
                        // Slider interaction
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal)

                HCenterControlsView()
            }
        }
    }
}

struct HCenterControlsView: View {
    var body: some View {
        HStack(spacing: 50) {
            Button(action: { print("Hard Skip Triggered") }) {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.title)
            }
            Button(action: { print("Play/Pause Toggle") }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 64))
            }
            Button(action: { print("Soft Skip Triggered") }) {
                Image(systemName: "goforward.10")
                    .font(.title)
            }
        }
        .foregroundStyle(.primary)
    }
}
