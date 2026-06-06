import Foundation
import SwiftData
import MusicKit

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    @Published var isMockMode: Bool = true
    @Published var musicProvider: any MusicProviderProtocol
    @Published var djBrain: any DJBrainProtocol
    let modelContainer: ModelContainer

    private init() {
        let useMock = true
        self.isMockMode = useMock

        do {
            let schema = Schema([
                UserTasteProfile.self,
                TrackCooldown.self,
                CachedTrack.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to initialize SwiftData Container: \(error)")
        }

        self.musicProvider = MockMusicProvider()
        self.djBrain = MockDJBrain()

        if !useMock {
            Task {
                await resolveProviders()
            }
        }
    }

    func resolveProviders() async {
        let realProvider = AppleMusicProvider()
        if await realProvider.isAvailable {
            self.musicProvider = realProvider
            print("AppEnvironment: Using AppleMusicProvider")
        } else {
            self.musicProvider = MockMusicProvider()
            print("AppEnvironment: MusicKit unavailable, falling back to MockMusicProvider")
        }
    }
}
