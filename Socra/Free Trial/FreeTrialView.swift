//
//  FreeTrialView.swift
//  Socra
//

import SwiftUI
import AVKit
import os.log

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "funloop.Socra",
    category: "FreeTrialView"
)

// ─────────────────────────────────────────────────────────────
// MARK: – Main View
// ─────────────────────────────────────────────────────────────
struct FreeTrialView: View {
    @Environment(\.dismiss)               private var dismiss
    @Environment(\.horizontalSizeClass)   private var hSize

    private static let pool = [
        "Why does electricity zap?","Why do roads get broken?",
        "Why do we need shoes?","Where do fish poo?",
        "Why are leaves green?","Why does thunder boom?",
        "Why is the sky blue?","Where does the sun go at night?",
        "How do birds stay up in the air?","Why do cats purr?",
        "Where does the wind come from?","Why do onions make us cry?",
        "How do magnets stick to the fridge?","Why is the ocean salty?",
        "Where do bugs sleep?","Why do we have eyebrows?"
    ]

    @State private var sliceIndex   = 0           // which group of 8 questions
    @State private var boardTrigger = 0           // forces QuestionBoard refresh

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // ── Shimmering background (full‑screen, muted loop) ────────────
            ShimmerBackground()
                .opacity(0.65)
                .allowsHitTesting(false)          // never block taps
                .overlay(                         // subtle gradient for contrast
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )

            VStack(spacing: 0) {

                // ── Hero video card ───────────────────────────────────────
                HeroVideo(boardTrigger: $boardTrigger)
                    .padding(.top, 60)

                Spacer(minLength: 24)

                // ── Headline & sub‑deck ───────────────────────────────────
                Group {
                    Text("Your Kid‑Friendly AI for Curious Minds")
                        .font(.system(size: 30, weight: .heavy))
                        .tracking(0.6)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)

                    Text("An infinitely patient tutor ready to answer every curious question.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6E6E"))
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // ── Benefit grid ─────────────────────────────────────────
                BenefitGrid()
                    .padding(.top, 32)

                // ── Cycling question board ───────────────────────────────
                QuestionBoard(texts: slice())
                    .id(boardTrigger)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .top).combined(with: .opacity)
                    ))
                    .padding(.top, 28)

                Spacer(minLength: 24)

                // ── CTA & legal ──────────────────────────────────────────
                VStack(spacing: 12) {
                    CTAButton()

                    HStack(spacing: 24) {
                        Link("Privacy Policy",
                             destination: URL(string: "https://YOURDOMAIN.com/privacy")!)
                        Link("Terms of Service",
                             destination: URL(string: "https://YOURDOMAIN.com/terms")!)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(.bottom, hSize == .regular ? 48 : 32)
            }

            // ── Close button (always on top) ─────────────────────────────
            closeButton
                .zIndex(10)
        }
        .accessibilityElement(children: .contain)
    }

    // ───────────────────────────────────────────────────────────
    // MARK: – Close button
    // ───────────────────────────────────────────────────────────
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#7B3BFF"))
                .frame(width: 44, height: 44)                 // 44‑pt tap target
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#7B3BFF"),
                                Color(hex: "#9B60FF"),
                                Color(hex: "#7B3BFF")
                            ]),
                            center: .center
                        ),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 44)                                    // below status bar
        .accessibilityLabel("Dismiss")
    }

    private func slice() -> [String] {
        let start = sliceIndex * 8
        let end   = min(start + 8, Self.pool.count)
        return Array(Self.pool[start..<end])
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – Shimmer video background (full‑screen loop)
// ─────────────────────────────────────────────────────────────
private struct ShimmerBackground: View {
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        Group {
            if let player {
                PlayerContainer(player: player)
            } else {
                Color(red: 0.94, green: 0.93, blue: 1.00)    // fallback tint
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard player == nil,
                  let url = Bundle.main.url(forResource: "thought_shimmer", withExtension: "mp4") else { return }

            let item  = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            looper    = AVPlayerLooper(player: queue, templateItem: item)
            queue.isMuted = true
            queue.play()
            player = queue
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – Hero video card (4:3, always muted)
// ─────────────────────────────────────────────────────────────
private struct HeroVideo: View {
    @State   private var player: AVPlayer?
    @Binding var boardTrigger: Int

    var body: some View {
        GeometryReader { geo in
            let width  = min(geo.size.width * 0.8,
                             geo.size.width < 500 ? 360 : 560)
            let height = width * 3 / 4

            PlayerContainer(player: player)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .modifier(CardShadow())
                .frame(maxWidth: .infinity)
                .onAppear(perform: setupPlayer)
        }
        .frame(height: UIScreen.main.bounds.height * 0.5)
    }

    private func setupPlayer() {
        guard player == nil else { return }

        guard
            let introURL = Bundle.main.url(forResource: "Enter_Right",  withExtension: "mp4"),
            let loopURL  = Bundle.main.url(forResource: "Excited_Fire", withExtension: "mp4")
        else { log.error("Video assets missing"); return }

        let intro = AVPlayerItem(url: introURL)
        let loop  = AVPlayerItem(url: loopURL)

        player = AVPlayer(playerItem: intro)
        player?.isMuted = true
        player?.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: intro,
            queue: .main
        ) { _ in
            player?.replaceCurrentItem(with: loop)
            player?.play()
            boardTrigger += 1

            player?.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: loop,
                queue: .main
            ) { _ in
                player?.seek(to: .zero); player?.play()
                boardTrigger += 1
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – Benefit grid
// ─────────────────────────────────────────────────────────────
private struct BenefitGrid: View {
    @Environment(\.horizontalSizeClass) private var hSize

    private let items = [
        "Kid-first UI they can navigate",
        "Kid-safe answers & safeguards",
        "Parent dashboard of activity",
        "Parent ↔︎ Child analytics"
    ]

    private var columns: [GridItem] {
        hSize == .regular
        ? [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)]
        : [GridItem(.flexible())]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(items, id: \.self) { txt in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "#7B3BFF"))
                        .frame(width: 6, height: 6)
                    Text(txt)
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.86))
                }
            }
        }
        .frame(maxWidth: 600)
        .accessibilityLabel("Benefits")
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – Question board
// ─────────────────────────────────────────────────────────────
private struct QuestionBoard: View {
    let texts: [String]
    private let cols = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(texts, id: \.self) { q in
                Text(q)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#444"))
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#F2F2F5"))
                            .overlay(
                                Capsule().stroke(Color.white, lineWidth: 1)
                            )
                    )
            }
        }
        .frame(maxWidth: 460)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – CTA button
// ─────────────────────────────────────────────────────────────
private struct CTAButton: View {
    @State private var pressed = false

    var body: some View {
        Button(action: {}) {
            Text("Start Your Free Trial")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 40)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#9B60FF"), Color(hex: "#7B3BFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                )
                .scaleEffect(pressed ? 0.96 : 1)
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { isPressing in
            withAnimation(.easeInOut(duration: 0.12)) { pressed = isPressing }
        }, perform: {})
        .accessibilityLabel("Start free-trial subscription")
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: – PlayerContainer & CardShadow
// ─────────────────────────────────────────────────────────────
struct PlayerContainer: UIViewRepresentable {
    let player: AVPlayer?
    func makeUIView(context: Context) -> UIView { PlayerView(player) }
    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? PlayerView)?.playerLayer.player = player
    }
    private final class PlayerView: UIView {
        init(_ p: AVPlayer?) {
            super.init(frame: .zero)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.player       = p
        }
        required init?(coder: NSCoder) { fatalError() }
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

private struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.05), radius: 24, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 4,  y: 2)
    }
}
