// OpenAILLMProvider.swift
import Foundation
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
    category: "LLM"
)

class OpenAILLMProvider: LLMProvider {

    func streamChatResponse(messages: [[String: Any]])
        async throws -> AsyncThrowingStream<String, Error>
    {
        // ⬇︎ updated constant name
        var req = URLRequest(url: URL(string: Config.openAIChatURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "stream": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            logger.error("OpenAI response: \(http.statusCode)")
            throw VoiceError.llmFailed(NSError(domain: "OpenAI", code: http.statusCode))
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") && !line.hasPrefix("data: [DONE]") {
                            let data = Data(line.dropFirst(6).utf8)
                            let tokens = await OpenAIStreamParser().parseStream(from: data)
                            for token in tokens {
                                continuation.yield(token)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: VoiceError.networkError(error))
                }
            }
        }
    }
}
