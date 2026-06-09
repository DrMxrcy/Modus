import Foundation
import SwiftData
import MusicKit
import OSLog

private let logger = Logger(subsystem: "app.modus", category: "MusicLibraryImporter")

/// Imports songs from the user's Apple Music library into the local SwiftData store as
/// `CachedTrack` seeds, replacing synthetic seed data with real MusicKit IDs.
actor MusicLibraryImporter {

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Imports the library only when the local store has no existing `CachedTrack` rows.
    ///
    /// - Returns: The number of tracks imported, or 0 if the import was skipped or failed.
    func importLibraryIfNeeded() async -> Int {
        let context = ModelContext(modelContainer)
        do {
            let existingCount = try context.fetchCount(FetchDescriptor<CachedTrack>())
            if existingCount > 0 {
                logger.info("MusicLibraryImporter: skipping import — \(existingCount) CachedTrack(s) already present")
                return 0
            }
        } catch {
            logger.error("MusicLibraryImporter: failed to fetch CachedTrack count — \(error)")
            return 0
        }
        return await importLibrary()
    }

    /// Fetches up to 200 songs from the user's Apple Music library and persists them as
    /// `CachedTrack` seeds using the existing `CachedTrack(from:)` convenience initializer.
    ///
    /// - Returns: The number of tracks successfully imported, or 0 on error.
    func importLibrary() async -> Int {
        let context = ModelContext(modelContainer)
        do {
            var request = MusicLibraryRequest<Song>()
            request.limit = 200
            let response = try await request.response()
            var importedCount = 0
            for song in response.items {
                guard let track = CachedTrack(from: song) else { continue }
                context.insert(track)
                importedCount += 1
            }
            do {
                try context.save()
                logger.info("MusicLibraryImporter: imported \(importedCount) track(s) from Apple Music library")
            } catch {
                logger.error("MusicLibraryImporter: failed to save imported tracks — \(error)")
            }
            return importedCount
        } catch {
            logger.error("MusicLibraryImporter: library request failed — \(error)")
            return 0
        }
    }
}
