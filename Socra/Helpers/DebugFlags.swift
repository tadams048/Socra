// DebugFlags.swift
// Centralised on/off switches for verbose logging & instrumentation.

import Foundation

struct DebugFlags {

    // MARK: – Audio & streaming
    static let micInputLevel       = true   // STT mic RMS levels
    static let streamingParsing    = true   // Raw OpenAI chunk JSON
    static let onChunkStart        = true   // “Firing onChunkStart …”
    static let audioPlayback       = true   // Queue-player lifecycle + chunk queuing
    static let audioFileCreation   = true   // Temp .mp3 path printouts

    // MARK: – Speech-to-text
    static let partialTranscript   = true   // Intermediate STT results
    static let sttLifecycle        = true   // Start/stop recogniser messages

    // MARK: – Image generation & display
    static let imageGenTiming      = true   // Runware timing spans
    static let imageSelection      = true   // “Selecting image for idx …”

    // MARK: – Timing & profiling
    static let timingEvents        = true   // High-level latency spans

    static let imageGenURL        = true   // “Runware generated image: …”
    static let audioRouteChanges  = true   // AVAudioSession route-change spam
}

