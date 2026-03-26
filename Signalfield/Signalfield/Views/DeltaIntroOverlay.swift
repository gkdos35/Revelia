// Signalfield/Views/DeltaIntroOverlay.swift

import SwiftUI

/// Full-screen intro overlay shown when the player enters The Delta (L63) for the first time.
///
/// The Delta is the game's final challenge zone — 12 combined-mechanic levels where every
/// biome's mechanics collide. This overlay signals that transition with a distinct visual
/// identity (dark indigo / deep-space palette, icon grid of all 7 biome mechanics) that
/// differs from the per-biome BiomeIntroOverlay cards.
///
/// Dismissed by:
///   - Clicking "Let's go"
///   - Clicking the dimmed background
///   - Pressing any key
///
/// Persistence: a "Don't show this again" toggle writes to @AppStorage("deltaIntroNeverShow").
/// GameView reads the same key and skips the overlay when it is true.
struct DeltaIntroOverlay: View {
    let onDismiss: () -> Void

    /// When true the overlay will not appear again after this session dismissal.
    @AppStorage("deltaIntroNeverShow") private var neverShowAgain = false

    // All 7 biome mechanic icons — shown as a mini-grid to communicate "everything converges".
    private let biomeIcons: [(icon: String, color: Color)] = [
        ("cloud.fog",               Color.cyan),
        ("lightbulb.fill",          Color(red: 0.08, green: 0.72, blue: 0.62)),
        ("arrow.left.arrow.right",  Color(red: 0.40, green: 0.60, blue: 0.85)),
        ("lock.fill",               Color(red: 0.78, green: 0.62, blue: 0.30)),
        ("arrow.up.arrow.down",     Color(red: 0.35, green: 0.82, blue: 0.75)),
        ("scope",                   Color(red: 0.90, green: 0.65, blue: 0.15)),
        ("hourglass.bottomhalf.filled", Color(red: 0.85, green: 0.70, blue: 0.40)),
    ]

    var body: some View {
        ZStack {
            // Dimmed background — tapping anywhere dismisses
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Card
            VStack(spacing: 22) {

                // Biome icon grid — 4 + 3 layout
                iconGrid

                // Title
                Text("The Delta")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Subtitle
                Text("All mechanics. No warm-up.")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color(red: 0.65, green: 0.72, blue: 1.00))
                    .italic()

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 4)

                // Description
                Text("The Delta combines mechanics from every biome into 12 levels. Fog obscures, mirrors invert, locks delay, sonars span, sand buries — sometimes all at once.\n\nEverything you've learned leads here.")
                    .font(.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Dismiss button
                Button(action: dismiss) {
                    Text("Let's go")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.10, green: 0.06, blue: 0.22))
                        .padding(.horizontal, 36)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.68, green: 0.72, blue: 1.00))
                        )
                }
                .buttonStyle(.plain)

                // "Don't show again" toggle
                Toggle(isOn: $neverShowAgain) {
                    Text("Don't show this again")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .toggleStyle(.checkbox)
                .foregroundColor(Color.white.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(32)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.08, green: 0.07, blue: 0.18).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.50, green: 0.55, blue: 1.00).opacity(0.60),
                                        Color(red: 0.30, green: 0.35, blue: 0.80).opacity(0.25),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: Color(red: 0.15, green: 0.10, blue: 0.45).opacity(0.8),
                    radius: 32, y: 12)
        }
        // Any key press dismisses the overlay
        .onKeyPress { _ in
            dismiss()
            return .handled
        }
    }

    // MARK: - Biome Icon Grid

    /// 7 biome icons in a 4+3 row layout inside a subtle rounded rect.
    private var iconGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    biomeIconBadge(icon: biomeIcons[i].icon, color: biomeIcons[i].color)
                }
            }
            HStack(spacing: 14) {
                ForEach(4..<7, id: \.self) { i in
                    biomeIconBadge(icon: biomeIcons[i].icon, color: biomeIcons[i].color)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func biomeIconBadge(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 42, height: 42)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
        }
    }

    // MARK: - Helpers

    private func dismiss() {
        onDismiss()
    }
}

#Preview {
    DeltaIntroOverlay(onDismiss: {})
        .frame(width: 600, height: 520)
        .background(Color.gray.opacity(0.3))
}
