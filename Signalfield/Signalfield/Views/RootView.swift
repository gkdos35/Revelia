// Signalfield/Views/RootView.swift
//
// Top-level navigation controller. Owns the selected-biome state and
// switches between BiomeSelectView (campaign map) and ContentView (level picker + game).
//
// No NavigationStack is used here — plain state-swap keeps the window chrome
// clean and gives us full control over the Back affordance inside ContentView.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var progressStore: ProgressStore

    /// True while the home / title screen is shown.
    /// Resets to true on every app launch — the home screen always appears first.
    @State private var showingHome: Bool = true

    /// The biome the player has tapped into. nil = showing the biome select screen.
    @State private var selectedBiome: BiomeInfo? = nil

    /// Cinematic trigger to pass to BiomeSelectView on the next map appearance.
    /// - `.biomeUnlock(mapIndex:)` when returning after completing a biome's final level.
    /// - `.squareCampaignComplete` when finishing The Delta square (L74) — plays the
    ///   square campaign banner then chains into the hex campaign unlock reveal.
    /// - `.campaignComplete` when finishing The Delta hex (L148) — the true final.
    /// - `nil` when returning via normal back navigation (no reveal animation needed).
    @State private var revealTrigger: RevealTrigger? = nil

    /// Tracks whether the player was viewing the hex campaign when they navigated
    /// into a biome. Passed to BiomeSelectView so it opens in the correct campaign
    /// mode when the view is recreated on return, instead of always defaulting to
    /// the square campaign.
    @State private var wasShowingHex: Bool = false

    var body: some View {
        if showingHome {
            // Home screen — shown on every launch; player must tap Play to proceed.
            WelcomeView(onComplete: { showingHome = false })
        } else if let biome = selectedBiome {
            ContentView(
                biome:  biome,
                onBack: { trigger in
                    revealTrigger = trigger
                    selectedBiome = nil
                }
            )
        } else {
            BiomeSelectView(
                onSelect:       { biome in
                    wasShowingHex = biome.id >= 9
                    selectedBiome = biome
                },
                revealTrigger:  revealTrigger,
                initialShowHex: wasShowingHex
            )
        }
    }
}

#Preview {
    RootView()
        .environmentObject(ProgressStore())
        .environmentObject(SettingsStore()) // SettingsStore still needed by child views
        .frame(width: 600, height: 700)
}
