// Protocols.swift
import Foundation

protocol SpeechToTextProvider {
    func startRecording() async throws
    func stopRecording() async throws -> String
}

protocol TextToSpeechProvider {
    func fetchAudio(for text: String, voiceID: String) async throws -> Data
    func fetchStreamingAudio(for text: String, voiceID: String) async throws -> Data
}

protocol LLMProvider {
    func streamChatResponse(messages: [[String: Any]]) async throws -> AsyncThrowingStream<String, Error>
}

protocol AudioPlayerProvider {
    func playChunk(data: Data, completion: (() -> Void)?)
    func playFull(data: Data, completion: (() -> Void)?)
    func stop()
    func reset()
}
