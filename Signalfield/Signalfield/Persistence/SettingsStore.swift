// Signalfield/Persistence/SettingsStore.swift
//
// App-level settings, persisted to Application Support as settings.json.
// Injected at app launch as @EnvironmentObject alongside ProgressStore.

import Foundation
import Combine

// MARK: - SettingsStore

final class SettingsStore: ObservableObject {

    // MARK: Published settings

    @Published var soundEnabled: Bool = true {
        didSet { save() }
    }

    // MARK: - Tutorial State

    /// False on first launch; set to true when the L1 guided tutorial completes.
    /// When false, starting L1 loads the scripted tutorial board instead of a
    /// randomly generated one and runs the step-by-step overlay.
    @Published var hasCompletedL1Tutorial: Bool = false {
        didSet { save() }
    }

    /// Biome IDs (0–8 base biome; hex biomes stored as biomeId % 9 + 9 offset, see note)
    /// for which the non-blocking intro tooltip has already been shown.
    ///
    /// Storage note: square biomes use IDs 1–8 directly; hex biomes use IDs 10–17
    /// (biomeId directly from LevelSpec.biomeId). Checking `shownBiomeIntros` by the
    /// raw biomeId means square and hex intros are tracked independently, as intended
    /// by the spec ("Show them independently — seeing the square version doesn't skip
    /// the hex version").
    @Published var shownBiomeIntros: Set<Int> = [] {
        didSet { save() }
    }

    // MARK: - Tutorial Reset

    /// Reset the tutorial state so the guided L1 tutorial and all biome intros
    /// will show again. Called by the Tutorial button on the home screen.
    func resetTutorial() {
        hasCompletedL1Tutorial = false
        shownBiomeIntros = []
    }

    // MARK: - Persistence

    private static let fileName = "settings.json"

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Signalfield", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    // MARK: - Codable snapshot

    private struct Snapshot: Codable {
        var soundEnabled: Bool
        var hasCompletedL1Tutorial: Bool
        var shownBiomeIntros: [Int]     // Stored as sorted array for stable JSON
    }

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Load / Save

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        soundEnabled           = snapshot.soundEnabled
        hasCompletedL1Tutorial = snapshot.hasCompletedL1Tutorial
        shownBiomeIntros       = Set(snapshot.shownBiomeIntros)
    }

    private func save() {
        let snapshot = Snapshot(
            soundEnabled:           soundEnabled,
            hasCompletedL1Tutorial: hasCompletedL1Tutorial,
            shownBiomeIntros:       shownBiomeIntros.sorted()
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
