import SwiftUI

struct VibeVisualizer: View {
    let energy: Double
    let valence: Double

    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [Float(valence), Float(energy)], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    .purple.opacity(0.4), .blue.opacity(valence), .indigo.opacity(0.3),
                    .cyan.opacity(0.4), .orange.opacity(energy), .pink.opacity(0.5),
                    .black, .clear, .black
                ]
            )
            .blur(radius: 10)
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color.blue.opacity(valence),
                    Color.red.opacity(energy)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
