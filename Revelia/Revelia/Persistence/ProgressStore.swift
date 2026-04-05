// Revelia/Persistence/ProgressStore.swift
//
// Persistence layer for campaign progress.
// Saves and loads a small JSON file from ~/Library/Application Support/Revelia/.
// The store is injected once at the app level as an @EnvironmentObject so every
// view in the tree can read progress without needing explicit prop-drilling.

import Foundation
import Combine

// MARK: - Data Models

/// Persisted record for a single level.
struct LevelRecord: Codable {
    /// True once the player has completed the level at least once.
    var completed: Bool = false
    /// Best star rating achieved across all runs (0 = never completed, 1–3).
    var bestStars: Int = 0
}

/// Persisted record for a single biome (tracks Casual Shield state).
struct BiomeRecord: Codable {
    /// True if the player cleared the biome's first level with 3 stars.
    var shieldEarned: Bool = false
    /// True if the shield has been used on any level in this biome.
    /// Once used, the shield is gone for this biome permanently.
    var shieldUsed: Bool = false
}

/// Root container — serialised in its entirety to progress.json.
struct ProgressData: Codable {
    /// Per-level records, keyed by LevelSpec.id (e.g. "L1", "L47").
    var levelRecords: [String: LevelRecord] = [:]
    /// Per-biome records, keyed by biomeId (0–17).
    /// JSONEncoder writes Int keys as string keys ("0", "1", …); JSONDecoder
    /// round-trips them correctly — no custom CodingKeys needed.
    var biomeRecords: [Int: BiomeRecord] = [:]
}

// MARK: - ProgressStore

/// App-wide, persistent store for campaign progress.
///
/// Owned once as `@StateObject` in `ReveliaApp` and shared as
/// `@EnvironmentObject` throughout the view hierarchy.
///
/// All mutations happen on the main actor — file I/O is synchronous
/// but fast (the JSON payload is tiny even for a full 148-level run).
@MainActor
final class ProgressStore: ObservableObject {

    // MARK: Published state

    /// The full progress data. Views that need reactive reads should
    /// call the query helpers below, which read from this published property.
    @Published private(set) var data = ProgressData()

    // DEBUG — remove before release
    /// Runtime-only override that makes every level selectable regardless of progress.
    /// Never written to the JSON file — resets to false on next app launch.
    /// Toggle with Cmd+Shift+U during development.
    @Published var allUnlocked: Bool = false

    // MARK: Private

    private let saveURL: URL

