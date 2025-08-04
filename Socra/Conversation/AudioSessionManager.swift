// AudioSessionManager.swift
// Handles AVAudioSession configuration and route / interruption callbacks.

import AVFoundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app",
                            category: "AudioSession")

final class AudioSessionManager {

    private let session = AVAudioSession.sharedInstance()

    init() {
        setupObservers()
    }

    // MARK: – Public control
    func activate() throws {
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,            // enables AEC
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            logger.info("Audio session activated")
        } catch {
            logger.error("Audio session activation failed: \(error.localizedDescription, privacy: .public)")
            throw VoiceError.audioSessionFailure(error)
        }
    }

    func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        logger.info("Audio session deactivated")
    }

    // MARK: – Notifications
    private func setupObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification,
                       object: nil)

        nc.addObserver(self,
                       selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)
    }

    @objc private func handleInterruption(_ n: Notification) {
        guard
            let info = n.userInfo,
            let raw  = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            logger.info("Audio interruption began")
            // pause players if you want …

        case .ended:
            logger.info("Audio interruption ended – re-activating session")
            try? activate()

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ n: Notification) {
        if DebugFlags.audioRouteChanges {
            logger.debug("Audio route changed")
        }
        // You can inspect n.userInfo?[AVAudioSessionRouteChangeReasonKey] if you care.
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
