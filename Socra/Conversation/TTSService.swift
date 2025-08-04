//
//  TTSService.swift
//  Socra
//
//  Primary: ElevenLabs.   Fallback: OpenAI TTS (“alloy” voice).
//  2025-07-31  – merge of original ElevenLabs code + OpenAI backup.
//

import Foundation
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
    category: "TTS"
)

// ---------- Convenience wrapper so NSCache can store Data ----------
final class AudioDataWrapper: NSObject { let data: Data; init(data: Data) { self.data = data } }

// ---------- Common errors ----------
enum TTSError: Error {
    case unauthorized          // 401  (likely out of credits / bad key)
    case rateLimited           // 429
    case emptyResponse
    case server(status: Int, body: String)
}

// ---------- Service ----------
final class TTSService: TextToSpeechProvider {

    // MARK: – Injected for streaming playback (if you want real chunk feed)
    private let audioPlayerFactory: () -> AudioPlayerProvider

    init(audioPlayer: @escaping () -> AudioPlayerProvider = { StreamingAudioPlayer() }) {
        self.audioPlayerFactory = audioPlayer
    }

    // MARK: – Local cache for non-streaming requests
    private let cache = NSCache<NSString, AudioDataWrapper>()

    // High-priority session so audio beats images over the wire
    private let highPrioritySession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.networkServiceType = .voice
        return URLSession(configuration: cfg)
    }()

    // ------------------------------------------------------------------
    // MARK: Non-streaming
    // ------------------------------------------------------------------
    func fetchAudio(for text: String) async throws -> Data {
        if let hit = cache.object(forKey: text as NSString) { return hit.data }

        do {
            let data = try await elevenLabsRequest(text: text, stream: false)
            cache.setObject(AudioDataWrapper(data: data), forKey: text as NSString)
            return data
        } catch TTSError.unauthorized, TTSError.rateLimited {
            logger.warning("ElevenLabs quota hit – falling back to OpenAI")
            let data = try await openAITTS(text: text, stream: false, speed: nil)
            cache.setObject(AudioDataWrapper(data: data), forKey: text as NSString)
            return data
        }
    }

    // ------------------------------------------------------------------
    // MARK: Streaming  (returns full Data but can feed chunks)
    // ------------------------------------------------------------------
    func fetchStreamingAudio(for text: String) async throws -> Data {
        do {
            return try await elevenLabsRequest(text: text, stream: true)
        } catch TTSError.unauthorized, TTSError.rateLimited {
            logger.warning("ElevenLabs quota hit – streaming fallback to OpenAI")
            return try await openAITTS(text: text, stream: true, speed: 1.1)
        }
    }

    // ==================================================================
    // MARK: ElevenLabs helpers
    // ==================================================================
    private func elevenLabsRequest(text: String, stream: Bool) async throws -> Data {
        let urlStr = "https://api.elevenlabs.io/v1/text-to-speech/\(Config.elevenLabsVoiceID)"
                    + (stream ? "/stream" : "")
        guard let url = URL(string: urlStr) else { fatalError("Bad ElevenLabs URL") }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if stream { req.setValue("audio/mpeg", forHTTPHeaderField: "Accept") }
        req.setValue(Config.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [ "stability": 0.6, "similarity_boost": 0.85 ],
            "output_format": "mp3_44100_128"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await highPrioritySession.data(for: req)
        try validateEleven(resp: resp, body: data)
        guard !data.isEmpty else { throw TTSError.emptyResponse }
        return data
    }

    private func validateEleven(resp: URLResponse?, body: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200: return
        case 401: throw TTSError.unauthorized
        case 429: throw TTSError.rateLimited
        default:
            let msg = String(data: body, encoding: .utf8) ?? ""
            throw TTSError.server(status: http.statusCode, body: msg)
        }
    }

    // ==================================================================
    // MARK: OpenAI helpers (backup)
    // ==================================================================
    private struct OpenAITTSRequest: Encodable {
        let model  = "tts-1"
        let input: String
        let voice  = "alloy"
        let format = "mp3"
        let speed: Double?
        let stream: Bool?
    }

    private func openAITTS(text: String, stream: Bool, speed: Double?) async throws -> Data {
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            fatalError("Bad OpenAI URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",             forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(
            OpenAITTSRequest(input: text, speed: speed, stream: stream ? true : nil)
        )

        if stream {
            // HTTP/2 chunked streaming
            let (bytes, resp) = try await highPrioritySession.bytes(for: req)
            try validateOpenAI(resp: resp)
            var buffer = Data()
            for try await chunk in bytes {
                buffer.append(chunk)
                // Optionally feed chunks: audioPlayerFactory().playChunk(data: chunk)
            }
            return buffer
        } else {
            let (data, resp) = try await highPrioritySession.data(for: req)
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