    // MARK: Init

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = appSupport.appendingPathComponent("Revelia", isDirectory: true)
        saveURL = folder.appendingPathComponent("progress.json")
        load()
    }

    // MARK: - Record a Level Result

    /// Called once when the player wins a level.
    ///
    /// Updates completion state and best star count for a winning run.
    /// Score/time leaderboards live in `LeaderboardStore`; this store now tracks
    /// progression only.
    func recordResult(levelId: String, score: Int, timeSeconds: Double, stars: Int) {
        var record = data.levelRecords[levelId] ?? LevelRecord()
        record.completed = true
        if stars        > record.bestStars  { record.bestStars  = stars  }
        data.levelRecords[levelId] = record
        save()
    }

    // MARK: - Casual Shield

    /// Marks a shield as earned for the given biome.
    /// Called when the player achieves 3 stars on the biome's first level.
    func markShieldEarned(biomeId: Int) {
        var record = data.biomeRecords[biomeId] ?? BiomeRecord()
        guard !record.shieldEarned else { return }   // Idempotent
        record.shieldEarned = true
        data.biomeRecords[biomeId] = record
        save()
    }

    /// Marks the shield for the given biome as used.
    /// Called when `RunStats.shieldUsed` is true at the end of a winning run.
    func markShieldUsed(biomeId: Int) {
        var record = data.biomeRecords[biomeId] ?? BiomeRecord()
        guard !record.shieldUsed else { return }     // Idempotent
        record.shieldUsed = true
        data.biomeRecords[biomeId] = record
        save()
    }

    // MARK: - Level Unlock Logic

    /// Returns true if the player is allowed to launch the given level.
    ///
    /// Rules:
    /// - L1 is always unlocked (square campaign entry).
    /// - L75 unlocks when L74 is completed (hex campaign entry — requires the
    ///   entire square campaign to be finished first).
    /// - All other levels (including all hex levels L76–L148) require only the
    ///   previous level completed. Hex biome entry points carry no additional
    ///   cross-campaign gate beyond the L74 prerequisite enforced by L75.
    func isUnlocked(_ level: LevelSpec) -> Bool {
        // DEBUG — remove before release
        if allUnlocked { return true }

        let id = level.id

        // L1 — always unlocked; it is the campaign starting point.
        if id == "L1" { return true }

        // L75 — hex campaign entry point; the entire hex campaign is locked until
        // the player completes The Delta (L74), the final level of the square campaign.
        if id == "L75" { return isCompleted("L74") }

        // All other levels (including all remaining hex levels L76–L148) —
        // strictly sequential: previous level must be completed.
        // Hex biome entry points carry no cross-campaign gate; once L74 is done
        // and the player works through the hex campaign linearly, each entry
        // point unlocks naturally when the preceding hex level is complete.
        guard let n = levelNumber(from: id) else { return false }
        return isCompleted("L\(n - 1)")
    }

    /// Extracts the integer from a level ID string (e.g. "L47" → 47).
    /// Returns nil if the string is malformed.
    private func levelNumber(from id: String) -> Int? {
        Int(id.dropFirst())
    }

    // MARK: - Queries

    /// Returns true if the player has completed the level at least once.
    func isCompleted(_ levelId: String) -> Bool {
        data.levelRecords[levelId]?.completed ?? false
    }

    /// Returns the player's best star rating for a level (0 if never completed).
    func bestStars(for levelId: String) -> Int {
        data.levelRecords[levelId]?.bestStars ?? 0
    }

    /// Returns true if a Casual Shield has been earned but not yet used for this biome.
    func shieldAvailable(for biomeId: Int) -> Bool {
        let record = data.biomeRecords[biomeId] ?? BiomeRecord()
        return record.shieldEarned && !record.shieldUsed
    }

    // MARK: - Debug

    // DEBUG — remove before release
    /// Wipes all progress from memory and disk. Used for development testing via Cmd+Shift+R.
    func resetAllProgress() {
        data = ProgressData()
        try? FileManager.default.removeItem(at: saveURL)
        print("[ProgressStore] Progress reset.")
    }

    // DEBUG — remove before release
    /// Prints a diagnostic summary of all level records to the Xcode console.
    /// Use Cmd+Shift+D from any screen to inspect exactly what's in the store.
    func dumpRecords() {
        let sorted = data.levelRecords
            .sorted { a, b in
                let na = Int(a.key.dropFirst()) ?? 0
                let nb = Int(b.key.dropFirst()) ?? 0
                return na < nb
            }
        print("──────────────────────────────────────────────")
        print("[ProgressStore] 📊 DUMP — \(sorted.count) records total, allUnlocked=\(allUnlocked)")
        for (id, rec) in sorted {
            print("  \(id): ⭐\(rec.bestStars) completed:\(rec.completed)")
        }
        // Show hex records specifically
        let hexRecords = sorted.filter {
            guard let n = Int($0.key.dropFirst()) else { return false }
            return n >= 75
        }
        print("  ── Hex records (L75+): \(hexRecords.count)")
        print("──────────────────────────────────────────────")
    }

    // DEBUG — remove before release
    /// Ensures every level from L1 up to (but not including) `levelId` has a
    /// completion record. Used by the Cmd+Shift+C debug shortcut to maintain
    /// a valid progression chain when jumping ahead via allUnlocked mode.
    ///
    /// Without this, clearing a level the player hasn't legitimately reached
    /// (e.g. L81 while allUnlocked is on) creates an orphaned record. When
    /// allUnlocked is later toggled off, the orphaned record cascades through
    /// the linear unlock logic and exposes all downstream levels at once.
    ///
    /// Only writes missing records; existing records (including real gameplay
    /// bests) are never overwritten. Saves to disk once at the end.
    func backfillPrerequisites(before levelId: String) {
        guard let target = levelNumber(from: levelId), target > 1 else { return }
        var changed = false
        for n in 1..<target {
            let id = "L\(n)"
            if data.levelRecords[id]?.completed != true {
                data.levelRecords[id] = LevelRecord(
                    completed: true,
                    bestStars: 3
                )
                changed = true
            }
        }
        if changed {
            save()
            print("[ProgressStore] Backfilled prerequisites through L\(target - 1).")
        }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let raw = try Data(contentsOf: saveURL)
            data = try JSONDecoder().decode(ProgressData.self, from: raw)
        } catch {
            // Corrupted or incompatible file — start fresh rather than crash.
            // The old file is left on disk; a successful save will overwrite it.
            print("[ProgressStore] Load failed, starting fresh: \(error)")
        }
    }

    private func save() {
        do {
            let folder = saveURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted   // Human-readable for debugging
            let raw = try encoder.encode(data)
            try raw.write(to: saveURL, options: .atomic)
        } catch {
            print("[ProgressStore] Save failed: \(error)")
        }
    }
}
