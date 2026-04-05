// Revelia/Utilities/ScoringCalculator.swift

import Foundation

/// Computes the score and star thresholds for a completed run.
///
/// Philosophy:
/// - Any clear starts at 100,000.
/// - Most of the spread comes from large performance bonuses, not tiny penalties.
/// - Time and action targets scale with board size, hazard count, and mechanic load.
/// - A clean, helper-free, fast, efficient run can approach 1,000,000.
struct ScoringCalculator {

    struct Thresholds {
        let decentTimeSeconds: Int
        let fastTimeSeconds: Int
        let eliteTimeSeconds: Int
        let topScoreTimeSeconds: Int
        let lowActions: Int
        let scoreTimeCutoffSeconds: Int
        let scoreActionCutoff: Int
    }

    private static let completionFloor = 100_000
    private static let maxTimeBonus = 750_000
    private static let maxActionBonus = 70_000
    private static let cleanRunBonus = 50_000
    private static let helperFreeBonus = 30_000
    private static let lightHelperBonus = 5_000

    static func calculateScore(stats: RunStats, level: LevelSpec) -> Int {
        let thresholds = thresholds(for: level)
        let timeRatio = performanceRatio(
            value: stats.elapsedTimeSeconds,
            excellent: Double(thresholds.topScoreTimeSeconds),
            cutoff: Double(thresholds.scoreTimeCutoffSeconds)
        )
        let actionRatio = performanceRatio(
            value: Double(stats.totalActions),
            excellent: Double(thresholds.lowActions),
            cutoff: Double(thresholds.scoreActionCutoff)
        )

        let timeBonus = Int(Double(maxTimeBonus) * pow(timeRatio, 2.9))
        let actionBonus = Int(Double(maxActionBonus) * pow(actionRatio, 1.9))
        let cleanBonus = stats.noGuessValidated ? cleanRunBonus : 0

        let helperBonus: Int
        switch stats.totalHelperUses {
        case 0:
            helperBonus = helperFreeBonus
        case 1:
            helperBonus = lightHelperBonus
        default:
            helperBonus = 0
        }

        return completionFloor + timeBonus + actionBonus + cleanBonus + helperBonus
    }

    static func calculateStars(stats: RunStats, level: LevelSpec) -> Int {
        let thresholds = thresholds(for: level)
        let cleanRun = stats.incorrectFlagsEverPlaced == 0
        let decentTime = stats.elapsedTimeSeconds <= Double(thresholds.decentTimeSeconds)
        let fastTime = stats.elapsedTimeSeconds <= Double(thresholds.fastTimeSeconds)
        let lowActions = stats.totalActions <= thresholds.lowActions
        let helperFree = stats.totalHelperUses == 0

        if fastTime && lowActions && cleanRun && helperFree {
            return 3
        }
        if decentTime && cleanRun {
            return 2
        }
        return 1
    }

    static func thresholds(for level: LevelSpec) -> Thresholds {
        let tileCount = Double(level.tileCount)
        let hazardCount = Double(level.hazardCount)
        let complexity = level.mechanicComplexityScore

        let decentTime = max(
            25,
            Int(
                (Double(level.parTimeSeconds) * 0.58)
                + (tileCount * 0.38)
                + (hazardCount * 0.90)
                + (complexity * 6.5)
            )
        )

        let fastTime = max(
            14,
            Int(
                (Double(level.parTimeSeconds) * 0.22)
                + (tileCount * 0.11)
                + (hazardCount * 0.28)
                + (complexity * 2.0)
            )
        )

        let eliteTime = max(
            10,
            Int(
                (Double(fastTime) * 0.72)
                - (tileCount * 0.02)
                - (complexity * 0.30)
            )
        )

        let topScoreTime = max(
            5,
            Int(
                Double(level.parTimeSeconds) * 0.065
            )
        )

        let lowActions = max(
            4,
            Int(
                (Double(level.safeTileCount) * 0.72)
                + (hazardCount * 0.60)
                + (complexity * 4.5)
            )
        )

        let scoreTimeCutoff = max(
            decentTime + 15,
            Int(
                Double(decentTime)
                + (tileCount * 2.6)
                + (hazardCount * 6.0)
                + (complexity * 18.0)
            )
        )

        let scoreActionCutoff = max(
            lowActions + 6,
            Int(
                Double(lowActions)
                + (tileCount * 0.32)
                + (hazardCount * 2.8)
                + (complexity * 9.0)
            )
        )

        return Thresholds(
            decentTimeSeconds: decentTime,
            fastTimeSeconds: fastTime,
            eliteTimeSeconds: eliteTime,
            topScoreTimeSeconds: topScoreTime,
            lowActions: lowActions,
            scoreTimeCutoffSeconds: scoreTimeCutoff,
            scoreActionCutoff: scoreActionCutoff
        )
    }

    static func previewParScore(for level: LevelSpec) -> Int {
        let thresholds = thresholds(for: level)
        let previewStats = RunStats(
            elapsedTimeSeconds: Double(thresholds.decentTimeSeconds),
            scansCount: max(1, thresholds.lowActions / 2),
            tagsPlacedCount: max(0, thresholds.lowActions - max(1, thresholds.lowActions / 2)),
            confirmedTagsCount: 0,
            shieldUsed: false,
            incorrectFlagsEverPlaced: 0,
            chargesUsed: false,
            helperUsesCount: 0,
            seed: 0
        )
        return calculateScore(stats: previewStats, level: level)
    }

    private static func performanceRatio(value: Double, excellent: Double, cutoff: Double) -> Double {
        guard cutoff > excellent else { return value <= excellent ? 1 : 0 }
        if value <= excellent { return 1 }
        if value >= cutoff { return 0 }
        return 1 - ((value - excellent) / (cutoff - excellent))
    }
}
