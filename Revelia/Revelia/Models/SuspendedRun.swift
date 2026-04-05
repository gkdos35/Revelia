// Revelia/Models/SuspendedRun.swift

import Foundation

struct SuspendedRun: Codable, Equatable {
    let schemaVersion: Int
    let levelId: String
    let seed: UInt64
    let board: Board
    let gameState: GameState
    let stats: RunStats
    let score: Int
    let stars: Int
    let elapsedTime: Double
    let beaconChargesRemaining: Int
    let isBeaconTargeting: Bool
    let conductorChargesRemaining: Int
    let isConductorTargeting: Bool
    let illuminatedCoords: Set<Coordinate>
    let linkedHighlightedCoord: Coordinate?
    let lockedSonarCoords: Set<Coordinate>
    let explosionOrigin: Coordinate?
    let quicksandFadeProgress: Double
    let savedAt: Date

    static let currentSchemaVersion = 1
}
