import Foundation
import SwiftData
import OSLog

actor TransitionManager {
    private let djBrain: any DJBrainProtocol
    private let ttsClient: TTSClient
    private let audioDucker: AudioDucker

    private var nextTransitionURL: URL?

    private static let logger = Logger(subsystem: "app.modus", category: "TransitionManager")

    init(djBrain: any DJBrainProtocol, ttsClient: TTSClient, audioDucker: AudioDucker) {
        self.djBrain = djBrain
        self.ttsClient = ttsClient
        self.audioDucker = audioDucker
    }

    func preRenderTransition(
        lastTrack: CachedTrack,
        nextTrack: CachedTrack,
        moodContext: String,
        bpm: Double,
        isPro: Bool = true
    ) async {
        guard isPro else {
            Self.logger.debug("preRenderTransition skipped (Free tier)")
            nextTransitionURL = nil
            return
        }

        let meta = TransitionMetadata(
            lastTrackTitle: lastTrack.title,
            lastTrackArtist: lastTrack.artistName,
            nextTrackTitle: nextTrack.title,
            nextTrackArtist: nextTrack.artistName,
            userMoodContext: moodContext,
            currentBPM: bpm
        )

        let script = await djBrain.generateTransition(meta: meta)
        // NOTE: do not log `script` — generated DJ transitions must not be written
        // to the system log (privacy + AI content rights, see docs/app-store/metadata.md).

        if let url = await ttsClient.synthesize(text: script) {
            self.nextTransitionURL = url
            Self.logger.debug("TTS cached")
        } else {
            self.nextTransitionURL = nil
            Self.logger.debug("TTS unavailable, will skip transition")
        }
    }

    func executeTransition(isEnabled: Bool = true) async {
        guard isEnabled else {
            Self.logger.debug("DJ transitions disabled (Free tier)")
            return
        }
        guard let url = nextTransitionURL else {
            Self.logger.debug("No transition to play")
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
