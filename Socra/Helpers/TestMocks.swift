// TestMocks.swift (New file: For unit testing hooks)
import Foundation

// Mock for SpeechToTextProvider
class MockSpeechToTextProvider: SpeechToTextProvider {
    var mockTranscript: String = "Mock question"
    var shouldThrow: Bool = false
    
    func startRecording() async throws {
        if shouldThrow {
            throw VoiceError.recognitionFailed(NSError(domain: "Mock", code: -1))
        }
        // Simulate start
    }
    
    func stopRecording() async throws -> String {
        if shouldThrow {
            throw VoiceError.noSpeechDetected
        }
        return mockTranscript
    }
}

// Mock for TextToSpeechProvider
class MockTextToSpeechProvider: TextToSpeechProvider {
    func fetchAudio(for text: String, voiceID: String) async throws -> Data {
        return Data()  // Empty data for test
    }

    func fetchStreamingAudio(for text: String, voiceID: String) async throws -> Data {
        return Data()  // Empty data for test
    }
}

// Mock for AudioPlayerProvider
class MockAudioPlayerProvider: AudioPlayerProvider {
    var didPlay = false
    var didStop = false
    
    func playChunk(data: Data, completion: (() -> Void)?) {
        didPlay = true
        completion?()
    }
    
    func playFull(data: Data, completion: (() -> Void)?) {
        didPlay = true
        completion?()
    }
    
    func stop() {
        didStop = true
    }
    
    func reset() {
        // No-op for mock
    }
}

// Example usage in tests (add to XCTestCase):
/*
let mockManager = ConversationManager(ttsService: MockTextToSpeechProvider())
mockManager.stopSpeaking()
XCTAssertFalse(mockManager.isSpeaking)
*/
