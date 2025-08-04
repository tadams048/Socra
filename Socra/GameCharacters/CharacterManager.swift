//
//  CharacterManager.swift
//  KidsConversationApp
//
//  Created by Socra‑AI on 2025‑08‑04.
//

import Foundation
import Combine
import SwiftUI

/// Top‑level manifest structure in `characters.json`.
private struct CharactersManifest: Codable {
    let schemaVersion: Int?
    let defaultCharacterId: String
    let characters: [Character]
}

/// Central source of truth for all character‑related state.
/// Phase 1 responsibilities:
///  • Parse `characters.json` once at launch.
///  • Expose `characters` for the picker grid.
///  • Publish `current` so other services (Gem, TTS, Conversation)
///    can observe changes.
@MainActor
final class CharacterManager: ObservableObject {

    // MARK: Public publishers
    @Published private(set) var characters: [Character] = []
    @Published var current: Character

    // MARK: Init
    init(bundle: Bundle = .main,
         manifestName: String = "characters",
         manifestExtension: String = "json")
    {
        // Attempt to load the manifest.
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        guard
            let url = bundle.url(forResource: manifestName, withExtension: manifestExtension),
            let data = try? Data(contentsOf: url),
            let manifest = try? decoder.decode(CharactersManifest.self, from: data),
            let firstCharacter = manifest.characters.first
        else {
            fatalError("❌ Unable to load or decode \(manifestName).\(manifestExtension)")
        }

        self.characters = manifest.characters

        // Pick default or fall back to first entry.
        self.current = manifest.characters.first(where: { $0.id == manifest.defaultCharacterId })
                    ?? firstCharacter
    }

    // MARK: User interaction
    func select(_ character: Character) {
        guard !character.isPlaceholder else { return }          // ignore “coming soon”
        if character.isCreatorTile {
            // A future Phase will present the “make your own character” flow.
            // For now we simply ignore the tap.
            return
        }
        current = character
    }
}
