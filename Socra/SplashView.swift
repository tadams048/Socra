//
//  SplashView.swift
//  Socra
//
//  Full-screen looping “thought_shimmer” until the app is ready.
//  Fades to ContentView() with a smooth cross-fade.
//

import SwiftUI
import AVKit

struct SplashView: View {
    @State private var isReady = false
    @State private var player: AVQueuePlayer?          // keeps looping
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack {
            if let player {
                FullScreenPlayerContainer(player: player)
                    .opacity(0.55)                     // dim for readability
                    .blur(radius: 8)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if isReady {
                ContentView()
                    .transition(.opacity)
            }
        }
        .task { await bootAndLoop() }
    }

    // MARK: – Boot
    private func bootAndLoop() async {
        // start video loop immediately
        if player == nil, let url = Bundle.main.url(forResource: "thought_shimmer",
                                                    withExtension: "mp4") {
            let item   = AVPlayerItem(url: url)
            let queue  = AVQueuePlayer()
            looper     = AVPlayerLooper(player: queue, templateItem: item)
            queue.isMuted = true
            queue.play()
            player = queue
        }

        // preload heavy dependencies (simulate 1.2-s boot)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        // … e.g. await AppDependencies.shared.storeManager.load()

        withAnimation(.easeOut(duration: 0.4)) {
            isReady = true
            player?.pause()        // stop splash animation
        }
    }
}

// ──────────────────────────────────────────────────────────────
// MARK: – Helper: edge-to-edge aspect-fill video container
// ──────────────────────────────────────────────────────────────
private struct FullScreenPlayerContainer: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView { PlayerView(player) }
    func updateUIView(_ uiView: UIView, context: Context) { }

    private final class PlayerView: UIView {
        init(_ p: AVPlayer) {
            super.init(frame: .zero)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.player       = p
        }
        required init?(coder: NSCoder) { fatalError() }
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
