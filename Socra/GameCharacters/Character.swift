//
//  Character.swift
//  KidsConversationApp
//
//  Created by Socra‑AI on 2025‑08‑04.
//

import Foundation
import SwiftUI

/// One entry from `characters.json`.
/// ───────────────────────────────────────────────────────
/// • 100 % Codable so we can decode directly from disk or a
///   remote JSON payload.
/// • Conforms to `Identifiable` & `Hashable` for SwiftUI lists.
/// • Keeps `animations` flexible by storing a `[String:String]` map.
///   The keys are the phase names (“enter”, “idle”…).
struct Character: Identifiable, Codable, Hashable {

    // MARK: Nested types
    enum Phase: String, CaseIterable {
        case enter, idle, speaking, listening
    }

    // MARK: Manifest keys
    let id: String
    let displayName: String
    let thumbnail: String
    let voiceID: String?
    let greeting: String
    let promptInjection: String
    let animations: [String: String]

    // Optional keys
    let ageRange: String?
    let difficulty: String?
    let placeholder: Bool?
    let isCreator: Bool?

    // MARK: Convenience flags
    var isPlaceholder: Bool { placeholder == true }
    var isCreatorTile: Bool { isCreator == true }

    // MARK: Asset helpers
    /// Returns a local‑bundle URL for the requested phase,
    /// or `nil` if it cannot be resolved.
    func url(for phase: Phase, in bundle: Bundle = .main) -> URL? {
        guard let path = animations[phase.rawValue] else { return nil }
        // Absolute URL (e.g. http…) – just forward it.
        if let absolute = URL(string: path), absolute.scheme?.hasPrefix("http") == true {
            return absolute
        }
        // Otherwise treat as a resource in the given bundle.
        let fileName = (path as NSString).deletingPathExtension
        let ext = (path as NSString).pathExtension
        return bundle.url(forResource: fileName, withExtension: ext.isEmpty ? nil : ext)
    }
}
