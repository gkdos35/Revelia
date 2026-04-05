// Revelia/ContentView.swift
//
// Campaign Task 4: two-state container that owns in-biome navigation.
//
// State 1 (selectedLevel == nil): shows LevelSelectView — the winding trail
//   screen where the player picks which level to play within the biome.
// State 2 (selectedLevel != nil): shows a thin game header + GameView.
//
// The old level-picker dropdown has been removed. LevelSelectView fully
// replaces it for all biome navigation.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var progressStore: ProgressStore
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var specimenStore: SpecimenStore
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var leaderboardStore: LeaderboardStore

    /// The biome being played. Provided by RootView via BiomeSelectView.
    /// When nil (dev/preview mode), shows a placeholder.
    var biome: BiomeInfo? = nil

    /// Called to return all the way to BiomeSelectView.
    /// Carries a `RevealTrigger` describing what cinematic to play on re-appear:
    /// - `.biomeUnlock(mapIndex:)` after completing a biome's final level
    /// - `.squareCampaignComplete` after finishing The Delta square (L74)
    /// - `.campaignComplete` after finishing The Delta hex (L148)
    /// - `nil` for plain back navigation (no animation)
    var onBack: ((RevealTrigger?) -> Void)? = nil
    var onQuitToHome: ((SuspendedRun) -> Void)? = nil
    var onClearSuspendedRun: (() -> Void)? = nil
    var initialSuspendedRun: SuspendedRun? = nil

    /// The level currently being played. nil = showing LevelSelectView.
    @State private var selectedLevel: LevelSpec? = nil
    @State private var resumedRun: SuspendedRun? = nil

    /// Changing this UUID forces GameView to recreate its ViewModel (new random seed).
    @State private var gameKey: UUID = UUID()

    /// Controls whether the biome mechanic intro sheet is visible.
    @State private var showBiomeMechanic: Bool = false
    @State private var selectedLeaderboardLevel: LevelSpec? = nil

    init(
        biome: BiomeInfo? = nil,
        onBack: ((RevealTrigger?) -> Void)? = nil,
        onQuitToHome: ((SuspendedRun) -> Void)? = nil,
        onClearSuspendedRun: (() -> Void)? = nil,
        initialSuspendedRun: SuspendedRun? = nil
    ) {
        self.biome = biome
        self.onBack = onBack
        self.onQuitToHome = onQuitToHome
        self.onClearSuspendedRun = onClearSuspendedRun
        self.initialSuspendedRun = initialSuspendedRun
        let initialLevel = biome?.levels.first(where: { $0.id == initialSuspendedRun?.levelId })
        _selectedLevel = State(initialValue: initialLevel)
        _resumedRun = State(initialValue: initialSuspendedRun)
    }

    // MARK: - Derived

    /// All levels in the active biome (or empty when biome is nil).
    private var levels: [LevelSpec] { biome?.levels ?? [] }

    /// True when `selectedLevel` is the last level in the biome's level list.
    private var isLastLevelOfBiome: Bool {
        guard let level = selectedLevel, let last = levels.last else { return false }
        return level.id == last.id
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if let level = selectedLevel {
                // ── State 2: Game ─────────────────────────────────────────────
                gameHeader(for: level)
                Divider()
                GameView(
                    levelSpec:             level,
                    suspendedRun:          resumedRun?.levelId == level.id ? resumedRun : nil,
                    onNextLevel:           isLastLevelOfBiome ? nil : { advanceToNextLevel() },
                    onReturnToMap:         isLastLevelOfBiome ? {
                        // Determine which cinematic trigger to fire on map reappear.
                        // biome.id % 9 gives the map index (0–8) for both campaigns.
                        let completedMapIndex = (biome?.id ?? 0) % 9
                        let nextMapIndex      = completedMapIndex + 1
                        if nextMapIndex < 9 {
                            onBack?(.biomeUnlock(mapIndex: nextMapIndex))
                        } else if (biome?.id ?? 0) < 9 {
                            // Square Delta (L74) completed — square campaign done.
                            // Chain into the hex campaign unlock reveal sequence.
                            onBack?(.squareCampaignComplete)
                        } else {
                            // Hex Delta (L148) completed — the true final campaign done.
                            onBack?(.campaignComplete)
                        }
                    } : nil,
                    onReturnToLevelSelect: {
                        audioManager.playMenuClick()
                        // Navigate back to LevelSelectView within this biome.
                        // Same action as the "← Levels" button in gameHeader.
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedLevel = nil
                        }
                    },
                    onSaveAndExit: { suspendedRun in
                        onQuitToHome?(suspendedRun)
                    },
                    onClearSuspendedRun: onClearSuspendedRun,
                    isLastLevelOfBiome: isLastLevelOfBiome,
                    biomeName:          biome?.name    ?? "",
                    biomeIcon:          biome?.icon    ?? "",
                    biomeLevelIds:      levels.map(\.id)
                )
                .id(gameKey)

            } else if let biome = biome {
                // ── State 1: Level select ─────────────────────────────────────
                LevelSelectView(
                    biome:  biome,
                    onBack: {
                        audioManager.playMenuClick()
                        onBack?(nil)
                    },
                    onPlay: { level in
                        audioManager.playMenuClick()
                        onClearSuspendedRun?()
                        resumedRun = nil
                        selectedLevel = level
                        gameKey       = UUID()
                    },
                    onShowHighScores: { level in
                        audioManager.playMenuClick()
                        selectedLeaderboardLevel = level
                    }
                )

            } else {
                // ── Dev/preview fallback (no biome provided) ──────────────────
                Spacer()
                Text("No biome selected.")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // ── Debug shortcuts (always in the responder chain) ───────────────
            debugShortcuts
        }
        // ── Biome mechanic intro sheet ────────────────────────────────────────
        // Presented as a sheet (never an overlay) so GameView's layout and input
        // are completely unaffected. Fires when the player enters a biome's first
        // level for the first time — unless they previously checked "Don't show again".
        .sheet(isPresented: $showBiomeMechanic) {
            BiomeMechanicView(
                biomeId: biome?.id ?? 0,
                onDontShowAgain: {
                    if let b = biome {
                        settingsStore.markBiomeIntroShown(b.id)
                    }
                }
            )
        }
        .sheet(item: $selectedLeaderboardLevel) { level in
            LevelLeaderboardView(level: level, showsCloseButton: true)
                .environmentObject(leaderboardStore)
                .frame(width: 600, height: 700)
        }
        .onChange(of: selectedLevel) { _, newLevel in
            guard
                let level  = newLevel,
                let b      = biome,
                b.id % 9 != 0,                          // Training Range has no intro
                level.id == levels.first?.id,           // only on the biome's first level
                !settingsStore.isBiomeIntroSuppressed(b.id)
            else { return } 
            showBiomeMechanic = true
        }
        .onAppear { syncAudioScreen() }
        .onChange(of: selectedLevel) { _, _ in syncAudioScreen() }
    }

    // MARK: - Game header

    /// Thin material bar shown above GameView. "← Levels" returns to LevelSelectView.
    private func gameHeader(for level: LevelSpec) -> some View {
        HStack(spacing: 0) {
            Button {
                audioManager.playMenuClick()
                // Return to LevelSelectView within this biome (not all the way to BiomeSelectView).
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedLevel = nil
                }
            } label: {
                Label("Levels", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 10)

            if let biome = biome {
                Image(systemName: biome.icon)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 5)
                Text(biome.name)
                    .font(.headline)
            } else {
                Text(level.displayName)
                    .font(.headline)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Level advancement

    /// Advances `selectedLevel` to the next level in the biome and reseeds GameView.
    private func advanceToNextLevel() {
        guard let current = selectedLevel,
              let idx = levels.firstIndex(where: { $0.id == current.id }),
              idx + 1 < levels.count
        else { return }
        audioManager.playMenuClick()
        onClearSuspendedRun?()
        resumedRun = nil
        selectedLevel = levels[idx + 1]
        gameKey       = UUID()
    }

    private func syncAudioScreen() {
        guard let biome else { return }
        if selectedLevel == nil {
            let biomeId = biome.id
            DispatchQueue.main.async {
                audioManager.transition(to: .levelSelect(biomeId: biomeId))
            }
        }
    }

    // MARK: - Debug shortcuts

    /// Hidden buttons providing keyboard shortcuts for development testing.
    /// These must remain in the ContentView body (not inside GameView) so they
    /// stay in the responder chain on BOTH the level-select and game screens.
    @ViewBuilder
    private var debugShortcuts: some View {
        // DEBUG — remove before release
        // Cmd+Shift+R: wipe all progress, return to level select.
        Button("") {
            progressStore.resetAllProgress()
            leaderboardStore.resetAllLeaderboards()
            selectedLevel = nil
        }
        .keyboardShortcut("R", modifiers: [.command, .shift])
        .frame(width: 0, height: 0)
        .hidden()

        // DEBUG — remove before release
        // Cmd+Shift+U: toggle unlock-all override (runtime only, no file changes).
        Button("") {
            progressStore.allUnlocked.toggle()
        }
        .keyboardShortcut("U", modifiers: [.command, .shift])
        .frame(width: 0, height: 0)
        .hidden()

        // DEBUG — remove before release
        // Cmd+Shift+C: instantly clear the current level (3★ / score 99999 / 1.0s).
        // On the game screen: records result, then advances or returns to map.
        // On the level-select screen: no-op (no level is active).
        //
        // Backfills all prerequisite levels first so the progression chain stays
        // valid even when jumping ahead via allUnlocked mode. This prevents
        // orphaned records from cascading through the linear unlock logic.
        Button("") {
            guard let level = selectedLevel else { return }
            progressStore.backfillPrerequisites(before: level.id)
            progressStore.recordResult(
                levelId:     level.id,
                score:       99999,
                timeSeconds: 1.0,
                stars:       3
            )
            _ = leaderboardStore.recordWinningRun(
                levelId: level.id,
                score: 99999,
                timeSeconds: 1.0,
                stars: 3
            )
            // DEBUG — also unlock the specimen for this level (mirrors real win logic)
            if let specimen = SpecimenCatalog.specimen(for: level.id) {
                specimenStore.unlock(specimen.id)
                let biomeId = specimen.biomeId
                let isHex   = specimen.isHex
                if specimenStore.allLevelSpecimensUnlocked(for: biomeId, isHex: isHex),
                   let rare = SpecimenCatalog.rareSpecimen(for: biomeId, isHex: isHex) {
                    specimenStore.unlock(rare.id)
                }
            }
            if isLastLevelOfBiome {
                selectedLevel = nil
                let completedMapIndex = (biome?.id ?? 0) % 9
                let nextMapIndex      = completedMapIndex + 1
                if nextMapIndex < 9 {
                    onBack?(.biomeUnlock(mapIndex: nextMapIndex))
                } else if (biome?.id ?? 0) < 9 {
                    // Square campaign complete — hex reveal follows.
                    onBack?(.squareCampaignComplete)
                } else {
                    // Hex campaign complete — true final.
                    onBack?(.campaignComplete)
                }
            } else {
                advanceToNextLevel()
            }
        }
        .keyboardShortcut("C", modifiers: [.command, .shift])
        .frame(width: 0, height: 0)
        .hidden()

        // DEBUG — remove before release
        // Cmd+Shift+D: dump all level records to the Xcode console.
        Button("") {
            progressStore.dumpRecords()
        }
        .keyboardShortcut("D", modifiers: [.command, .shift])
        .frame(width: 0, height: 0)
        .hidden()
    }
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(
                biome:  BiomeInfo.squareBiomes[0],
                onBack: { _ in }
            )
            .previewDisplayName("ContentView — biome provided")

            ContentView()
                .previewDisplayName("ContentView — no biome (dev mode)")
        }
        .environmentObject(ProgressStore())
        .environmentObject(LeaderboardStore())
        .environmentObject(SettingsStore())
        .environmentObject(SpecimenStore())
        .environmentObject(AudioManager())
        .frame(width: 600, height: 700)
    }
}
