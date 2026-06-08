import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels

private let logger = Logger(subsystem: "app.echodj", category: "OnDeviceDJBrain")

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
            logger.info("LanguageModelSession initialized")
        } else {
            self.modelSession = nil
            logger.info("SystemLanguageModel unavailable (status: \(String(describing: availability), privacy: .public))")
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
            if let sanitized = Self.sanitizeTransition(response.content) {
                return sanitized
            }
            return fallbackTransition(meta: meta)
        } catch {
            #if DEBUG
            print("OnDeviceDJBrain: Inference error \(error)")
            #endif
            return fallbackTransition(meta: meta)
        }
    }

    /// Sanitize a model-generated transition. Returns nil if the output is unsafe
    /// or unusable; callers should fall back to a curated template in that case.
    ///
    /// Rules (see `docs/app-store/metadata.md` AI-Generated Content disclosure):
    /// 1. Strip markdown formatting (asterisks, underscores, backticks, heading marks).
    /// 2. Reject multi-line responses (the prompt asks for a single brief segue).
    /// 3. Hard-cap at 15 words regardless of what the model emitted.
    /// 4. Reject responses that look like quoted lyrics (brackets, double-quoted
    ///    blocks, or lines beginning with "verse"/"chorus"/"bridge"/"intro"/"outro").
    /// 5. Reject if the response contains anything that looks like a URL.
    private static func sanitizeTransition(_ raw: String) -> String? {
        // Step 1: trim and strip markdown.
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let strippedChars: Set<Character> = ["*", "_", "`", "#", ">", "~"]
        text = String(text.filter { !strippedChars.contains($0) })

        // Step 2: reject multi-line.
        if text.contains("\n") {
            return nil
        }

        // Step 3: hard word cap.
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else { return nil }
        let capped = words.prefix(15).map(String.init)
        var result = capped.joined(separator: " ")

        // Step 4: lyric-pattern deny.
        let lower = result.lowercased()
        let lyricMarkers = ["[", "]", "(verse", "(chorus", "(bridge", "(intro", "(outro", "verse:", "chorus:", "bridge:"]
        if lyricMarkers.contains(where: { lower.contains($0) }) {
            return nil
        }
        // Quoted lyric block heuristic: a quote longer than 6 chars inside the line.
        if let firstQuote = result.firstIndex(of: "\""),
           let lastQuote = result.lastIndex(of: "\""),
           firstQuote != lastQuote {
            return nil
        }

        // Step 5: URL reject.
        if result.contains("://") || result.lowercased().contains("http") {
            return nil
        }

        // Final trim in case capping/filtering left edge whitespace.
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
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
        guard queueLength > 0 else { return [] }
        guard let session = modelSession else {
            return []
        }

        let sanitizedTitle = seedTitle.replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\r", with: " ")
            .replacingOccurrences(of: "\\\\", with: "")
        let sanitizedArtist = seedArtist.replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\r", with: " ")
            .replacingOccurrences(of: "\\\\", with: "")
        let sanitizedMood = userMoodContext.replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\r", with: " ")
            .replacingOccurrences(of: "\\\\", with: "")

        let prompt = """
        Seed track: \(sanitizedTitle) by \(sanitizedArtist).
        User mood: \(sanitizedMood).
        Build a \(queueLength)-track station arc. Return ONLY a JSON array of objects with keys: position (0-based Int), targetEnergy (0.0-1.0), targetValence (0.0-1.0), targetBPM (60-200), weight (0.0-1.0). Do not include markdown or explanation.
        """

        do {
            let response = try await session.respond(to: prompt)
            var content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip markdown code fences if present
            if content.hasPrefix("```") {
                if let firstNewline = content.firstIndex(of: "\n") {
                    content = String(content[firstNewline...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if content.hasSuffix("```") {
                if let lastNewline = content.lastIndex(of: "\n") {
                    content = String(content[..<lastNewline]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            guard let data = content.data(using: .utf8) else {
                return []
            }
            let decoded = try JSONDecoder().decode([StationArcTarget].self, from: data)
            let clamped = decoded.prefix(queueLength).map { target in
                StationArcTarget(
                    position: max(0, min(target.position, queueLength - 1)),
                    targetEnergy: max(0.0, min(target.targetEnergy, 1.0)),
                    targetValence: max(0.0, min(target.targetValence, 1.0)),
                    targetBPM: max(60.0, min(target.targetBPM, 200.0)),
                    weight: max(0.0, min(target.weight, 1.0))
                )
            }
            return clamped
        } catch {
            #if DEBUG
            print("OnDeviceDJBrain: Arc generation error \(error)")
            #endif
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
        guard queueLength > 0 else { return [] }
        return []
    }
}

#endif
