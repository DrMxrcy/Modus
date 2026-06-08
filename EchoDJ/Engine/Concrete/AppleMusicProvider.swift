import Foundation
import MusicKit
import MediaPlayer
import OSLog

private let logger = Logger(subsystem: "app.echodj", category: "AppleMusicProvider")

actor AppleMusicProvider: MusicProviderProtocol {

    var isAvailable: Bool {
        MusicAuthorization.currentStatus == .authorized
    }

    var isPlaying: Bool {
        ApplicationMusicPlayer.shared.state.playbackStatus == .playing
    }

    var currentTrackID: String? {
        loadedTrackID
    }

    var currentPlaybackProgress: Double {
        guard loadedDuration > 0 else { return 0.0 }
        return ApplicationMusicPlayer.shared.playbackTime / loadedDuration
    }

    var playbackDuration: Double {
        loadedDuration
    }

    private var loadedTrackID: String?
    private var loadedDuration: TimeInterval = 0.0
    private var loadedTitle: String = ""
    private var loadedArtist: String = ""
    private var loadedAlbum: String = ""

    init() {
        Task {
            await configureRemoteCommands()
        }
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { try await self.play() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { await self.pause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { try await self.skipNext() }
            return .success
        }
    }

    func loadTrack(id: String) async throws {
        var request = MusicCatalogSearchRequest(term: id, types: [Song.self])
        request.limit = 10
        let response: MusicCatalogSearchResponse
        do {
            response = try await request.response()
        } catch {
            logger.error("loadTrack catalog search failed: \(error.localizedDescription, privacy: .public)")
            throw AppleMusicError.trackNotFound
        }
        guard let song = response.songs.first(where: { $0.id.rawValue == id }) ?? response.songs.first else {
            throw AppleMusicError.trackNotFound
        }

        self.loadedTrackID = song.id.rawValue
        self.loadedTitle = song.title
        self.loadedArtist = song.artistName
        self.loadedAlbum = song.albumTitle ?? ""
        self.loadedDuration = song.duration ?? 240.0

        ApplicationMusicPlayer.shared.queue = [song]
        updateNowPlayingInfo()
    }

    func play() async throws {
        try await ApplicationMusicPlayer.shared.play()
        updateNowPlayingInfo()
    }

    func pause() async {
        ApplicationMusicPlayer.shared.pause()
        updateNowPlayingInfo()
    }

    func skipNext() async throws {
        let finalProgress = currentPlaybackProgress
        _ = loadedTrackID ?? "Unknown"

        logger.debug("skip track at progress \(finalProgress, privacy: .public)")

        ApplicationMusicPlayer.shared.stop()
        loadedTrackID = nil
        loadedDuration = 0.0
        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let trackID = loadedTrackID, !trackID.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyTitle] = loadedTitle
            nowPlayingInfo[MPMediaItemPropertyArtist] = loadedArtist
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = loadedAlbum
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = loadedDuration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = ApplicationMusicPlayer.shared.playbackTime
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

enum AppleMusicError: Error {
    case trackNotFound
}
