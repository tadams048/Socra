//
//  CharacterSelectionView.swift
//  Socra
//
//  Phase‑2 picker that lists all characters.
//  No asset/voice swapping here—that arrives in Phase 3.
//
import SwiftUI

struct CharacterSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var characterManager: CharacterManager

    // Grid layout: adaptive 110‑pt tiles
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(characterManager.characters) { character in
                        CharacterTileView(character: character,
                                          isSelected: character.id == characterManager.current.id)
                        .onTapGesture {
                            handleTap(character)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Choose a Character")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: – Logic
    private func handleTap(_ character: Character) {
        // 1) Placeholder tiles do nothing
        guard !character.isPlaceholder else { return }

        // 2) Custom‑creator tile (future Phase) just prints for now
        if character.isCreatorTile {
            print("TODO: Launch custom‑creator flow")
            return
        }

        // 3) Select & dismiss
        characterManager.select(character)
        dismiss()
    }
}
