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

    /// Non-nil while the guided L1 tutorial is active.
    /// Created fresh each time the player taps Tutorial on the home screen.
    @State private var tutorialManager: TutorialManager? = nil

    var body: some View {
        if showingHome {
            // Home screen — shown on every launch; player must tap Play to proceed.
            WelcomeView(
                onComplete: { showingHome = false },
                onTutorial: {
                    tutorialManager = TutorialManager()
                    showingHome     = false
                }
            )
        } else if let mgr = tutorialManager {
            // Guided tutorial — L1 in scripted mode with step-by-step overlay.
            // "Return to Map" after winning drops tutorialManager → shows BiomeSelectView.
            // Back button ("← Home") returns to the home screen.
            tutorialContainer(manager: mgr)
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

    // MARK: - Tutorial Container

    /// Thin wrapper that presents L1 in guided-tutorial mode.
    ///
    /// `isLastLevelOfBiome` is false — L1 is not the last level of Training Range.
    /// `onNextLevel` is nil so the win card shows "Return to Map" (via onReturnToMap)
    /// instead of "Next Level." After the tutorial the player lands on BiomeSelectView.
    ///
    /// Behaviour on exit:
    /// - Win → "Return to Map" → `tutorialManager = nil` → BiomeSelectView
    /// - Back button (← Home) → `tutorialManager = nil`, `showingHome = true` → WelcomeView
    @ViewBuilder
    private func tutorialContainer(manager: TutorialManager) -> some View {
        let l1 = LevelSpec.trainingRange[0]

        VStack(spacing: 0) {
            // Minimal top bar
            HStack(spacing: 0) {
                Button {
                    tutorialManager = nil
                    showingHome     = true
                } label: {
                    Label("Home", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Text("Tutorial")
                    .font(.headline)

                Spacer()

                // Balance the chevron on the left
                Label("Home", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .hidden()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            GameView(
                levelSpec:             l1,
                tutorialManager:       manager,
                onNextLevel:           nil,
                onReturnToMap:         { tutorialManager = nil },
                onReturnToLevelSelect: { tutorialManager = nil; showingHome = true },
                isLastLevelOfBiome:    false,
                biomeName:             "Training Range",
                biomeIcon:             "flag.fill",
                biomeLevelIds:         [l1.id]
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
