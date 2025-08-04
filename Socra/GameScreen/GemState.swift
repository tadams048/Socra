// GemState.swift
import Foundation

enum GemState {
    case idle
    case listening
    case talking
    case processing
    case errorRetry  // Premium: New state for visual error feedback (e.g., red pulse)
}
