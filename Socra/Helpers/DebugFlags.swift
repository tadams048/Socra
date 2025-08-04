// DebugFlags.swift
// Centralised on/off switches for verbose logging & instrumentation.

import Foundation

struct DebugFlags {

    // MARK: – Audio & streaming
    static let micInputLevel       = false   // STT mic RMS levels
    static let streamingParsing    = false   // Raw OpenAI chunk JSON
    static let onChunkStart        = false   // “Firing onChunkStart …”
    static let audioPlayback       = false   // Queue-player lifecycle + chunk queuing
    static let audioFileCreation   = false   // Temp .mp3 path printouts

    // MARK: – Speech-to-text
    static let partialTranscript   = false   // Intermediate STT results
    static let sttLifecycle        = false   // Start/stop recogniser messages

    // MARK: – Image generation & display
    static let imageGenTiming      = false   // Runware timing spans
    static let imageSelection      = false   // “Selecting image for idx …”

    // MARK: – Timing & profiling
    static let timingEvents        = false   // High-level latency spans

    static let imageGenURL        = false   // “Runware generated image: …”
    static let audioRouteChanges  = false   // AVAudioSession route-change spam
}

