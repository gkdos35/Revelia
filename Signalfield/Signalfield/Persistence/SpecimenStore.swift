// Signalfield/Persistence/SpecimenStore.swift
//
// Tracks which specimens the player has unlocked.
// Persists to specimens.json in the same Application Support folder as
// progress.json and settings.json.
//
// Unlock logic:
// - Level specimens unlock when the player earns 3 stars on the matching level.
//   The caller (ProgressStore integration, added in a later step) should call
//   `unlock(_:)` after recording a 3-star result.
// - Rare biome specimens unlock when ALL level specimens for that biome+campaign
//   are unlocked. Check with `allLevelSpecimensUnlocked(for:isHex:)` and call
//   `unlock(_:)` on the rare specimen ID if it returns true.

import Foundation
import Combine

// MARK: - SpecimenStore

/// App-wide, persistent store for specimen unlock state.
///
/// Inject once as `@StateObject` in `SignalfieldApp` and share as
/// `@EnvironmentObject` throughout the view hierarchy — the same pattern
/// used by `ProgressStore`.
///
/// All mutations run on the main actor; file I/O is synchronous but fast
/// (the JSON payload is a small array of ID strings).
@MainActor
final class SpecimenStore: ObservableObject {

    // MARK: - Published State

    /// IDs of every specimen the player has unlocked.
    /// Views should query this through the helper methods below rather than
    /// reading the set directly, to avoid coupling to ID string formats.
    @Published private(set) var unlockedSpecimenIds: Set<String> = []

    // MARK: - Private

    private let saveURL: URL

    // MARK: - Init

    /// Designated initialiser.
    ///
    /// - Parameter saveURL: Override the save location. Pass `nil` (the default) to use
    ///   the standard `~/Library/Application Support/Signalfield/specimens.json` path.
    ///   Pass a custom URL in unit tests to avoid touching real player data.
    init(saveURL: URL? = nil) {
        if let url = saveURL {
            self.saveURL = url
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let folder = appSupport.appendingPathComponent("Signalfield", isDirectory: true)
            self.saveURL = folder.appendingPathComponent("specimens.json")
        }
        load()
    }

    // MARK: - Unlock Queries

    /// Returns `true` if the specimen with the given ID has been unlocked.
    func isUnlocked(_ specimenId: String) -> Bool {
        unlockedSpecimenIds.contains(specimenId)
    }

    /// Unlocks the specimen with the given ID and persists the change.
    /// Idempotent — calling with an already-unlocked ID is a no-op.
    func unlock(_ specimenId: String) {
        guard !unlockedSpecimenIds.contains(specimenId) else { return }
        unlockedSpecimenIds.insert(specimenId)
        save()
    }

    // MARK: - Aggregate Queries

    /// The number of unlocked specimens belonging to a given biome (0–8).
    /// Counts both level specimens and rare specimens across both campaigns.
    func unlockedCount(for biomeId: Int) -> Int {
        let biomeIds = Set(SpecimenCatalog.specimens(for: biomeId).map { $0.id })
        return unlockedSpecimenIds.intersection(biomeIds).count
    }

    /// `true` when every level specimen for the given biome and campaign is unlocked.
    ///
    /// Use this to check whether the matching rare specimen should be awarded:
    /// ```swift
    /// if specimenStore.allLevelSpecimensUnlocked(for: biomeId, isHex: isHex) {
    ///     if let rare = SpecimenCatalog.rareSpecimen(for: biomeId, isHex: isHex) {
    ///         specimenStore.unlock(rare.id)
    ///     }
    /// }
    /// ```
    func allLevelSpecimensUnlocked(for biomeId: Int, isHex: Bool) -> Bool {
        let levelSpecimens = SpecimenCatalog
            .specimens(for: biomeId)
            .filter { !$0.isRare && $0.isHex == isHex }
        return levelSpecimens.allSatisfy { unlockedSpecimenIds.contains($0.id) }
    }

    // MARK: - Persistence

    /// Serialises `unlockedSpecimenIds` to `specimens.json`. Called automatically
    /// by `unlock(_:)` after every change; exposed as `internal` for testing.
    func save() {
        do {
            let folder = saveURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(Array(unlockedSpecimenIds).sorted())
            try raw.write(to: saveURL, options: .atomic)
        } catch {
            print("[SpecimenStore] Save failed: \(error)")
        }
    }

    /// Loads `unlockedSpecimenIds` from `specimens.json`.
    /// Called automatically on init; exposed as `internal` for testing.
    func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let raw = try Data(contentsOf: saveURL)
            let ids = try JSONDecoder().decode([String].self, from: raw)
            unlockedSpecimenIds = Set(ids)
        } catch {
            // Corrupted or incompatible file — start fresh rather than crash.
            print("[SpecimenStore] Load failed, starting fresh: \(error)")
        }
    }

    // MARK: - Debug

    // DEBUG — remove before release
    /// Wipes all unlocked specimens from memory and disk.
    func resetAllSpecimens() {
        unlockedSpecimenIds = []
        try? FileManager.default.removeItem(at: saveURL)
        print("[SpecimenStore] Specimen collection reset.")
    }
}
