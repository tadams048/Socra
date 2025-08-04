//
//  ThoughtShimmerView.swift
//  Socra
//
//  Loops a silent “thinking” animation *continuously* until a PNG arrives.
//  2025-08-03: switched to AVQueuePlayer + AVPlayerLooper so playback auto-resumes
//             after every AVAudioSession interruption (caused by mic recording).
//

import SwiftUI
import AVKit
import Combine

struct ThoughtShimmerView: View {

    // MARK: Player + looper
    @State private var queuePlayer: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?          // keep a strong ref
    @State private var interruptionCancellable: AnyCancellable?

    var body: some View {
        Group {
            if let player = queuePlayer {
                SquarePlayerContainer(player: player)   // keeps 1 : 1 crop
            } else {
                Color.clear                              // asset missing fallback
            }
        }
        .onAppear { setupLoop() }
        .onDisappear { queuePlayer?.pause()
                       interruptionCancellable?.cancel() }
    }

    // MARK: – Setup helper
    private func setupLoop() {
        guard queuePlayer == nil,
              let url = Bundle.main.url(forResource: "thought_shimmer",
                                        withExtension: "mp4")
        else { return }

        let item         = AVPlayerItem(url: url)
        let player       = AVQueuePlayer()
        let looper       = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted   = true
        player.play()

        queuePlayer = player
        self.looper = looper

        // Resume after any AVAudioSession interruption (e.g., mic start/stop)
        interruptionCancellable = NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .sink { _ in
                // If paused, kick it back into play
                if player.timeControlStatus != .playing {
                    player.play()
                }
            }
    }
}
