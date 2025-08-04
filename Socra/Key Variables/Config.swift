//
//  Config.swift
//  Socra
//
//  Secrets are supplied at run-time via Scheme-level environment
//  variables (or Info.plist fallback).  Nothing sensitive is hard-coded.
//

import Foundation

enum Config {

    // MARK: – OpenAI
    static let openAIKey: String = Self.value(for: "OPENAI_API_KEY")

    /// Chat/completions endpoint (streamed tokens)
    static let openAIChatURL     = "https://api.openai.com/v1/chat/completions"

    /// Audio/speech endpoint (streamed MP3)
    static let openAITTSURL      = "https://api.openai.com/v1/audio/speech"

    /// Legacy alias so older call-sites still compile
    static let openAIURL         = openAIChatURL

    // MARK: – ElevenLabs
    static let elevenLabsAPIKey: String = Self.value(for: "ELEVEN_API_KEY")
    static let elevenLabsVoiceID        = "zGjIP4SZlMnY9m93k97r"
    static let elevenTTSEndpoint        = "https://api.elevenlabs.io/v1/text-to-speech"

    // MARK: – Runware
    static let runwareApiKey:    String = Self.value(for: "RUNWARE_API_KEY")
    static let runwareEndpointURL       = "https://api.runware.ai/v1/image/generate"
    static let runwareModel             = "runware:100@1"

    // MARK: – Helper
    private static func value(for key: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key] { return env }
        if let plist = Bundle.main.infoDictionary?[key] as? String { return plist }
        return ""   // Caller decides how to handle “missing”
    }
}
