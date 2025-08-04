// StreamingUtils.swift
// -------------------------------------------------------------
//  Utilities for
//    • Parsing the OpenAI SSE text stream
//    • Chunk-by-chunk audio playback with temp-file cleanup
// -------------------------------------------------------------
//
// 2025-07-31:
//   • Removed duplicate AudioPlayerProvider definition—
//     we now use the one from Protocols.swift.
//   • Deletes every temp .mp3 after it plays.
//   • queuePlayer made optional so .stop() releases resources.
//

import Foundation
import AVFoundation
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
    category: "AudioStreaming"
)


// ──────────────────────────────────────────────────────────────
// MARK: – OpenAI SSE parsing
// ──────────────────────────────────────────────────────────────

struct OpenAIChunkResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let delta: Delta?
        struct Delta: Decodable {
            let role: String?
            let content: String?
            let refusal: String?
        }
    }
}

actor OpenAIStreamParser {
    /// Pull out incremental `content` tokens from one `data:` line.
    func parseStream(from data: Data) -> [String] {
        guard let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = raw.data(using: .utf8) else { return [] }

        if DebugFlags.streamingParsing { logger.debug("Chunk raw: \(raw)") }

        if let resp = try? JSONDecoder().decode(OpenAIChunkResponse.self, from: jsonData),
           let token = resp.choices.first?.delta?.content { return [token] }

        // Fallback: naive grep
        if let range = raw.range(of: "\"content\":\""),
           let end   = raw[range.upperBound...].firstIndex(of: "\"") {
            let token = raw[range.upperBound..<end]
                .replacingOccurrences(of: "\\\"", with: "\"")
            return [token]
        }
        return []
    }
}



// ──────────────────────────────────────────────────────────────
// MARK: – StreamingAudioPlayer (conforms to AudioPlayerProvider)
// ──────────────────────────────────────────────────────────────

final class StreamingAudioPlayer: NSObject, AudioPlayerProvider {

    private var queuePlayer: AVQueuePlayer?
    private var audioItems: [AVPlayerItem] = []

    /// Called just before each chunk is queued (used for timing logs).
    var onChunkStart: (() -> Void)?

    // MARK: init / deinit
    override init() {
        super.init()
        queuePlayer = AVQueuePlayer()
        if DebugFlags.audioPlayback { logger.info("Queue player initialized") }
    }

    deinit { stop() }

    // MARK: public API
    func playChunk(data: Data, completion: (() -> Void)? = nil) {
        guard let (url, item) = makePlayerItem(from: data) else {
            completion?(); return
        }
        audioItems.append(item)

        if DebugFlags.onChunkStart {
            logger.info("[TIMING] Firing onChunkStart for chunk at: \(Date())")
        }
        onChunkStart?()

        queuePlayer?.insert(item, after: nil)
        if queuePlayer?.rate == 0 { queuePlayer?.play() }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            try? FileManager.default.removeItem(at: url)
            if DebugFlags.audioFileCreation {
                logger.debug("Deleted temp audio: \(url.lastPathComponent)")
            }
            completion?()
            self?.cleanup(item)
        }
    }

    func playFull(data: Data, completion: (() -> Void)? = nil) {
        playChunk(data: data, completion: completion)
    }

    func stop() {
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        audioItems.removeAll()
        if DebugFlags.audioPlayback { logger.info("Playback stopped and queue cleared") }
    }

    func reset() {
        queuePlayer?.removeAllItems()
        audioItems.removeAll()
    }

    // MARK: helpers
    private func makePlayerItem(from data: Data) -> (URL, AVPlayerItem)? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        do {
            try data.write(to: url)
            if DebugFlags.audioFileCreation {
                logger.debug("Audio file created: \(url.lastPathComponent)")
            }
            let item = AVPlayerItem(url: url)
            item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            return (url, item)
        } catch {
            logger.error("Audio temp write failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func cleanup(_ item: AVPlayerItem) {
        if let idx = audioItems.firstIndex(of: item) {
            audioItems.remove(at: idx)
        }
    }

    // MARK: KVO for errors
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "status",
              let item = object as? AVPlayerItem,
              item.status == .failed else { return }
        logger.error("Audio item failed: \(item.error?.localizedDescription ?? "unknown")")
    }
}
