//
//  Character.swift
//  Socra
//
//  Updated for Phase 4 – adds `greetingAudio` and makes `voiceID` optional.
//

import Foundation
import SwiftUI

struct Character: Identifiable, Codable, Hashable {

    enum Phase: String, CaseIterable {
        case enter, idle, speaking, listening
    }

    // Manifest keys
    let id: String
    let displayName: String
    let thumbnail: String
    let voiceID: String?                  // ← was String, now optional
    let greeting: String
    let greetingAudio: String?            // ← NEW
    let promptInjection: String
    let animations: [String: String]

    // Optional extras
    let ageRange: String?
    let difficulty: String?
    let placeholder: Bool?
    let isCreator: Bool?

    var isPlaceholder: Bool { placeholder == true }
    var isCreatorTile: Bool { isCreator == true }

    // Asset resolver
    func url(for phase: Phase, in bundle: Bundle = .main) -> URL? {
        guard let path = animations[phase.rawValue] else { return nil }
        if let url = URL(string: path), url.scheme?.hasPrefix("http") == true { return url }
        let fileName = (path as NSString).deletingPathExtension
        let ext      = (path as NSString).pathExtension
        return bundle.url(forResource: fileName, withExtension: ext.isEmpty ? nil : ext)
    }

    /// Resolves the optional greeting MP3 listed in the manifest.
    func greetingAudioURL(in bundle: Bundle = .main) -> URL? {
        guard let file = greetingAudio else { return nil }
        if let url = URL(string: file), url.scheme?.hasPrefix("http") == true { return url }
        let name = (file as NSString).deletingPathExtension
        let ext  = (file as NSString).pathExtension.isEmpty ? "mp3" : (file as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext)
    }
}
