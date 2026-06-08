import Foundation
import OSLog

private let logger = Logger(subsystem: "app.echodj", category: "TTSClient")

actor TTSClient {
    private let apiKey: String?
    private let cacheDirectory: URL

    init(apiKey: String? = nil) {
        self.apiKey = apiKey
        let tempDir = FileManager.default.temporaryDirectory
        self.cacheDirectory = tempDir.appendingPathComponent("echodj_transitions", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func synthesize(text: String, voiceID: String = "default") async -> URL? {
        let hash = text.hashValue
        let cachedURL = cacheDirectory.appendingPathComponent("\(hash)_\(voiceID).mp3")

        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return nil // No API key, skip TTS
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.5
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                logger.error("API error: status \(status, privacy: .public)")
                return nil
            }
            try data.write(to: cachedURL)
            return cachedURL
        } catch {
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
