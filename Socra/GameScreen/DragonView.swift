//
//  DragonView.swift
//  Socra
//
//  Starts or pauses its players based on `shouldPlay`.
//  Keeps the same @State across rotation, so no restart.
//

import SwiftUI
import AVKit

struct DragonView: View {
    let isSpeaking: Bool
    let shouldPlay: Bool                   // ⬅ new

    // Players & state
    @State private var talkingPlayer:   AVQueuePlayer?
    @State private var listeningPlayer: AVQueuePlayer?
    @State private var introPlayer:     AVPlayer?
    @State private var talkingLooper:   AVPlayerLooper?
    @State private var listeningLooper: AVPlayerLooper?

    @State private var talkingOpacity:   Double = 0
    @State private var listeningOpacity: Double = 0
    @State private var introOpacity:     Double = 1
    @State private var isPlayingIntro               = true
    @State private var playersInitialised           = false

    var body: some View {
        ZStack {
            if let introPlayer {
                SquarePlayerContainer(player: introPlayer)
                    .opacity(introOpacity)
                    .transition(.opacity)
            }
            if let talkingPlayer {
                SquarePlayerContainer(player: talkingPlayer)
                    .opacity(talkingOpacity)
                    .transition(.opacity)
            }
            if let listeningPlayer {
                SquarePlayerContainer(player: listeningPlayer)
                    .opacity(listeningOpacity)
                    .transition(.opacity)
            }
            Rectangle().fill(Color.clear)
        }
        .onAppear { if !playersInitialised { setupPlayers() } }
        .onChange(of: shouldPlay) { _, play in
            play ? resumePlayback() : pausePlayback()
        }
        .onChange(of: isSpeaking) { _, speaking in
            updateOpacity(speaking: speaking)
        }
        .onDisappear { pausePlayback() }
    }

    // — Setup (paused by default) —
    private func setupPlayers() {
        guard
            let talkURL   = Bundle.main.url(forResource: "Talking_dragon",   withExtension: "mp4"),
            let listenURL = Bundle.main.url(forResource: "Listening_dragon", withExtension: "mp4"),
            let introURL  = Bundle.main.url(forResource: "Enter_Right",      withExtension: "mp4")
        else { print("[DragonView] Missing MP4s"); return }

        // Intro (non-loop)
        introPlayer = AVPlayer(url: introURL)
        introPlayer?.isMuted = true

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: introPlayer?.currentItem,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: 0.5)) { introOpacity = 0 }
            isPlayingIntro = false
            updateOpacity(speaking: isSpeaking)
        }

        // Talking loop
        let talkItem = AVPlayerItem(url: talkURL)
        talkingPlayer = AVQueuePlayer()
        talkingLooper = AVPlayerLooper(player: talkingPlayer!, templateItem: talkItem)
        talkingPlayer?.isMuted = true

        // Listening loop
        let listenItem = AVPlayerItem(url: listenURL)
        listeningPlayer = AVQueuePlayer()
        listeningLooper = AVPlayerLooper(player: listeningPlayer!, templateItem: listenItem)
        listeningPlayer?.isMuted = true

        // Keep everyone paused until shouldPlay == true
        pausePlayback()
        listeningOpacity = 1            // default idle frame
        playersInitialised = true
    }

    // — Play / Pause in bulk —
    private func resumePlayback() {
        introPlayer?.seek(to: .zero)
        introPlayer?.play()
        talkingPlayer?.play()
        listeningPlayer?.play()
    }
    private func pausePlayback() {
        introPlayer?.pause()
        talkingPlayer?.pause()
        listeningPlayer?.pause()
    }

    // — Cross-fade between talking & listening loops —
    private func updateOpacity(speaking: Bool) {
        guard shouldPlay, !isPlayingIntro else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            if speaking {
                talkingOpacity   = 1
                listeningOpacity = 0
            } else {
                listeningOpacity = 1
                talkingOpacity   = 0
            }
        }
    }
}
