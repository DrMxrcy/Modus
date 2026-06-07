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
    var queueManager: StationQueueManager
    var telemetryCollector: TelemetryCollector
    var transitionManager: TransitionManager

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

        let mockProvider = MockMusicProvider()
        self.musicProvider = mockProvider

        let brain = defaultDJBrain()
        self.djBrain = brain

        self.queueManager = StationQueueManager(
            modelContainer: self.modelContainer,
            provider: mockProvider
        )
        self.telemetryCollector = TelemetryCollector(
            provider: mockProvider,
            modelContainer: self.modelContainer
        )
        self.transitionManager = makeTransitionManager(brain: brain)

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
            self.queueManager = StationQueueManager(
                modelContainer: self.modelContainer,
                provider: realProvider
            )
            self.telemetryCollector = TelemetryCollector(
                provider: realProvider,
                modelContainer: self.modelContainer
            )
            print("AppEnvironment: Using AppleMusicProvider")
        } else {
            self.musicProvider = MockMusicProvider()
            self.queueManager = StationQueueManager(
                modelContainer: self.modelContainer,
                provider: MockMusicProvider()
            )
            self.telemetryCollector = TelemetryCollector(
                provider: MockMusicProvider(),
                modelContainer: self.modelContainer
            )
            print("AppEnvironment: MusicKit unavailable, falling back to MockMusicProvider")
        }

        let candidate = defaultDJBrain()
        if await candidate.isAvailable {
            self.djBrain = candidate
            self.transitionManager = makeTransitionManager(brain: candidate)
            print("AppEnvironment: Using OnDeviceDJBrain")
        } else {
            let fallback = MockDJBrain()
            self.djBrain = fallback
            self.transitionManager = makeTransitionManager(brain: fallback)
            print("AppEnvironment: Foundation Models unavailable, falling back to MockDJBrain")
        }
    }
}

private func defaultDJBrain() -> any DJBrainProtocol {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
        return OnDeviceDJBrain()
    }
    #endif
    return MockDJBrain()
}

private func makeTransitionManager(brain: any DJBrainProtocol) -> TransitionManager {
    TransitionManager(
        djBrain: brain,
        ttsClient: TTSClient(),
        audioDucker: AudioDucker()
    )
}
