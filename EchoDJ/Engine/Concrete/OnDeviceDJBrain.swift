import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
actor OnDeviceDJBrain: DJBrainProtocol {
    private var modelSession: LanguageModelSession?

    var isAvailable: Bool { modelSession != nil }

    init() {
        let availability = SystemLanguageModel.default.availability
        let available = availability == .available

        if available {
            self.modelSession = LanguageModelSession(
                instructions: """
                You are 'Echo', an audio radio DJ companion. Your goal is to write conversational, brief segues between music tracks. Keep your responses under 15 words. Always reference the user's explicit listening mood vibe when transitioning.
                """
            )
            print("OnDeviceDJBrain: LanguageModelSession initialized")
        } else {
            self.modelSession = nil
            print("OnDeviceDJBrain: SystemLanguageModel unavailable (status: \(availability))")
        }
    }

    func generateTransition(meta: TransitionMetadata) async -> String {
        guard let session = modelSession else {
            return fallbackTransition(meta: meta)
        }

        let prompt = """
        User finished: \(meta.lastTrackTitle) by \(meta.lastTrackArtist).
        Next up: \(meta.nextTrackTitle) by \(meta.nextTrackArtist).
        Current Context: User is feeling \(meta.userMoodContext) traveling at \(Int(meta.currentBPM)) BPM.
        Compose a brief, witty transition script.
        """

        do {
            let response = try await session.respond(to: prompt)
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty {
                return fallbackTransition(meta: meta)
            }
            return content
        } catch {
            print("OnDeviceDJBrain: Inference error \(error)")
            return fallbackTransition(meta: meta)
        }
    }

    private func fallbackTransition(meta: TransitionMetadata) -> String {
        let fallbacks = [
            "Echo here. Next up: \(meta.nextTrackTitle). Let's keep the \(meta.userMoodContext) flowing.",
            "Transitioning into \(meta.nextTrackArtist) with that \(meta.userMoodContext) energy.",
            "Here's \(meta.nextTrackTitle). Match that \(meta.userMoodContext) vibe.",
            "Echo out. \(meta.nextTrackTitle) is next on the station.",
            "Keep it locked. \(meta.nextTrackTitle) up next at \(Int(meta.currentBPM)) BPM."
        ]
        return fallbacks.randomElement() ?? "Next up: \(meta.nextTrackTitle)."
    }

    func generateStationArc(
        seedTitle: String,
        seedArtist: String,
        userMoodContext: String,
        queueLength: Int
    ) async -> [StationArcTarget] {
        guard let session = modelSession else {
            return []
        }

        let prompt = """
        Seed track: \(seedTitle) by \(seedArtist).
        User mood: \(userMoodContext).
        Build a \(queueLength)-track station arc. Return ONLY a JSON array of objects with keys: position (0-based Int), targetEnergy (0.0-1.0), targetValence (0.0-1.0), targetBPM (60-200), weight (0.0-1.0). Do not include markdown or explanation.
        """

        do {
            let response = try await session.respond(to: prompt)
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = content.data(using: .utf8) else {
                return []
            }
            let decoded = try JSONDecoder().decode([StationArcTarget].self, from: data)
            return Array(decoded.prefix(queueLength))
        } catch {
            print("OnDeviceDJBrain: Arc generation error \(error)")
            return []
        }
    }
}

#else

actor OnDeviceDJBrain: DJBrainProtocol {
    var isAvailable: Bool { false }

    func generateTransition(meta: TransitionMetadata) async -> String {
        return "Echo here. Next up: \(meta.nextTrackTitle). Keep the \(meta.userMoodContext) flowing."
    }

    func generateStationArc(
        seedTitle: String,
        seedArtist: String,
        userMoodContext: String,
        queueLength: Int
    ) async -> [StationArcTarget] {
        return []
    }
}

#endif
