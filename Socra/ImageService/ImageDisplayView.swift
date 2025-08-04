//
//  ImageDisplayView.swift
//  Socra
//
//  Square illustration view with cross-fade + thought-bubble placeholder.
//  2025-08-01: redesigned for stacked / side-by-side layout.
//  2025-08-02: updated for iOS 17 onChange API & main-actor isolation.
//

import SwiftUI
import os.log

private let imgLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.funloop.Socra",
    category: "ImageDisplay"
)

struct ImageDisplayView: View {
    // ╭──────────────────── external state ───────────────────╮
    @ObservedObject var conversationManager: ConversationManager
    let size: CGFloat                                          // enforced square
    // ╰────────────────────────────────────────────────────────╯

    // Cross-fade state
    @State private var displayedURL: URL?
    @State private var nextURL:       URL?
    @State private var showNext       = false
    @State private var lastURL:       URL?
    @State private var lastUpdate:    Date = .distantPast

    // Timer to poll for late images
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // ── Base layer ─────────────────────────────────────────────
            AsyncImage(url: displayedURL) { phase in
                switch phase {
                case .empty:
                    ThoughtShimmerView()                     // ✨ placeholder
                case .success(let image):
                    fadeable(image, hidden: showNext)
                case .failure:
                    fadeable(Image("fallback_dragon_placeholder"), hidden: showNext)
                @unknown default:
                    EmptyView()
                }
            }

            // ── Incoming layer ─────────────────────────────────────────
            AsyncImage(url: nextURL) { phase in
                if case .success(let image) = phase {
                    fadeable(image, hidden: !showNext)
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()                                           // guarantee square
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }

        // 🔄 iOS 17 two-value onChange overloads
        .onChange(of: conversationManager.currentSentenceIndex) { _, _ in
            updateImage()
        }
        .onChange(of: conversationManager.imageGenManager.generatedImages) { _, _ in
            updateImage()
        }
    }

    // MARK: – Helpers
    private func fadeable(_ img: Image, hidden: Bool) -> some View {
        img.resizable()
           .scaledToFill()
           .opacity(hidden ? 0 : 1)
           .animation(.easeInOut(duration: 0.5), value: hidden)
           .accessibilityHidden(true)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Ensure we’re on the main actor before calling the isolated method
            Task { @MainActor in
                updateImage()
            }
        }
    }

    @MainActor
    private func updateImage() {
        let now = Date()
        if displayedURL != nil, now.timeIntervalSince(lastUpdate) < 4 { return }

        let idx = conversationManager.currentSentenceIndex
        let candidate = conversationManager.imageGenManager.generatedImages
            .last { $0.storyId == conversationManager.currentStoryId &&
                    $0.sentenceIndex <= idx }?.url

        guard candidate != lastURL else { return }

        nextURL    = candidate
        showNext   = true
        lastURL    = candidate
        lastUpdate = now

        // after fade-in, swap layers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            displayedURL = nextURL
            showNext     = false
        }
    }
}
