// Revelia/Views/BiomeCompleteView.swift

import SwiftUI

/// Summary screen shown when the player completes the final level of a biome.
///
/// Replaces the normal EndOfLevelView for biome-final levels only.
/// Displays the biome name, an icon, total stars earned across all biome levels,
/// and a single "Return to Map" button.
///
/// For campaign-final levels (L74 square, L148 hex) the header changes to
/// "Campaign Complete!" instead of "Biome Complete!".
struct BiomeCompleteView: View {
    let biomeName: String
    let biomeIcon: String
    let starsEarned: Int
    let totalStarsPossible: Int
    let isCampaignComplete: Bool
    let onReturnToMap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Biome icon
            Image(systemName: biomeIcon)
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
                .padding(.bottom, 4)

            // Header
            Text(isCampaignComplete ? "Campaign Complete!" : "Biome Complete!")
                .font(.title.weight(.bold))
                .foregroundColor(.green)

            // Biome name
            Text(biomeName)
                .font(.title3.weight(.medium))
                .foregroundColor(.primary)

            // Star summary
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(starsEarned) / \(totalStarsPossible)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.title3)

            // Congratulatory message
            Text(congratulatoryMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, 4)

            // Return to Map button
            Button(action: onReturnToMap) {
                Text("Return to Map")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top, 8)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private var congratulatoryMessage: String {
        if isCampaignComplete {
            return "You've conquered every biome. The signals are clear."
        }
        return "Every signal in \(biomeName) decoded. A new biome awaits."
    }
}
