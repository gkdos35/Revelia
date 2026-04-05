// Revelia/Models/RunStats.swift

import Foundation

/// Tracks all stats for a single play-through of a level.
struct RunStats: Codable, Equatable {
    var elapsedTimeSeconds: Double = 0
    var scansCount: Int = 0
    var tagsPlacedCount: Int = 0         // Total tag actions (suspect + confirmed)
    var confirmedTagsCount: Int = 0      // Confirmed tags at end
    var shieldUsed: Bool = false

    /// Count of incorrect confirmed flags placed at any point during the run.
    /// A confirmed flag on a non-hazard tile increments this the moment it is placed.
    /// Removing the flag does NOT decrement the counter — the mistake is recorded
    /// permanently and disqualifies the run from ★★ and ★★★ ratings.
    var incorrectFlagsEverPlaced: Int = 0

    /// True if the player spent any beacon or deep pulse charge during this run.
    /// Using a charge disqualifies the run from ★★★ (but not ★★).
    var chargesUsed: Bool = false

    /// Counts every helper-tool use during the run.
    /// Each beacon charge, conductor pulse, and Casual Shield consumption counts once.
    var helperUsesCount: Int = 0

    var seed: UInt64 = 0

    /// Total actions = scans + tags.
    var totalActions: Int {
        scansCount + tagsPlacedCount
    }

    /// True if no incorrect flags were placed at any point during the run.
    /// Used for the ★★ condition and the +15 000 score bonus.
    var noGuessValidated: Bool { incorrectFlagsEverPlaced == 0 }

    /// Total helper use across all mechanic aids and the Casual Shield.
    var totalHelperUses: Int {
        helperUsesCount + (shieldUsed ? 1 : 0)
    }
}
