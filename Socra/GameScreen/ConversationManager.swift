//
//  ConversationManager.swift
//  Socra – end‑to‑end flow (Swift 6 compliant)
//
//  • Streaming OpenAI chat → ElevenLabs / OpenAI TTS
//  • Image generation per story
//  • Character‑aware greetings, voice IDs, and system prompts
//

import Foundation
import AVFoundation
import Combine
import SwiftUI
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
    category: "Conversation"
)

@MainActor
final class ConversationManager: ObservableObject {

    // ───────── UI‑bound state ─────────
    @Published var isSpeaking               = false
    @Published var isUserInitiatedListening = false
    @Published var errorMessage: String?
    @Published var agentMessage: String?
    @Published var currentSentenceIndex     = 0
    @Published var currentStoryId           = UUID()

    @Published var imageGenManager: ImageGenerationManager

    // ───────── Internals ─────────
    private let speechRecognizer: SpeechToTextProvider
    private let ttsService:       TTSService                    // concrete for voiceID
    private let timingLogger:     TimingProvider
    private let characterManager: CharacterManager

    private var messages: [[String: Any]]
    private var systemPrompt: String

    private var audioGroup       = DispatchGroup()
    private var streamingPlayer: StreamingAudioPlayer?
    private var greetingPlayer:  AVAudioPlayer?
    private let streamParser     = OpenAIStreamParser()

    private var cancellables     = Set<AnyCancellable>()

    private enum PlaybackState { case idle, speaking }
    private var playbackState: PlaybackState = .idle

