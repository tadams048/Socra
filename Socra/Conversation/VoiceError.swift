// VoiceError.swift
import Foundation

enum VoiceError: Error, LocalizedError {
    case permissionDenied
    case audioSessionFailure(Error)
    case recognitionFailed(Error)
    case ttsFailed(Error)
    case llmFailed(Error)
    case timeout
    case networkError(Error)
    case initializationFailed
    case unavailable
    case engineStartFailed(underlying: Error)
    case noSpeechDetected
    case notRecording
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone access is required. Please enable in Settings."
        case .audioSessionFailure(let error): return "Audio setup failed: \(error.localizedDescription)"
        case .recognitionFailed(let error): return "Speech recognition error: \(error.localizedDescription)"
        case .ttsFailed(let error): return "Voice synthesis error: \(error.localizedDescription)"
        case .llmFailed(let error): return "AI response error: \(error.localizedDescription)"
        case .timeout: return "Operation timed out. Please try again."
        case .networkError(let error): return "Network issue: \(error.localizedDescription)"
        case .initializationFailed: return "Failed to initialize speech recognizer."
        case .unavailable: return "Speech recognizer not available."
        case .engineStartFailed(let underlying): return "Failed to start audio engine: \(underlying.localizedDescription)"
        case .noSpeechDetected: return "No speech detected. Try speaking louder."
        case .notRecording: return "Not recording."
        }
    }
}
