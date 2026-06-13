import SwiftUI
import MusicKit
import AVFoundation
import Accelerate
import OSLog

private let logger = Logger(subsystem: "app.modus", category: "Phase0Spike")

/// Phase 0 spike harness — see /Users/jp/.claude/plans/we-have-another-tab-indexed-coral.md
/// Answers two questions on a real device:
///  (1) Steerability — can we set `ApplicationMusicPlayer.shared.queue` to a `Song.station`,
///      see upcoming `queue.entries`, and `skipToNextEntry()` cleanly?
///  (2) Feature viability — can we get `Song.previewAssets`, decode, and compute usable
///      numerical features on-device?
///
/// Reached via Settings → Debug → Phase 0 Spike. Device + Apple Music subscription required.
@MainActor
struct SpikeView: View {
    @State private var seedQuery: String = "Friday I'm in Love"
    @State private var logLines: [String] = []
    @State private var isBusy: Bool = false
    @State private var resolvedSong: Song? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                seedSection
                steerabilitySection
                featureSection
                logSection
            }
            .padding()
        }
        .navigationTitle("Phase 0 Spike")
    }

    // MARK: - Sections

    private var seedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seed").font(.headline)
            HStack {
                TextField("Song title", text: $seedQuery)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusy)
                Button("Resolve") {
                    Task { await resolveSeed() }
                }
                .disabled(isBusy || seedQuery.isEmpty)
            }
            if let song = resolvedSong {
                Text("\(song.title) — \(song.artistName)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("station=\(song.station == nil ? "nil" : song.station!.name) · preview=\(song.previewAssets?.count ?? 0) · isrc=\(song.isrc ?? "nil")")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var steerabilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steerability").font(.headline)
            HStack {
                Button("A: [song, station]") { Task { await runSeedFirstStationTail() } }
                    .disabled(isBusy || resolvedSong == nil)
                Button("B: [station] only") { Task { await runStationOnly() } }
                    .disabled(isBusy || resolvedSong == nil)
            }
            HStack {
                Button("Skip") { Task { await runSkip() } }
                    .disabled(isBusy)
                Button("Stop") { stopPlayback() }
                    .disabled(isBusy)
                Button("Snapshot Queue") { snapshotQueue() }
                    .disabled(isBusy)
            }
        }
        .buttonStyle(.bordered)
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feature Viability (preview MIR)").font(.headline)
            Button("Run Preview MIR") { Task { await runPreviewMIR() } }
                .buttonStyle(.bordered)
                .disabled(isBusy || resolvedSong == nil)
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Log").font(.headline)
                Spacer()
                Button("Clear") { logLines.removeAll() }
                    .font(.caption)
                    .disabled(isBusy)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(logLines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 280, maxHeight: 420)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: logLines.count) { _, newValue in
                    if newValue > 0 {
                        withAnimation { proxy.scrollTo(newValue - 1, anchor: .bottom) }
                    }
                }
            }
        }
    }

    // MARK: - Logging

    private func log(_ s: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        let line = "\(f.string(from: Date())) \(s)"
        logLines.append(line)
        logger.debug("\(line, privacy: .public)")
    }

    // MARK: - Resolve seed

    private func resolveSeed() async {
        isBusy = true
        defer { isBusy = false }
        log("--- resolve seed: \(seedQuery)")
        do {
            try await ensureAuthorized()
            var req = MusicCatalogSearchRequest(term: seedQuery, types: [Song.self])
            req.limit = 5
            let resp = try await req.response()
            guard let candidate = resp.songs.first else {
                log("no song matched.")
                resolvedSong = nil
                return
            }
            log("matched: \(candidate.title) by \(candidate.artistName)")
            let detailed = try await candidate.with([.station])
            resolvedSong = detailed
            if let st = detailed.station {
                log("station loaded: \(st.name) [id=\(st.id.rawValue)]")
            } else {
                log("station NIL — this song has no associated station.")
            }
            log("previewAssets=\(detailed.previewAssets?.count ?? 0) isrc=\(detailed.isrc ?? "nil") duration=\(detailed.duration ?? 0)s")
        } catch {
            log("ERROR resolve: \(error.localizedDescription)")
        }
    }

    private func ensureAuthorized() async throws {
        switch MusicAuthorization.currentStatus {
        case .authorized: return
        case .notDetermined:
            let s = await MusicAuthorization.request()
            if s != .authorized { throw SpikeError.notAuthorized }
        default:
            throw SpikeError.notAuthorized
        }
    }

    // MARK: - Steerability tests

    private func runSeedFirstStationTail() async {
        guard let song = resolvedSong else { return }
        isBusy = true
        defer { isBusy = false }
        log("=== TEST A: queue = [song, station] ===")
        guard let station = song.station else {
            log("ABORT: song.station is nil. Re-resolve a song that has a station.")
            return
        }
        ApplicationMusicPlayer.shared.queue = [song, station]
        await measuredPlay(label: "A")
        await pollQueue(label: "A", durationSec: 20, intervalSec: 5)
    }

    private func runStationOnly() async {
        guard let song = resolvedSong else { return }
        isBusy = true
        defer { isBusy = false }
        log("=== TEST B: queue = [station] only ===")
        guard let station = song.station else {
            log("ABORT: song.station is nil.")
            return
        }
        ApplicationMusicPlayer.shared.queue = [station]
        await measuredPlay(label: "B")
        await pollQueue(label: "B", durationSec: 20, intervalSec: 5)
    }

    private func runSkip() async {
        isBusy = true
        defer { isBusy = false }
        let player = ApplicationMusicPlayer.shared
        let before = player.queue.currentEntry?.title ?? "nil"
        log("skip: before currentEntry='\(before)'")
        let t = Date()
        do {
            try await player.skipToNextEntry()
            let dt = Date().timeIntervalSince(t)
            try? await Task.sleep(nanoseconds: 800_000_000)
            let after = player.queue.currentEntry?.title ?? "nil"
            log("skip ok in \(String(format: "%.2f", dt))s → '\(after)'")
        } catch {
            log("ERROR skip: \(error.localizedDescription)")
        }
    }

    private func stopPlayback() {
        ApplicationMusicPlayer.shared.stop()
        log("player stopped.")
    }

    private func snapshotQueue() {
        let player = ApplicationMusicPlayer.shared
        let entries = player.queue.entries
        log("snapshot: entries.count=\(entries.count) current='\(player.queue.currentEntry?.title ?? "nil")'")
        for (idx, e) in entries.prefix(10).enumerated() {
            log("  [\(idx)] '\(e.title)' — \(e.subtitle ?? "")")
        }
    }

    private func measuredPlay(label: String) async {
        let t0 = Date()
        do {
            try await ApplicationMusicPlayer.shared.play()
            let dt = Date().timeIntervalSince(t0)
            log("\(label) play() ok in \(String(format: "%.2f", dt))s")
        } catch {
            log("\(label) ERROR play: \(error.localizedDescription)")
        }
    }

    private func pollQueue(label: String, durationSec: Int, intervalSec: Int) async {
        let steps = max(1, durationSec / intervalSec)
        for i in 0..<steps {
            try? await Task.sleep(nanoseconds: UInt64(intervalSec) * 1_000_000_000)
            let entries = ApplicationMusicPlayer.shared.queue.entries
            let current = ApplicationMusicPlayer.shared.queue.currentEntry?.title ?? "nil"
            log("\(label) t=\(intervalSec * (i + 1))s entries=\(entries.count) current='\(current)'")
            for (idx, e) in entries.prefix(5).enumerated() {
                log("  [\(idx)] '\(e.title)' — \(e.subtitle ?? "")")
            }
        }
    }

    // MARK: - Feature viability (preview MIR)

    private func runPreviewMIR() async {
        guard let song = resolvedSong else { return }
        isBusy = true
        defer { isBusy = false }
        log("=== PREVIEW MIR ===")
        guard let previewURL = song.previewAssets?.first?.url else {
            log("FAIL: song has no previewAssets URL.")
            return
        }
        log("preview url: \(previewURL.absoluteString)")

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("modus-spike-\(song.id.rawValue).m4a")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // 1. Download
        let dlStart = Date()
        do {
            let (data, _) = try await URLSession.shared.data(from: previewURL)
            try data.write(to: tmpURL, options: .atomic)
            log("downloaded \(data.count) bytes in \(String(format: "%.2f", Date().timeIntervalSince(dlStart)))s")
        } catch {
            log("ERROR download: \(error.localizedDescription)")
            return
        }

        // 2. Decode
        let decodeStart = Date()
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: tmpURL)
        } catch {
            log("ERROR open audio file: \(error.localizedDescription)")
            return
        }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            log("FAIL: empty file or could not allocate PCM buffer")
            return
        }
        do {
            try file.read(into: buffer)
        } catch {
            log("ERROR read pcm: \(error.localizedDescription)")
            return
        }
        log("decoded \(buffer.frameLength) frames @ \(Int(format.sampleRate)) Hz, \(format.channelCount) ch in \(String(format: "%.2f", Date().timeIntervalSince(decodeStart)))s")

        guard let channelData = buffer.floatChannelData else {
            log("FAIL: no floatChannelData (format=\(format))")
            return
        }
        let n = Int(buffer.frameLength)
        let mono = channelData[0]

        // 3. RMS energy
        var rms: Float = 0
        vDSP_rmsqv(mono, 1, &rms, vDSP_Length(n))
        let energyNorm = min(1.0, Double(rms) * 4.0) // soft compress to ~[0,1]
        log("RMS=\(String(format: "%.4f", rms))  energy≈\(String(format: "%.2f", energyNorm))")

        // 4. Zero-crossing rate (rough timbre/acousticness proxy)
        var zc: vDSP_Length = 0
        var crossings: vDSP_Length = 0
        vDSP_nzcros(mono, 1, vDSP_Length(n - 1), &zc, &crossings, vDSP_Length(n - 1))
        let zcr = Double(crossings) / Double(max(n, 1))
        log("ZCR=\(String(format: "%.4f", zcr))")

        log("--- pipeline OK. tempo & valence intentionally NOT measured in spike. ---")
    }
}

private enum SpikeError: LocalizedError {
    case notAuthorized
    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Apple Music not authorized."
        }
    }
}
