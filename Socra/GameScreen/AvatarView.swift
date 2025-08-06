//
//  AvatarView.swift   (a.k.a. CharacterAnimationView)
//  Socra
//
//  Phase 3 – manifest‑driven video player
//  • Keeps square, aspect‑fill crop via SquarePlayerContainer
//  • Intro once, then idle/speaking loops with 0.25 s cross‑fade
//

import SwiftUI
import AVKit
import Combine

struct AvatarView: View {

    // Inputs from parent
    let isSpeaking: Bool
    let shouldPlay: Bool

    // Character context
    @EnvironmentObject private var characterManager: CharacterManager

    // Players
    @State private var introPlayer:     AVPlayer?
    @State private var idlePlayer:      AVQueuePlayer?
    @State private var speakingPlayer:  AVQueuePlayer?
    @State private var idleLooper:      AVPlayerLooper?
    @State private var speakingLooper:  AVPlayerLooper?

    // UI state
    @State private var introOpacity:    Double = 1
    @State private var idleOpacity:     Double = 0
    @State private var speakingOpacity: Double = 0
    @State private var playersReady                 = false
    @State private var cancellables = Set<AnyCancellable>()

    // MARK: – Body
    var body: some View {
        ZStack {
            if let introPlayer {
                SquarePlayerContainer(player: introPlayer)
                    .opacity(introOpacity)
            }
            if let idlePlayer {
                SquarePlayerContainer(player: idlePlayer)
                    .opacity(idleOpacity)
            }
            if let speakingPlayer {
                SquarePlayerContainer(player: speakingPlayer)
                    .opacity(speakingOpacity)
            }
            Rectangle().fill(Color.clear)           // keeps stack size
        }
        .onAppear { configurePlayers(for: characterManager.current,
                                     playIntro: false) }
        .onChange(of: characterManager.current) { newChar in
            configurePlayers(for: newChar, playIntro: true)
        }
        .onChange(of: isSpeaking) { speaking in
            withAnimation(.easeInOut(duration: 0.25)) {
                if speaking {
                    speakingOpacity = 1
                    idleOpacity     = 0
                } else {
                    idleOpacity     = 1
                    speakingOpacity = 0
                }
            }
        }
        .onChange(of: shouldPlay) { play in
            play ? resumeAll() : pauseAll()
        }
    }

    // MARK: – Player setup
    private func configurePlayers(for character: Character, playIntro: Bool) {
        pauseAll()
        clearPlayers()
        playersReady = false

        // URLs with legacy fallback
        let introURL    = resolvedURL(for: .enter,    in: character)
        let idleURL     = resolvedURL(for: .idle,     in: character)
        let speakingURL = resolvedURL(for: .speaking, in: character)

        // Intro (non‑loop)
        if let url = introURL {
            introPlayer = AVPlayer(url: url)
            introPlayer?.isMuted = true
            NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime,
                                                 object: introPlayer?.currentItem)
                .prefix(1)
                .sink { _ in
                    withAnimation(.easeInOut(duration: 0.5)) { introOpacity = 0 }
                }
                .store(in: &cancellables)
        }

        // Idle loop
        if let url = idleURL {
            let item = AVPlayerItem(url: url)
            idlePlayer = AVQueuePlayer()
            idleLooper = AVPlayerLooper(player: idlePlayer!, templateItem: item)
            idlePlayer?.isMuted = true
            idleOpacity = 1                                   // default frame
        }

        // Speaking loop
        if let url = speakingURL {
            let item = AVPlayerItem(url: url)
            speakingPlayer = AVQueuePlayer()
            speakingLooper = AVPlayerLooper(player: speakingPlayer!, templateItem: item)
            speakingPlayer?.isMuted = true
        }

        playersReady = true

        if shouldPlay { resumeAll(playIntro: playIntro) }
    }

    private func resumeAll(playIntro: Bool = true) {
        guard playersReady else { return }
        if playIntro { introPlayer?.seek(to: .zero) }
        introPlayer?.play()
        idlePlayer?.play()
        speakingPlayer?.play()
    }
    private func pauseAll() {
        introPlayer?.pause()
        idlePlayer?.pause()
        speakingPlayer?.pause()
    }
    private func clearPlayers() {
        introPlayer = nil
        idlePlayer = nil
        speakingPlayer = nil
        cancellables.removeAll()
    }

    // MARK: – URL resolver with legacy fallback
    private func resolvedURL(for phase: Character.Phase, in character: Character) -> URL? {
        if let url = character.url(for: phase) {
            return url
        }
        let legacyName: String = {
            switch phase {
            case .enter:     return "Enter_Right"
            case .idle:      return "Listening_dragon"
            case .speaking:  return "Talking_dragon"
            case .listening: return "Listening_dragon"
            }
        }()
        return Bundle.main.url(forResource: legacyName, withExtension: "mp4")
    }
}