    // MARK: – Init
    init(
        speechRecognizer: SpeechToTextProvider = SpeechRecognizer(),
        ttsService:       TTSService           = TTSService(),
        imageGenService:  ImageGenProvider     = ImageGenService(),
        timingLogger:     TimingProvider       = TimingLogger(),
        characterManager: CharacterManager     = AppDependencies.shared.characterManager
    ) {
        self.speechRecognizer = speechRecognizer
        self.ttsService       = ttsService
        self.timingLogger     = timingLogger
        self.characterManager = characterManager

        self.systemPrompt = SystemPrompt.content(for: characterManager.current)
        self.messages = [["role": "system", "content": systemPrompt]]

        self.imageGenManager  = ImageGenerationManager(
            imageGenService: imageGenService,
            timingLogger:    timingLogger
        )

        // Bubble image updates so SwiftUI refreshes instantly
        imageGenManager.$generatedImages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // React to character changes (greet + update system prompt)
        characterManager.$current
            .sink { [weak self] newChar in
                self?.handleCharacterChange(to: newChar)
            }
            .store(in: &cancellables)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: – Public entry points
    // ─────────────────────────────────────────────────────────────
    func userDidSubmit(_ prompt: String) {
        Task {
            timingLogger.start(event: "UserSubmit")
            logger.info("User prompt: \(prompt)")

            resetStoryState()
            messages.append(["role": "user", "content": prompt])

            do   { try await streamChatResponse() }
            catch {
                errorMessage = error.localizedDescription
                logger.error("Stream failed: \(error.localizedDescription)")
            }

            timingLogger.end(event: "UserSubmit")
        }
    }

    /// Plays the greeting for the current character.
    func playGreeting() { handleCharacterChange(to: characterManager.current, greetOnly: true) }

    func stopSpeaking() {
        streamingPlayer?.stop()
        greetingPlayer?.stop()
        isSpeaking    = false
        playbackState = .idle
        Task { _ = try? await speechRecognizer.stopRecording() }
        imageGenManager.resetForNewStory(storyId: currentStoryId)
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: – Character change & greeting
    // ─────────────────────────────────────────────────────────────
    private func handleCharacterChange(to char: Character, greetOnly: Bool = false) {
        stopSpeaking()

        // refresh system prompt
        systemPrompt = SystemPrompt.content(for: char)
        messages[0]["content"] = systemPrompt
        if !greetOnly { logger.debug("System prompt updated for \(char.id)") }

        // play greeting
        if let url = char.greetingAudioURL() {
            playLocalGreeting(url)
        } else {
            Task { await speak(char.greeting, using: char.voiceID) }
        }
    }

    private func playLocalGreeting(_ url: URL) {
        do {
            greetingPlayer = try AVAudioPlayer(contentsOf: url)
            greetingPlayer?.play()
            isSpeaking = true
            Task { @MainActor in
                try await Task.sleep(nanoseconds: UInt64((greetingPlayer?.duration ?? 0) * 1_000_000_000))
                self.isSpeaking = false
            }
        } catch {
            logger.error("Greeting MP3 failed: \(error.localizedDescription)")
            Task { await speak(characterManager.current.greeting,
                               using: characterManager.current.voiceID) }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: – Streaming loop
    // ─────────────────────────────────────────────────────────────
    private func streamChatResponse() async throws {
        timingLogger.start(event: "OpenAIStream")

        var req = URLRequest(url: URL(string: Config.openAIChatURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json",           forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        req.setValue("text/event-stream",          forHTTPHeaderField: "Accept")

        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "messages": messages,
            "stream": true
        ])

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "OpenAI", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Stream HTTP \(http.statusCode)"])
        }

        streamingPlayer = StreamingAudioPlayer()
        isSpeaking      = true
        playbackState   = .speaking
        audioGroup      = DispatchGroup()

        var partialReply = ""
        var fullReply    = ""

        for try await line in bytes.lines {
            guard line.hasPrefix("data: "),
                  !line.hasPrefix("data: [DONE]") else { continue }

            let data   = Data(line.dropFirst(6).utf8)
            let tokens = await streamParser.parseStream(from: data)

            for token in tokens {
                partialReply += token
                fullReply    += token
                agentMessage  = fullReply

                if token.contains(where: { ".!?".contains($0) }) {
                    let sentence = partialReply.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty {
                        await playSentence(sentence)
                        partialReply = ""
                    }
                }
            }
        }

        if !partialReply.isEmpty { await playSentence(partialReply) }

        // Launch single‑image generation
        let summaryPrompt = await extractSummaryPrompt(from: fullReply)
        imageGenManager.enqueueImageGeneration(prompt: summaryPrompt, at: 0)

        await waitOnGroup(audioGroup)
        isSpeaking      = false
        playbackState   = .idle
        messages.append(["role": "assistant", "content": fullReply])

        timingLogger.end(event: "OpenAIStream")
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: – Helpers
    // ─────────────────────────────────────────────────────────────
    private func speak(_ text: String, using voiceID: String?) async {
        do {
            let id   = voiceID ?? Config.elevenLabsVoiceID
            let data = try await ttsService.fetchAudio(for: cleanTextForTTS(text), voiceID: id)
            isSpeaking      = true
            playbackState   = .speaking
            streamingPlayer = StreamingAudioPlayer()
            audioGroup      = DispatchGroup()

            audioGroup.enter()
            streamingPlayer?.playFull(data: data) { self.audioGroup.leave() }
            await waitOnGroup(audioGroup)

            isSpeaking    = false
            playbackState = .idle
        } catch {
            errorMessage = error.localizedDescription
            logger.error("speak() failed: \(error.localizedDescription)")
        }
    }

    private func playSentence(_ sentence: String) async {
        guard !sentence.isEmpty else { return }

        do {
            timingLogger.start(event: "TTSChunk")

            if playbackState == .idle {
                _ = try? await speechRecognizer.stopRecording(after: 0.3)
                playbackState = .speaking
            }

            let vid = characterManager.current.voiceID ?? Config.elevenLabsVoiceID
            let audioData = try await ttsService.fetchStreamingAudio(for: cleanTextForTTS(sentence), voiceID: vid)
            audioGroup.enter()
            streamingPlayer?.playChunk(data: audioData) { [weak self] in
                self?.audioGroup.leave()
                self?.playbackState = .idle
            }

            timingLogger.end(event: "TTSChunk")
            currentSentenceIndex += 1
        } catch {
            logger.error("TTS chunk failed: \(error.localizedDescription)")
        }
    }

    private func cleanTextForTTS(_ text: String) -> String {
        text.replacingOccurrences(of: "[*_#>]?", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func waitOnGroup(_ group: DispatchGroup) async {
        await withCheckedContinuation { cont in
            group.notify(queue: .global()) { cont.resume() }
        }
    }

    private func extractSummaryPrompt(from story: String) async -> String {
        let fallback = story
            .split(separator: " ")
            .prefix(30)
            .joined(separator: " ")

        timingLogger.start(event: "SummaryExtract")

        let prompt = await withTaskGroup(of: String.self) { group -> String in
            group.addTask { [story] in
                do {
                    var req = URLRequest(url: URL(string: Config.openAIChatURL)!)
                    req.httpMethod = "POST"
                    req.setValue("application/json",           forHTTPHeaderField: "Content-Type")
                    req.setValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")

                    req.httpBody = try JSONSerialization.data(withJSONObject: [
                        "model": "gpt-4o-mini",
                        "messages": [
                            ["role": "system", "content": StoryExtractionPrompt.content],
                            ["role": "user",   "content": story]
                        ]
                    ])

                    let (data, resp) = try await URLSession.shared.data(for: req)
                    guard (resp as? HTTPURLResponse)?.statusCode == 200,
                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let msg = choices.first?["message"] as? [String: Any],
                          let content = msg["content"] as? String,
                          !content.isEmpty else { throw NSError() }

                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                } catch { return fallback }
            }

            // 1‑second race timeout
            group.addTask {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return fallback
            }

            let winner = await group.next() ?? fallback
            group.cancelAll()
            return winner
        }

        timingLogger.end(event: "SummaryExtract")
        return prompt
    }

    private func resetStoryState() {
        currentStoryId        = UUID()
        currentSentenceIndex  = 0
        imageGenManager.resetForNewStory(storyId: currentStoryId)
    }

    // MARK: – Analytics
    func imageDisplayed(at index: Int) {
        logger.info("Image displayed for sentenceIndex \(index)")
    }
}

// MARK: – Micro‑gate helper
extension SpeechToTextProvider {
    /// Stops recording *after* a small delay so the mic buffer can clear.
    @discardableResult
    func stopRecording(after delay: TimeInterval) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return try await stopRecording()
    }
}
