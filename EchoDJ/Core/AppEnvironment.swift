import Foundation
import SwiftData
import MusicKit

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    @Published var isSimulatorMode: Bool = false
    @Published var musicProvider: any MusicProviderProtocol
    @Published var djBrain: any DJBrainProtocol
    let modelContainer: ModelContainer
    var queueManager: StationQueueManager
    var telemetryCollector: TelemetryCollector
    var transitionManager: TransitionManager
    let subscriptionManager: SubscriptionManager

    private init() {
        self.isSimulatorMode = isSimulatorBuild()

        do {
            let schema = Schema([
                UserTasteProfile.self,
                TrackCooldown.self,
                CachedTrack.self,
                StationSession.self
            ])
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [cloudConfig]
            )
            print("AppEnvironment: SwiftData initialized with CloudKit sync")
        } catch {
            fatalError("Failed to initialize SwiftData Container: \(error)")
        }

        let provider = makeMusicProvider()
        self.musicProvider = provider

        let brain = makeDJBrain()
        self.djBrain = brain

        self.queueManager = StationQueueManager(
            modelContainer: self.modelContainer,
            provider: provider
        )
        self.telemetryCollector = TelemetryCollector(
            provider: provider,
            modelContainer: self.modelContainer
        )
        self.transitionManager = makeTransitionManager(brain: brain)
        self.subscriptionManager = SubscriptionManager()

        Task {
            await resolveCapabilities()
        }
    }

    func resolveCapabilities() async {
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
            print("AppEnvironment: AppleMusicProvider active")
        } else {
            print("AppEnvironment: AppleMusicProvider not authorized — using current provider")
        }

        let candidate = OnDeviceDJBrain()
        if await candidate.isAvailable {
            self.djBrain = candidate
            self.transitionManager = makeTransitionManager(brain: candidate)
            print("AppEnvironment: OnDeviceDJBrain active")
        } else {
            print("AppEnvironment: OnDeviceDJBrain unavailable — using current brain")
        }
    }
}

private func isSimulatorBuild() -> Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
}

private func makeMusicProvider() -> any MusicProviderProtocol {
    #if targetEnvironment(simulator)
    return SimulatorMusicProvider()
    #else
    return AppleMusicProvider()
    #endif
}

private func makeDJBrain() -> any DJBrainProtocol {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
        return OnDeviceDJBrain()
    }
    #endif
    #if targetEnvironment(simulator)
    return FallbackDJBrain()
    #else
    return OnDeviceDJBrain()
    #endif
}

private func makeTransitionManager(brain: any DJBrainProtocol) -> TransitionManager {
    TransitionManager(
        djBrain: brain,
        ttsClient: TTSClient(),
        audioDucker: AudioDucker()
    )
}
