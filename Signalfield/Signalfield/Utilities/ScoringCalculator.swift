// Signalfield/Utilities/ScoringCalculator.swift

import Foundation

/// Computes the composite score for a completed run.
///
/// Formula from spec:
///   score = 100000 - time×20 - totalActions×30 + (noGuess ? 15000 : 0)
///   Clamped to minimum 0.
///
/// Primary sort: score DESC. Ties broken by: time ASC.
struct ScoringCalculator {

    /// Calculate the final score for a run.
    static func calculateScore(stats: RunStats) -> Int {
        var score = 100_000
        score -= Int(stats.elapsedTimeSeconds) * 20
        score -= stats.totalActions * 30
        if stats.noGuessValidated {
            score += 15_000
        }
        return max(0, score)
    }

    /// Calculate star rating for a completed level.
    ///
    /// These conditions apply globally to every level in the game:
    /// - ★   Complete the level
    /// - ★★  Complete under par time with no incorrect flags placed at any point
    /// - ★★★ Under par time, no incorrect flags, AND no beacon/pulse charges used
    ///
    /// "Incorrect flag" means a confirmed tag placed on a non-hazard tile.
    /// Removing the flag after placing it does not undo the disqualification.
    /// "Charges used" means any beacon charge or deep pulse charge was spent.
    static func calculateStars(stats: RunStats, parTimeSeconds: Int) -> Int {
        let underPar  = stats.elapsedTimeSeconds < Double(parTimeSeconds)
        let cleanRun  = stats.incorrectFlagsEverPlaced == 0  // ★★ condition
        let pureRun   = cleanRun && !stats.chargesUsed       // ★★★ condition

        if underPar && pureRun {
            return 3
        } else if underPar && cleanRun {
            return 2
        } else {
            return 1
        }
    }
}
