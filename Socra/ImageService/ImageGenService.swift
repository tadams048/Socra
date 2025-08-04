import Foundation
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
    category: "ImageGen"
)

protocol ImageGenProvider {
    func generateImage(for prompt: String) async throws -> URL
}

/// Concrete Runware.ai implementation
class ImageGenService: ImageGenProvider {

    private let maxRetries = 2

    func generateImage(for prompt: String) async throws -> URL {
        AppDependencies.shared.timingLogger.start(event: "RunwareGen")

        guard !Config.runwareApiKey.isEmpty else {
            throw NSError(domain: "ImageGen", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Runware API key missing"])
        }
        guard let endpoint = URL(string: Config.runwareEndpointURL) else {
            throw NSError(domain: "ImageGen", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid Runware endpoint"])
        }

        for attempt in 1...maxRetries {
            do {
                let url = try await internalGenerate(prompt: prompt, endpoint: endpoint)
                AppDependencies.shared.timingLogger.end(event: "RunwareGen")
                return url
            } catch {
                logger.error("Runware attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < maxRetries {
                    try await Task.sleep(for: .milliseconds(500 * attempt))
                }
            }
        }

        AppDependencies.shared.timingLogger.end(event: "RunwareGen")
        // ultimate fallback → bundled placeholder
        if let fallback = Bundle.main.url(forResource: "fallback_dragon_placeholder", withExtension: "png") {
            return fallback
        }
        throw NSError(domain: "ImageGen", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Image generation failed"])
    }

    // MARK: – Low-level request
    private func internalGenerate(prompt: String, endpoint: URL) async throws -> URL {
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(Config.runwareApiKey)", forHTTPHeaderField: "Authorization")

        // Assemble body
        let taskUUID = UUID().uuidString.lowercased()
        let body: [[String: Any]] = [[
            "taskType": "imageInference",
            "taskUUID": taskUUID,
            "positivePrompt": ImageGenSystemPrompt.content + " " + prompt,
            "model": Config.runwareModel,
            "steps": 4,
            "width": 512,
            "height": 512,
            "numberResults": 1,
            "outputType": "URL",
            "outputFormat": "PNG"
        ]]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let msg = parseErrorMessage(from: data) ?? "Runware response error"
            throw NSError(domain: "Runware", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let urlString = first["imageURL"] as? String,
              let imageURL = URL(string: urlString) else {
            throw NSError(domain: "Runware", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Malformed Runware response"])
        }

        logger.info("Runware generated image: \(imageURL.absoluteString)")
        return imageURL
    }

    // Parse {"errors":[{"message": "..."}]}
    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errors = json["errors"] as? [[String: Any]],
              let first = errors.first,
              let msg = first["message"] as? String else { return nil }
        return msg
    }
}
