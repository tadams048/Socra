// TimingLogger.swift (New: Microservice for centralized, toggleable latency profiling)
import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app", category: "Timing")

protocol TimingProvider {
    func start(event: String)
    func end(event: String)
}

class TimingLogger: TimingProvider {
    private var startTimes: [String: Date] = [:]
    
    func start(event: String) {
        if DebugFlags.timingEvents {
            startTimes[event] = Date()
            logger.info("[TIMING] Started: \(event)")
        }
    }
    
    func end(event: String) {
        if DebugFlags.timingEvents, let start = startTimes[event] {
            let duration = Date().timeIntervalSince(start)
            logger.info("[TIMING] Ended: \(event), duration: \(duration) seconds")
            startTimes.removeValue(forKey: event)
        }
    }
}
