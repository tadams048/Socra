//
//  CharacterTileView.swift
//  Socra
//
//  Shows a thumbnail + name inside a rounded card.
//  Handles disabled/placeholder visuals.
//
import SwiftUI

struct CharacterTileView: View {
    let character: Character
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Border highlights the current character.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)

            VStack(spacing: 8) {
                Image(character.thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .opacity(character.isPlaceholder ? 0.3 : 1.0)

                Text(character.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(character.isPlaceholder ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .frame(width: 110, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(character.isPlaceholder ? 0.6 : 1)
        .overlay(
            // Lock icon on “coming soon”
            Group {
                if character.isPlaceholder {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
        )
    }
}
