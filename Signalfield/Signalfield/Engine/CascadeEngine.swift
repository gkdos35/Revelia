// Signalfield/Engine/CascadeEngine.swift

import Foundation

/// Handles BFS cascade when a 0-signal tile is revealed.
///
/// Algorithm:
/// 1. Start from a revealed tile with signal == 0
/// 2. BFS: for each 0-signal tile, queue all hidden safe neighbors
/// 3. Reveal queued tiles; if they also have signal 0, continue the flood
/// 4. Stop at non-zero signals (they get revealed but don't propagate)
/// 5. Never reveal hazards
///
/// Biome-specific stop/reveal rules:
/// - Fogged tiles (Biome 1) cascade exactly like normal tiles — they reveal as part
///   of a cascade and display their fog range (e.g. "1–2") after reveal. A fogged
///   tile with true signal 0 continues to propagate; one with signal > 0 reveals
///   but does not propagate. Fog is a display-only transformation; the true signal
///   drives all cascade decisions.
/// - Inverted tiles (Biome 5) cascade normally: cascade uses `tile.signal` (true hazard
///   count), so a tile with 0 hazard neighbors cascades even though it displays a large
///   safe-neighbor count. The inversion is purely a display transformation.
/// - Sonar tiles (Biome 6) cascade normally: `tile.signal` is set to the
///   directional total (N+S+E+W hazard count) by RuleEngine Pass 5. A sonar with
///   signal == 0 (all sight lines clear) cascades to its 8-neighbors as expected.
/// - Locked tiles (Biome 4) STOP the cascade — cascade does not reveal locked tiles.
///   They unlock only when enough surrounding neighbors are revealed via normal play.
struct CascadeEngine {

    /// Result of a cascade operation.
    struct CascadeResult {
        /// All coordinates that were revealed by the cascade (in BFS order).
        let revealedCoordinates: [Coordinate]
    }

    /// Perform a cascade starting from the given coordinate.
    /// The starting tile must already be revealed and have signal == 0.
    ///
    /// Returns the list of tiles revealed (for animation purposes).
    static func cascade(from start: Coordinate, on board: inout Board) -> CascadeResult {
        var revealed: [Coordinate] = []
        var queue: [Coordinate] = [start]
        var visited: Set<Coordinate> = [start]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let currentTile = board[current]

            // Only propagate from 0-signal tiles. Fogged tiles are NOT excluded here —
            // a fogged tile with true signal 0 should propagate cascade to its neighbors
            // just like any other 0-signal tile. Fog is display-only; true signal rules.
            guard let signal = currentTile.signal, signal == 0 else { continue }

            // Check all neighbors (geometry-aware: 8 for square, 6 for hex)
            let neighbors = board.neighbors(of: current)
            for neighbor in neighbors {
                guard !visited.contains(neighbor) else { continue }
                visited.insert(neighbor)

                let neighborTile = board[neighbor]

                // Never cascade into hazards
                guard !neighborTile.isHazard else { continue }

                // Never cascade into locked tiles (Biome 4: Ruins).
                // Locked tiles have their own unlock mechanic — they reveal only when
                // enough neighbors have been uncovered, not through BFS cascade.
                guard !neighborTile.isLocked else { continue }

                // Only cascade into hidden tiles
                guard neighborTile.isHidden else { continue }

                // Fogged neighbors are revealed normally — they will display their fog
                // range (e.g. "1–2") after reveal, but cascade does not skip them.

                // Reveal this neighbor
                board[neighbor].state = .revealed
                board[neighbor].tagState = .none
                revealed.append(neighbor)

                // Propagate if this neighbor's true signal is also 0
                if let neighborSignal = board[neighbor].signal, neighborSignal == 0 {
                    queue.append(neighbor)
                }
            }
        }

        return CascadeResult(revealedCoordinates: revealed)
    }
}
