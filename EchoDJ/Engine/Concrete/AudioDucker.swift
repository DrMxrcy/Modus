import Foundation
import AVFoundation
import OSLog

private let logger = Logger(subsystem: "app.echodj", category: "AudioDucker")

actor AudioDucker {
    private var player: AVAudioPlayer?
    private var duckTask: Task<Void, Never>?

    func duckPlayback(duration: TimeInterval) async {
        duckTask?.cancel()
        logger.debug("Ducking playback for \(duration, privacy: .public)s")
    }

    func restorePlayback() async {
        duckTask?.cancel()
        logger.debug("Restoring playback volume")
    }

    func playTransition(url: URL) async {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            self.player = player
            player.prepareToPlay()
            player.play()

            while player.isPlaying {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        } catch {
            logger.error("Failed to play transition: \(error.localizedDescription, privacy: .public)")
        }
    }
}
