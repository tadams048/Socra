//
//  ContentView.swift
//  Socra
//
//  Portrait  :  [Image] over [Dragon]
//  Landscape :  [Dragon] | [Image]
//

import SwiftUI
import AVFAudio
import AVFoundation
import StoreKit
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.funloop.Socra",
    category: "ContentView"
)

struct ContentView: View {

    // ── Injected / State ──────────────────────────────────────────
    private let speechRecognizer: SpeechToTextProvider
    @StateObject private var conversationManager: ConversationManager

    // Phase‑2 additions ↓
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var showingCharacterSheet = false
    // Phase‑2 additions ↑

    @State private var gemState: GemState = .idle
    @State private var micPermissionGranted = false
    @State private var errorMessage: String?
    @State private var showFreeTrial = true         // pay‑wall flag

    @StateObject private var storeManager = StoreManager()

    /// Referenced by ConversationManager on first greet
    static let greetingText = """
    Hello I’m Rex! Do you want to hear a story? \
    Tap and hold the diamond to talk to me!
    """

    // ── Init ───────────────────────────────────────────────────────
    init() {
        let recognizer = SpeechRecognizer()
        self.speechRecognizer = recognizer
        _conversationManager  = StateObject(
            wrappedValue: ConversationManager(speechRecognizer: recognizer)
        )
    }

    // ── Body ───────────────────────────────────────────────────────
    var body: some View {
        NavigationStack {               // ← wrapped in NavigationStack to host toolbar
            GeometryReader { geo in
                let isPortrait = geo.size.height >= geo.size.width
                let square: CGFloat = isPortrait
                    ? min(geo.size.width,  geo.size.height / 2)
                    : min(geo.size.height, geo.size.width  / 2)

                ZStack {
                    Color(.systemBackground).ignoresSafeArea()

                    // — Adaptive layout (IDs keep state on rotate) —
                    Group {
                        if isPortrait {
                            VStack(spacing: 0) {
                                illustrationSquare(of: square).id("illustration")
                                dragonSquare(of: square).id("dragon")
                            }
                        } else {
                            HStack(spacing: 0) {
                                dragonSquare(of: square).id("dragon")
                                illustrationSquare(of: square).id("illustration")
                            }
                        }
                    }

                    // — Gem + error banner —
                    VStack {
                        Spacer()
                        if micPermissionGranted { gem }
                        if let err = errorMessage { errorText(err) }
                    }
                    .padding(.bottom,
                             geo.safeAreaInsets.bottom + (isPortrait ? 4 : 12))
                }
            }
            // — React to state changes —
            .onChange(of: conversationManager.errorMessage) { _, msg in
                errorMessage = msg
            }
            .onChange(of: conversationManager.isSpeaking) { _, speaking in
                gemState = speaking ? .talking : .idle
            }
            .onChange(of: showFreeTrial) { _, presented in
                if !presented { configureSession() }
            }
            .fullScreenCover(isPresented: $showFreeTrial) { FreeTrialView() }
            .task {
                await storeManager.load()
                if storeManager.isSubscribed { showFreeTrial = false }
            }
            // ── Phase‑2 toolbar + sheet ──────────────────────────
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCharacterSheet = true
                    } label: {
                        Image(systemName: "person.crop.square")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Choose a character")
                }
            }
            .sheet(isPresented: $showingCharacterSheet) {
                CharacterSelectionView()
                    .environmentObject(characterManager)
            }
            // ─────────────────────────────────────────────────────
        }
        .navigationBarTitleDisplayMode(.inline)   // keeps nav bar compact
    }

    // ── Squares ───────────────────────────────────────────────────
    @ViewBuilder
    private func illustrationSquare(of size: CGFloat) -> some View {
        ImageDisplayView(conversationManager: conversationManager, size: size)
            .modifier(CardStyle())
    }

    @ViewBuilder
    private func dragonSquare(of size: CGFloat) -> some View {
        DragonView(
            isSpeaking: conversationManager.isSpeaking,
            shouldPlay: !showFreeTrial          // ⬅ gate playback
        )
        .frame(width: size, height: size)
        .modifier(CardStyle())
    }

    // ── Gem button ────────────────────────────────────────────────
    private var gem: some View {
        GemView(state: $gemState)
            .frame(width: 200, height: 200)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if conversationManager.isSpeaking {
                            conversationManager.stopSpeaking()
                        }
                        gemState = .listening
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        Task { try? await speechRecognizer.startRecording() }
                    }
                    .onEnded { _ in
                        gemState = .processing
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        Task {
                            do {
                                let text = try await speechRecognizer.stopRecording()
                                if text.isEmpty {
                                    errorMessage = "No speech detected. Try again?"
                                    gemState = .idle
                                } else {
                                    conversationManager.userDidSubmit(text)
                                }
                            } catch {
                                errorMessage = "Speech error: \(error.localizedDescription)"
                                gemState = .idle
                            }
                        }
                    }
            )
    }

    // ── Helpers ───────────────────────────────────────────────────
    private func errorText(_ msg: String) -> some View {
        Text(msg)
            .font(.subheadline)
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord,
                                 mode: .voiceChat,
                                 options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)

        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
                if granted {
                    conversationManager.speak(ContentView.greetingText)
                } else {
                    errorMessage = "Microphone access is required. Enable it in Settings."
                }
            }
        }
    }
}

// ── CardStyle (unchanged) ─────────────────────────────────────────
private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.482, green: 0.231, blue: 1.000),
                                Color(red: 0.608, green: 0.376, blue: 1.000),
                                Color(red: 0.482, green: 0.231, blue: 1.000)
                            ]),
                            center: .center
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 24, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 4,  y: 2)
    }
}
