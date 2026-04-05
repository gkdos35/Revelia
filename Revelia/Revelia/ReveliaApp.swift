// Revelia/ReveliaApp.swift

import SwiftUI

@main
struct ReveliaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// Campaign progress store — created once at app launch, shared via environment.
    @StateObject private var progressStore = ProgressStore()

    /// App-level settings (signal display mode, sound, first-launch flag).
    @StateObject private var settingsStore = SettingsStore()

    /// Specimen collection store — tracks which specimens the player has unlocked.
    @StateObject private var specimenStore = SpecimenStore()

    /// Centralized audio service for music and sound effects.
    @StateObject private var audioManager = AudioManager()

    /// Local top-10 leaderboards per level.
    @StateObject private var leaderboardStore = LeaderboardStore()

    /// Single suspended in-progress run used by Save/Resume.
    private let suspendedRunStore = SuspendedRunStore()

    var body: some Scene {
        WindowGroup {
            RootView(suspendedRunStore: suspendedRunStore)
                .environmentObject(progressStore)
                .environmentObject(settingsStore)
                .environmentObject(specimenStore)
                .environmentObject(audioManager)
                .environmentObject(leaderboardStore)
                .onAppear {
                    audioManager.setBackgroundMusicEnabled(settingsStore.backgroundMusicEnabled)
                    audioManager.setGameSoundsEnabled(settingsStore.gameSoundsEnabled)
                    audioManager.setScenePhase(scenePhase)
                }
                .onChange(of: settingsStore.backgroundMusicEnabled) { _, isEnabled in
                    audioManager.setBackgroundMusicEnabled(isEnabled)
                }
                .onChange(of: settingsStore.gameSoundsEnabled) { _, isEnabled in
                    audioManager.setGameSoundsEnabled(isEnabled)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    audioManager.setScenePhase(newPhase)
                }
        }
        .defaultSize(width: 600, height: 700)
    }
}
