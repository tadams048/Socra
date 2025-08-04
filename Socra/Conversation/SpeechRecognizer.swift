//
//  SpeechRecognizer.swift
//  Captures mic → text with timing, logging, and Swift-6 actor safety.
//

import Foundation
import Speech
import AVFoundation
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
    category: "STT"
)

actor SpeechRecognizer: SpeechToTextProvider {

    // MARK: – State
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var continuation: CheckedContinuation<String, Error>?
    private var recognitionResult: Result<String, Error>?

    private var timeoutWorkItem: DispatchWorkItem?

    private var isRecording      = false
    private var latestPartial    = ""

    // MARK: – Public API
    func startRecording() async throws {
        AppDependencies.shared.timingLogger.start(event: "STTStart")
        guard !isRecording else { return }
        isRecording = true

        guard let recognizer = SFSpeechRecognizer(locale: .init(identifier: "en-US")) else {
            logger.error("Failed to init recognizer")
            throw VoiceError.initializationFailed
        }
        guard recognizer.isAvailable else {
            logger.error("Speech recognizer unavailable")
            throw VoiceError.unavailable
        }

        try configureAudioSession()

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let engine = AVAudioEngine()
        audioEngine = engine
        let input = engine.inputNode

        installTap(on: input)
        try engine.start()
        logger.info("Mic recording started")

        // Result handler – hop back onto the actor.
        task = recognizer.recognitionTask(with: request!) { [weak self] result, error in
            guard let self else { return }
            Task { await self.handleRecognition(result: result, error: error) }
        }
    }

    func stopRecording() async throws -> String {
        guard let request else {
            isRecording = false
            if let result = recognitionResult {
                recognitionResult = nil
                return try result.get()
            }
            throw VoiceError.notRecording
        }

        // Let Core Audio flush ~200 ms of buffered frames.
        try? await Task.sleep(nanoseconds: 200_000_000)

        request.endAudio()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        let transcript = try await withCheckedThrowingContinuation { cont in
            continuation = cont

            timeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                Task { await self.finish(with: .failure(VoiceError.timeout)) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8,
                                          execute: timeoutWorkItem!)
        }

        AppDependencies.shared.timingLogger.end(event: "STTStart")
        return transcript
    }

    // MARK: – Private helpers
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    private func installTap(on node: AVAudioNode) {
        let fmt = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1_024, format: fmt) { [weak self] buffer, _ in
            // Hop back onto the actor to touch actor-isolated state.
            Task { [weak self] in
                await self?.appendBuffer(buffer)
            }

            guard DebugFlags.micInputLevel,
                  let channel = buffer.floatChannelData?.pointee else { return }

            // Break the RMS calculation into simpler sub-expressions to keep
            // the Swift 6 type-checker happy.
            let frameCount = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameCount { sum += channel[i] * channel[i] }
            let rms = sqrt(sum / Float(frameCount))
            let db  = 20 * log10(rms)

            logger.debug("Input: \(String(format: "%.1f", db)) dB")
        }
    }

    private func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?,
                                   error: Error?) async {
        if let result {
            let transcript = result.bestTranscription.formattedString
            latestPartial  = transcript

            if DebugFlags.partialTranscript {
                logger.debug("Partial: \(transcript, privacy: .public)")
            }

            if result.isFinal {
                logger.info("Final: \(transcript, privacy: .public)")
                finish(with: .success(transcript))
            }
        } else if let error {
            logger.error("STT error: \(error, privacy: .public)")
            finish(with: .failure(VoiceError.recognitionFailed(error)))
        }
    }

    private func finish(with result: Result<String, Error>) {
        if let cont = continuation {
            continuation = nil
            timeoutWorkItem?.cancel()
            switch result {
            case .success(let str): cont.resume(returning: str)
            case .failure(let err): cont.resume(throwing: err)
            }
        } else {
            recognitionResult = result              // deliver later in stopRecording()
        }
        cleanUp()
    }

    private func cleanUp() {
        task?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()

        request  = nil
        task     = nil
        audioEngine = nil
        isRecording = false

        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}
