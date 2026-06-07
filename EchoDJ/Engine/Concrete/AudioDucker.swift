import Foundation
import AVFoundation

actor AudioDucker {
    private var player: AVAudioPlayer?
    private var duckTask: Task<Void, Never>?

    func duckPlayback(duration: TimeInterval) async {
        duckTask?.cancel()
        print("AudioDucker: Ducking playback for \(duration)s")
    }

    func restorePlayback() async {
        duckTask?.cancel()
        print("AudioDucker: Restoring playback volume")
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
            print("AudioDucker: Failed to play transition \(error)")
        }
    }
}
