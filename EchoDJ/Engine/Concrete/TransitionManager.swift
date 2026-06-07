import Foundation
import SwiftData

actor TransitionManager {
    private let djBrain: any DJBrainProtocol
    private let ttsClient: TTSClient
    private let audioDucker: AudioDucker

    private var nextTransitionURL: URL?

    init(djBrain: any DJBrainProtocol, ttsClient: TTSClient, audioDucker: AudioDucker) {
        self.djBrain = djBrain
        self.ttsClient = ttsClient
        self.audioDucker = audioDucker
    }

    func preRenderTransition(
        lastTrack: CachedTrack,
        nextTrack: CachedTrack,
        moodContext: String,
        bpm: Double
    ) async {
        let meta = TransitionMetadata(
            lastTrackTitle: lastTrack.title,
            lastTrackArtist: lastTrack.artistName,
            nextTrackTitle: nextTrack.title,
            nextTrackArtist: nextTrack.artistName,
            userMoodContext: moodContext,
            currentBPM: bpm
        )

        let script = await djBrain.generateTransition(meta: meta)
        print("TransitionManager: Pre-rendered script: \(script)")

        if let url = await ttsClient.synthesize(text: script) {
            self.nextTransitionURL = url
            print("TransitionManager: TTS cached at \(url)")
        } else {
            self.nextTransitionURL = nil
            print("TransitionManager: TTS unavailable, will skip transition")
        }
    }

    func executeTransition() async {
        guard let url = nextTransitionURL else {
            print("TransitionManager: No transition to play")
            return
        }

        await audioDucker.duckPlayback(duration: 5.0)
        await audioDucker.playTransition(url: url)
        await audioDucker.restorePlayback()

        nextTransitionURL = nil
    }

    func clearPendingTransition() {
        nextTransitionURL = nil
    }
}
