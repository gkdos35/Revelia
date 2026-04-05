// Revelia/Views/BiomeIntroOverlay.swift

import SwiftUI

/// A "here's the new mechanic" card shown when the player enters the first level of a biome.
///
/// Appears as a full-screen translucent overlay on top of the game board.
/// Dismissed by clicking the "Got it" button, tapping the dimmed background,
/// or pressing any key. GameView drives visibility with a @State bool that
/// resets on every level load, so this overlay re-appears every time the
/// player starts that biome's opening level — no persistence involved.
struct BiomeIntroOverlay: View {
    let title: String
    let icon: String     // SF Symbol name
    let message: String  // Multi-line explanation; supports \n for line breaks
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background — tapping anywhere dismisses
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Card
            VStack(spacing: 20) {
                // Biome icon
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white)

                // Title
                Text(title)
                    .font(.title.weight(.semibold))
                    .foregroundColor(.white)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 1)
                    .padding(.horizontal, 8)

                // Mechanic explanation
                Text(message)
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.90))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.4))
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
        }
        // Any key press dismisses the overlay
        .onKeyPress { _ in
            onDismiss()
            return .handled
        }
    }
}

#Preview {
    BiomeIntroOverlay(
        title: "Frozen Mirrors",
        icon: "arrow.left.arrow.right",
        message: "Linked tiles reflect each other's signal.\nThe number you see belongs to the partner tile, not this one.\nLook for the ↔ symbol to spot linked pairs.",
        onDismiss: {}
    )
}
