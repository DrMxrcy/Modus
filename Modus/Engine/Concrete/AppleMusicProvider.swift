import Foundation
import MusicKit
import MediaPlayer
import SwiftData
import OSLog

private let logger = Logger(subsystem: "app.modus", category: "AppleMusicProvider")

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

    var currentTitle: String {
        loadedTitle
    }

    var currentArtist: String {
        loadedArtist
    }

    var currentArtworkURL: URL? {
        loadedArtwork?.url(width: 600, height: 600)
    }

    private var loadedTrackID: String?
    private var loadedDuration: TimeInterval = 0.0
    private var loadedTitle: String = ""
    private var loadedArtist: String = ""
    private var loadedAlbum: String = ""
    private var loadedArtwork: Artwork?
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
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
        guard MusicAuthorization.currentStatus == .authorized else {
            logger.error("loadTrack requires Apple Music authorization (status=\(String(describing: MusicAuthorization.currentStatus), privacy: .public))")
            throw AppleMusicError.authRequired
        }

        // Seed-library tracks use synthetic IDs ("1", "2"…). Real MusicKit catalog
        // IDs are longer alphanumeric strings. Skip the ID-as-search-term path for
        // synthetic IDs and go straight to title+artist lookup to avoid wrong results.
        let isSyntheticID = id.count < 8

        if !isSyntheticID {
            var request = MusicCatalogSearchRequest(term: id, types: [Song.self])
            request.limit = 10
            do {
                let response = try await request.response()
                if let song = response.songs.first(where: { $0.id.rawValue == id }) ?? response.songs.first {
                    await applySong(song)
                    return
                }
            } catch {
                logger.error("loadTrack catalog search by ID failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Primary path for synthetic seeds: look up cached metadata and search by title + artist
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedTrack>(
            predicate: #Predicate { $0.trackID == id }
        )
        if let cached = (try? context.fetch(descriptor))?.first {
            let term = "\(cached.title) \(cached.artistName)"
            var fallbackRequest = MusicCatalogSearchRequest(term: term, types: [Song.self])
            fallbackRequest.limit = 10
            do {
                let response = try await fallbackRequest.response()
                if let song = response.songs.first {
                    await applySong(song)
                    return
                }
            } catch {
                logger.error("loadTrack fallback search failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        throw AppleMusicError.trackNotFound
    }

    private func applySong(_ song: Song) async {
        self.loadedTrackID = song.id.rawValue
        self.loadedTitle = song.title
        self.loadedArtist = song.artistName
        self.loadedAlbum = song.albumTitle ?? ""
        self.loadedDuration = song.duration ?? 240.0
        self.loadedArtwork = song.artwork

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
        loadedTitle = ""
        loadedArtist = ""
        loadedAlbum = ""
        loadedArtwork = nil
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

enum AppleMusicError: Error, LocalizedError {
    case trackNotFound
    case authRequired

    var errorDescription: String? {
        switch self {
        case .trackNotFound:
            return "Could not find this track in Apple Music. Try a different song or check your Apple Music subscription."
        case .authRequired:
            return "Apple Music access is required to play this track. Connect Apple Music in onboarding or Settings."
        }
    }
}
