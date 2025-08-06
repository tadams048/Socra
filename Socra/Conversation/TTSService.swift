//
//  TTSService.swift
//  Socra
//
//  Primary: ElevenLabs.   Fallback: OpenAI TTS (“alloy” voice).
//  2025‑08‑06  – updated debugging & error reporting.
//

import Foundation
import os.log

// ─────────────────────────────────────────────────────────────
// MARK: – Logging helper
// ─────────────────────────────────────────────────────────────
private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "funloop.Socra",
    category: "TTSService"
)

// ─────────────────────────────────────────────────────────────
// MARK: – Convenience for NSCache
// ─────────────────────────────────────────────────────────────
final class AudioDataWrapper: NSObject {
    let data: Data
    init(data: Data) { self.data = data }
}

// ─────────────────────────────────────────────────────────────
// MARK: – Errors
// ─────────────────────────────────────────────────────────────
enum TTSError: Error, LocalizedError {
    case unauthorized                // 401
    case rateLimited                 // 429
    case emptyResponse
    case server(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "ElevenLabs says the token is invalid or you are out of credits (401)."
        case .rateLimited:
            return "ElevenLabs rate‑limit hit (429)."
        case .emptyResponse:
            return "ElevenLabs returned an empty audio buffer."
        case .server(let status, let body):
            return "ElevenLabs HTTP \(status): \(body)"
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – Service
// ─────────────────────────────────────────────────────────────
final class TTSService: TextToSpeechProvider {

    // Injected so ConversationManager can get a *fresh* player for streaming
    private let audioPlayerFactory: () -> AudioPlayerProvider

    init(audioPlayer: @escaping () -> AudioPlayerProvider = { StreamingAudioPlayer() }) {
        self.audioPlayerFactory = audioPlayer
    }

    // Local cache (non‑stream requests only)
    private let cache = NSCache<NSString, AudioDataWrapper>()

    // Give audio traffic priority over images
    private let hiPriSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.networkServiceType = .voice
        return URLSession(configuration: cfg)
    }()

    // =========================================================
    // MARK: Non‑streaming
    // =========================================================
    func fetchAudio(for text: String) async throws -> Data {
        if let cached = cache.object(forKey: text as NSString) { return cached.data }

        do {
            let data = try await elevenLabsRequest(text: text, stream: false)
            cache.setObject(AudioDataWrapper(data: data), forKey: text as NSString)
            return data
        } catch TTSError.unauthorized, TTSError.rateLimited {
            logger.warning("ElevenLabs quota/401 – falling back to OpenAI (non‑stream)")
            let data = try await openAITTS(text: text, stream: false)
            cache.setObject(AudioDataWrapper(data: data), forKey: text as NSString)
            return data
        }
    }

    // =========================================================
    // MARK: Streaming – returns full Data *and* feeds chunks
    // =========================================================
    func fetchStreamingAudio(for text: String) async throws -> Data {
        do {
            return try await elevenLabsRequest(text: text, stream: true)
        } catch TTSError.unauthorized, TTSError.rateLimited {
            logger.warning("ElevenLabs quota/401 – falling back to OpenAI (stream)")
            return try await openAITTS(text: text, stream: true, speed: 1.1)
        }
    }

    // =========================================================
    // MARK: ElevenLabs helpers
    // =========================================================
    private func elevenLabsRequest(text: String, stream: Bool) async throws -> Data {
        let urlString =
          "https://api.elevenlabs.io/v1/text-to-speech/\(Config.elevenLabsVoiceID)"
          + (stream ? "/stream" : "")
        guard let url = URL(string: urlString) else { fatalError("Bad ElevenLabs URL") }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",     forHTTPHeaderField: "Content-Type")
        if stream { req.setValue("audio/mpeg", forHTTPHeaderField: "Accept") }
        req.setValue(Config.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")

        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [ "stability": 0.6, "similarity_boost": 0.85 ],
            "output_format": "mp3_44100_128"
        ])

        let (data, resp) = try await hiPriSession.data(for: req)
        try validateEleven(resp: resp, body: data)
        guard !data.isEmpty else { throw TTSError.emptyResponse }
        return data
    }

    /// Detailed validation with debug surface
    private func validateEleven(resp: URLResponse?, body: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }

        // Log every non‑200 in DEBUG so you can see the JSON reason
        #if DEBUG
        if http.statusCode != 200 {
            let bodyStr = String(data: body, encoding: .utf8) ?? "<non‑utf8>"
            logger.debug("ElevenLabs HTTP \(http.statusCode) body: \(bodyStr)")
        }
        #endif

        switch http.statusCode {
        case 200: return
        case 401: throw TTSError.unauthorized
        case 429: throw TTSError.rateLimited
        case 404, 422:
            let msg = String(data: body, encoding: .utf8) ?? ""
            throw TTSError.server(status: http.statusCode, body: msg) // surfaces actual detail
        default:
            let msg = String(data: body, encoding: .utf8) ?? ""
            throw TTSError.server(status: http.statusCode, body: msg)
        }
    }

    // =========================================================
    // MARK: OpenAI helpers (backup)
    // =========================================================
    private struct OpenAITTSRequest: Encodable {
        let model  = "tts-1"
        let input: String
        let voice  = "alloy"
        let format = "mp3"
        var speed: Double? = nil
        var stream: Bool?  = nil
    }

    private func openAITTS(text: String,
                           stream: Bool,
                           speed: Double? = nil) async throws -> Data {

        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            fatalError("Bad OpenAI URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",           forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            OpenAITTSRequest(input: text, speed: speed, stream: stream ? true : nil)
        )

        if stream {
            // HTTP/2 chunk streaming
            let (bytes, resp) = try await hiPriSession.bytes(for: req)
            try validateOpenAI(resp: resp)
            var buffer = Data()
            for try await chunk in bytes {
                buffer.append(chunk)
                // You could feed chunks here:
                // audioPlayerFactory().playChunk(data: chunk)
            }
            return buffer
        } else {
            let (data, resp) = try await hiPriSession.data(for: req)
            try validateOpenAI(resp: resp, body: data)
            return data
        }
    }

    private func validateOpenAI(resp: URLResponse?, body: Data? = nil) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200: return
        case 401: throw TTSError.unauthorized
        case 429: throw TTSError.rateLimited
        default:
            let msg = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw TTSError.server(status: http.statusCode, body: msg)
        }
    }
}
