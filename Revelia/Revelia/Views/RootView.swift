// Revelia/Views/RootView.swift
//
// Top-level navigation controller. Owns the selected-biome state and
// switches between BiomeSelectView (campaign map) and ContentView (level picker + game).
//
// No NavigationStack is used here — plain state-swap keeps the window chrome
// clean and gives us full control over the Back affordance inside ContentView.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var specimenStore: SpecimenStore
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var leaderboardStore: LeaderboardStore
    private let suspendedRunStore: SuspendedRunStore

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
    @State private var showingHighScores: Bool = false
    @State private var pendingSuspendedRun: SuspendedRun? = nil
    @State private var pendingSaveAndQuitRun: SuspendedRun? = nil

    init(suspendedRunStore: SuspendedRunStore) {
        self.suspendedRunStore = suspendedRunStore
    }

    var body: some View {
        Group {
            if showingHighScores {
                HighScoresFlowView(onBackToHome: {
                    showingHighScores = false
                })
            } else if showingHome {
                // Home screen — shown on every launch; player must tap Play to proceed.
                WelcomeView(
                    onComplete: { showingHome = false },
                    onShowHighScores: { showingHighScores = true },
                    hasSuspendedRun: suspendedRunStore.hasSuspendedRun,
                    onResumeLastRun: resumeSuspendedRun
                )
            } else if let biome = selectedBiome {
                ContentView(
                    biome:  biome,
                    onBack: { trigger in
                        revealTrigger = trigger
                        pendingSuspendedRun = nil
                        selectedBiome = nil
                    },
                    onQuitToHome: { suspendedRun in
                        pendingSaveAndQuitRun = suspendedRun
                    },
                    onClearSuspendedRun: {
                        suspendedRunStore.clear()
                    },
                    initialSuspendedRun: pendingSuspendedRun
                )
            } else {
                BiomeSelectView(
                    onSelect:       { biome in
                        audioManager.playMenuClick()
                        wasShowingHex = biome.id >= 9
                        pendingSuspendedRun = nil
                        selectedBiome = biome
                    },
                    onShowHighScores: {
                        showingHighScores = true
                    },
                    revealTrigger:  revealTrigger,
                    initialShowHex: wasShowingHex
                )
            }
        }
        .onAppear { syncAudioScreen() }
        .onChange(of: pendingSaveAndQuitRun) { _, run in
            guard let run else { return }
            DispatchQueue.main.async {
                suspendedRunStore.save(run)
                pendingSuspendedRun = nil
                selectedBiome = nil
                showingHome = true
                pendingSaveAndQuitRun = nil
            }
        }
        .onChange(of: showingHome) { _, _ in syncAudioScreen() }
        .onChange(of: showingHighScores) { _, _ in syncAudioScreen() }
        .onChange(of: selectedBiome?.id) { _, _ in syncAudioScreen() }
    }

    private func syncAudioScreen() {
        let nextScreen: AudioScreen?
        if showingHome || showingHighScores {
            nextScreen = .home
        } else if selectedBiome == nil {
            nextScreen = .biomeMap
        } else {
            nextScreen = nil
        }

        guard let nextScreen else { return }
        DispatchQueue.main.async {
            audioManager.transition(to: nextScreen)
        }
    }

    private func resumeSuspendedRun() {
        guard let run = suspendedRunStore.currentRun else { return }
        let allBiomes = BiomeInfo.squareBiomes + BiomeInfo.hexBiomes
        guard let biome = allBiomes.first(where: { biome in
            biome.levels.contains(where: { $0.id == run.levelId })
        }) else {
            suspendedRunStore.clear()
            return
        }

        pendingSuspendedRun = run
        wasShowingHex = biome.id >= 9
        showingHome = false
        selectedBiome = biome
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(suspendedRunStore: SuspendedRunStore())
            .environmentObject(ProgressStore())
            .environmentObject(SettingsStore()) // SettingsStore still needed by child views
            .environmentObject(SpecimenStore())
            .environmentObject(AudioManager())
            .environmentObject(LeaderboardStore())
            .frame(width: 600, height: 700)
    }
}
