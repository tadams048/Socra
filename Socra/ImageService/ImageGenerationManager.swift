// ImageGenerationManager.swift
// Queues, generates, validates, and caches Runware images.
// Updated 2025-07-30: added Combine import & simplified concurrency tracking.

import Foundation
import Combine
import os.log
import UIKit   // optional PNG validation only

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
    category: "ImageGenManager"
)

struct GeneratedImage: Equatable {
    let sentenceIndex: Int
    let url: URL
    let storyId: UUID
}

@MainActor
class ImageGenerationManager: ObservableObject {
    // ────────────── Public state ──────────────
    @Published var generatedImages: [GeneratedImage] = []

    // ────────────── Dependencies ──────────────
    private let imageGenService: ImageGenProvider
    private let timingLogger:   TimingProvider

    // ────────────── Tunables ────────────────
    private let maxImages         = 10
    private let maxPendingGens    = 4
    private let maxConcurrentGens = 2

    private let fallbackPrompt =
        "IMPORTANT PIXAR ANIMATION ART STYLE. IMPORTANT KID FRIENDLY. " +
        "A cheerful airplane flying in a bright blue sky."

    // Queues & counters
    private var pendingGenQueue: [(prompt: String, sentenceIndex: Int)] = []
    private var activeGenCount   = 0
    private var imageCount       = 0
    private var currentStoryId   = UUID()

    // MARK: – Init / reset
    init(
        imageGenService: ImageGenProvider = ImageGenService(),
        timingLogger: TimingProvider = TimingLogger()
    ) {
        self.imageGenService = imageGenService
        self.timingLogger    = timingLogger
    }

    func resetForNewStory(storyId: UUID) {
        currentStoryId  = storyId
        generatedImages = []
        imageCount      = 0
        pendingGenQueue = []
        activeGenCount  = 0
        logger.info("Image manager reset for story \(storyId)")
    }

    // MARK: – Public enqueue
    func enqueueImageGeneration(prompt: String, at sentenceIndex: Int) {
        guard imageCount < maxImages,
              pendingGenQueue.count < maxPendingGens,
              prompt.count > 30 else {
            logger.info("Enqueue skipped (limits hit or prompt too short)")
            return
        }

        pendingGenQueue.append((prompt, sentenceIndex))
        processGenQueue()
    }

    // MARK: – Queue engine
    private func processGenQueue() {
        guard activeGenCount < maxConcurrentGens,
              !pendingGenQueue.isEmpty else { return }

        let item = pendingGenQueue.removeFirst()
        activeGenCount += 1

        Task { [weak self] in
            await self?.generateImage(for: item)
        }
    }

    // MARK: – Worker
    private func generateImage(for item: (prompt: String, sentenceIndex: Int)) async {
        defer {
            activeGenCount = max(activeGenCount - 1, 0)
            processGenQueue()
        }

        for attempt in 1...2 {
            do {
                timingLogger.start(event: "RunwareGen")
                let url = try await imageGenService.generateImage(for: item.prompt)
                guard url.absoluteString.hasSuffix(".png"),
                      await isValidPNG(at: url) else {
                    throw NSError(domain: "ImageGen", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
                }

                let finalURL = await cachePNG(url) ?? url
                generatedImages.append(
                    GeneratedImage(sentenceIndex: item.sentenceIndex,
                                   url: finalURL,
                                   storyId: currentStoryId)
                )
                imageCount += 1
                timingLogger.end(event: "RunwareGen")
                return                        // ✅ success
            } catch {
                logger.error("Attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt == 2 { await generateFallback(for: item) }
            }
        }
    }

    // MARK: – Fallback
    private func generateFallback(for item: (prompt: String, sentenceIndex: Int)) async {
        do {
            timingLogger.start(event: "RunwareGenFallback")
            let url = try await imageGenService.generateImage(for: fallbackPrompt)
            guard url.absoluteString.hasSuffix(".png"),
                  await isValidPNG(at: url) else { return }

            let finalURL = await cachePNG(url) ?? url
            generatedImages.append(
                GeneratedImage(sentenceIndex: item.sentenceIndex,
                               url: finalURL,
                               storyId: currentStoryId)
            )
            imageCount += 1
            timingLogger.end(event: "RunwareGenFallback")
        } catch {
            logger.error("Fallback failed: \(error.localizedDescription)")
        }
    }

    // MARK: – Helpers
    private func isValidPNG(at url: URL) async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            return data.starts(with: [0x89, 0x50, 0x4E, 0x47]) // PNG magic
        } catch { return false }
    }

    private func cachePNG(_ remoteURL: URL) async -> URL? {
        let fm       = FileManager.default
        let cacheDir = fm.temporaryDirectory.appendingPathComponent("ImageCache")
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        // prune >10 files
        if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey]),
           files.count >= 10,
           let oldest = files.min(by: { (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast <
                                        (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast }) {
            try? fm.removeItem(at: oldest)
        }

        let fileURL = cacheDir.appendingPathComponent(UUID().uuidString + ".png")
        do {
            let (data, resp) = try await URLSession.shared.data(from: remoteURL)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  data.starts(with: [0x89, 0x50, 0x4E, 0x47]) else { return nil }
            try data.write(to: fileURL)
            return fileURL
        } catch {
            logger.error("Cache write failed: \(error.localizedDescription)")
            return nil
        }
    }
}
