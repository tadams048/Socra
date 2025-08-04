//
//  AppDependencies.swift
//  Socra
//
//  Updated 2025‑08‑04
//

import Foundation

struct AppDependencies {

    // MARK: – Singleton
    @MainActor
    static let shared: AppDependencies = {
        AppDependencies(
            characterManager:   CharacterManager(),
            speechToText:       SpeechRecognizer(),
            textToSpeech:       TTSService(),
            llm:                OpenAILLMProvider(),
            makeAudioPlayer:    { StreamingAudioPlayer() },
            audioSessionManager: AudioSessionManager(),
            timingLogger:       TimingLogger()
        )
    }()

    // MARK: – Stored deps
    let characterManager: CharacterManager          // ← NEW
    let speechToText:      SpeechToTextProvider
    let textToSpeech:      TextToSpeechProvider
    let llm:               LLMProvider
    let makeAudioPlayer:   () -> AudioPlayerProvider
    let audioSessionManager: AudioSessionManager
    let timingLogger:      TimingProvider

    var audioPlayer: AudioPlayerProvider { makeAudioPlayer() }

    // MARK: – Designated init
    init(
        characterManager:   CharacterManager,
        speechToText:       SpeechToTextProvider,
        textToSpeech:       TextToSpeechProvider,
        llm:                LLMProvider,
        makeAudioPlayer:    @escaping () -> AudioPlayerProvider,
        audioSessionManager: AudioSessionManager,
        timingLogger:       TimingProvider
    ) {
        self.characterManager    = characterManager
        self.speechToText        = speechToText
        self.textToSpeech        = textToSpeech
        self.llm                 = llm
        self.makeAudioPlayer     = makeAudioPlayer
        self.audioSessionManager = audioSessionManager
        self.timingLogger        = timingLogger
    }
}

// MARK: – Test / preview convenience
extension AppDependencies {

    /// Construct a mock container on the Main Actor.
    @MainActor
    static func mock(
        // 🔧 1) characterManager is **optional** now (defaults to nil)
        characterManager: CharacterManager? = nil,
        speechToText:     SpeechToTextProvider = SpeechRecognizer(),
        textToSpeech:     TextToSpeechProvider = TTSService(),
        llm:              LLMProvider          = OpenAILLMProvider(),
        makeAudioPlayer:  @escaping () -> AudioPlayerProvider = { StreamingAudioPlayer() },
        audioSessionManager: AudioSessionManager = AudioSessionManager(),
        timingLogger:     TimingProvider       = TimingLogger()
    ) -> AppDependencies {

        // 🔧 2) If caller didn’t supply one, create it *inside* the Main‑Actor context
        let cm = characterManager ?? CharacterManager()

        return AppDependencies(
            characterManager:   cm,
            speechToText:       speechToText,
            textToSpeech:       textToSpeech,
            llm:                llm,
            makeAudioPlayer:    makeAudioPlayer,
            audioSessionManager: audioSessionManager,
            timingLogger:       timingLogger
        )
    }
}
