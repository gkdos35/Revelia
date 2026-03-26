// Signalfield/Engine/RuleEngine.swift

import Foundation

/// Computes clue signals for tiles based on biome rules.
///
/// All tiles store their TRUE signal (exact 8-neighbor hazard count). Biome
/// mechanics modify what the PLAYER SEES, not the underlying truth:
/// - Biome 0: player sees exact signal (same as true)
/// - Biome 1: fogged tiles show a range (min–max); beacons clear fog to exact
/// - Biome 2: no signal modification — illumination is purely transient state
/// - Biome 3: linked tiles display partner's signal; own signal used for cascade
/// - Biome 4: locked tiles are safe — no signal modification
/// - Biome 5: inverted tiles display safe-neighbor count; own true signal used for cascade
/// - Biome 6: sonar `signal` is overwritten with N+S+E+W total (Pass 5);
///            cascade uses this total (signal==0 means all directions clear)
/// - Biome 7: no signal modification — quicksand is purely a visual fade layer
///
/// The true signal is always used for cascade logic. Display logic lives in TileView
/// (via `tile.displayedSignal`, which accounts for biome mechanics).
struct RuleEngine {

    // MARK: - Signal Computation

    /// Compute the true signal (hazard count) for a single tile.
    /// Returns nil for hazard tiles (they don't display signals).
    static func computeSignal(at coord: Coordinate, on board: Board) -> Int? {
        let tile = board[coord]

        // Hazards don't have signals
        if tile.isHazard { return nil }

        // Baseline: count hazards in the neighborhood (8 for square, 6 for hex).
        // Uses board.neighbors(of:) so geometry is respected for all grid shapes.
        let neighbors = board.neighbors(of: coord)
        let hazardCount = neighbors.count(where: { board[$0].isHazard })
        return hazardCount
    }

    /// Compute signals for every tile on the board. Returns an updated board.
    /// Also fills biome-specific display data (fog ranges, linked partner signals,
    /// inverted safe counts, sonar directional totals).
    ///
    /// Pass order matters:
    /// 1. True signals — sets `tile.signal` (own 8-neighbor hazard count) for every tile.
    /// 2. Fog ranges — computes the ±1 display range for each fogged tile.
    /// 3. Inverted safe counts — fills `invertedData.safeNeighborCount` for Biome 5
    ///    tiles (safeCount = totalNeighbors − hazardCount). MUST run before Pass 4
    ///    so that linked tiles on inverted boards can read the partner's safeNeighborCount.
    /// 4. Linked partner signals — fills `linkedData.partnerSignal` now that all true
    ///    signals AND inverted safe counts are known. When the partner is an inverted
    ///    tile, partnerSignal is set to the partner's safeNeighborCount so TileView
    ///    displays the correct value for Delta Linked+Inverted combos (L65, L68).
    /// 5. Sonar directional totals — overwrites `tile.signal` for Biome 6
    ///    sonar tiles with N+S+E+W hazard counts, and fills all four directional
    ///    fields in `sonarData`. This MUST run after Pass 1 (needs all hazards
    ///    marked) and after any other passes that depend on the 8-neighbor signal.
    ///
    /// - Parameters:
    ///   - board: The board with hazards already placed.
    ///   - spec: The level specification (used to check which biome mechanics apply).
    ///   - seed: The board seed, used to derive deterministic per-biome RNG streams.
    static func computeAllSignals(on board: Board, spec: LevelSpec, seed: UInt64) -> Board {
        var board = board

        // Pass 1: compute true signals (own hazard count) for all tiles.
        // This value drives cascade logic for ALL biomes — including linked tiles,
        // where the displayed signal differs from the true signal.
        for coord in board.allCoordinates {
            board[coord].signal = computeSignal(at: coord, on: board)
        }

        // Pass 2: compute fog ranges for Biome 1 fogged tiles.
        // Each fogged tile shows a range of exactly 1 (e.g. "2–3" or "3–4").
        // Direction is chosen deterministically per-tile via a seed-offset RNG.
        if spec.hasFog {
            // Offset the seed so the fog-direction RNG is independent of
            // phase 1 terrain and phase 2 hazard placement.
            var fogRNG = SplitMix64(seed: seed &+ 0xF06_D1CE)

            for coord in board.allCoordinates {
                if board[coord].fogData != nil, let trueSignal = board[coord].signal {
                    let (lo, hi) = fogRange(for: trueSignal, rng: &fogRNG)
                    board[coord].fogData?.signalMin = lo
                    board[coord].fogData?.signalMax = hi
                }
            }
        }

        // Pass 3: fill safe-neighbor counts for Biome 5 inverted tiles.
        // safeNeighborCount = total neighbors − hazardCount (i.e. true signal).
        // Uses board.neighbors(of:) so the count is correct for both square (8) and hex (6).
        // This is deterministic — no RNG needed.
        // Only tiles that still have invertedData at this point are safe tiles
        // (hazards had theirs cleared in placeHazards).
        // Must run before Pass 4 (linked) so linked tiles on inverted boards can
        // read the partner's safeNeighborCount when building partnerSignal.
        if spec.hasInverted {
            for coord in board.allCoordinates {
                guard board[coord].invertedData != nil,
                      let hazardCount = board[coord].signal else { continue }
                let totalNeighbors = board.neighbors(of: coord).count
                board[coord].invertedData?.safeNeighborCount = totalNeighbors - hazardCount
            }
        }

        // Pass 4: fill linked partner signals for Biome 3 linked tiles.
        // Now that all true signals AND inverted safe counts are known, we can
        // populate `partnerSignal` so TileView can display the correct value
        // without accessing the full board.
        //
        // Delta cross-mechanic: when the partner tile is inverted (Linked+Underside
        // combos in L65 and L68), the player-facing value is the partner's
        // safeNeighborCount, not the partner's hazard-count signal. We use
        // invertedData.safeNeighborCount when available so the linked tile displays
        // what the player would actually read on the partner.
        if spec.hasLinked {
            for coord in board.allCoordinates {
                if let partnerCoord = board[coord].linkedData?.partnerCoord {
                    // Capture partner signal into a local first — assigning directly
                    // from board[partnerCoord] while also writing board[coord] causes
                    // an overlapping-access exclusivity violation in Swift.
                    let partnerSignal: Int?
                    if let safeCount = board[partnerCoord].invertedData?.safeNeighborCount {
                        // Partner is inverted — display its safe-neighbor count.
                        partnerSignal = safeCount
                    } else {
                        partnerSignal = board[partnerCoord].signal
                    }
                    board[coord].linkedData?.partnerSignal = partnerSignal
                }
            }
        }

        // Pass 5: compute sonar signals for Biome 6 (Coral Basin).
        //
        // For each sonar tile, walk each primary sight-line beam to the board edge,
        // counting every hazard encountered. The per-direction counts are stored in
        // sonarData for optional per-direction display; their SUM overwrites `tile.signal`.
        //
        // Uses `board.sonarBeams(from:)` so the beam count is geometry-aware:
        //   - Square boards: 4 beams (N/S/E/W), fills northCount/southCount/eastCount/westCount.
        //   - Hex boards:    6 beams (N/NE/SE/S/SW/NW), fills north/northEast/southEast/
        //                    south/southWest/northWest counts.
        //
        // Overwriting `tile.signal` with the directional total is intentional:
        //   - CascadeEngine uses `signal == 0` to decide whether to flood-fill.
        //     A sonar with 0 hazards across all beams correctly cascades.
        //   - `displayedSignal` falls through to `return signal`, so TileView
        //     automatically shows the correct total without a special branch.
        //   - Normal (non-sonar) safe tiles on the same board keep their
        //     neighbor-count signals from Pass 1 untouched.
        if spec.hasSonar {
            for coord in board.allCoordinates {
                guard board[coord].isSonar else { continue }

                let beams = board.sonarBeams(from: coord)
                let counts = beams.map { beam in beam.count(where: { board[$0].isHazard }) }

                switch board.gridShape {
                case .square:
                    // beams order: [N, S, E, W]
                    board[coord].sonarData?.northCount = counts[0]
                    board[coord].sonarData?.southCount = counts[1]
                    board[coord].sonarData?.eastCount  = counts[2]
                    board[coord].sonarData?.westCount  = counts[3]

                case .hexagonal:
                    // beams order: [N, NE, SE, S, SW, NW]
                    board[coord].sonarData?.northCount     = counts[0]
                    board[coord].sonarData?.northEastCount = counts[1]
                    board[coord].sonarData?.southEastCount = counts[2]
                    board[coord].sonarData?.southCount     = counts[3]
                    board[coord].sonarData?.southWestCount = counts[4]
                    board[coord].sonarData?.northWestCount = counts[5]
                }

                // Overwrite the neighbor-count signal with the directional total.
                board[coord].signal = counts.reduce(0, +)
            }
        }

        return board
    }

    /// Compute a fog range of exactly 1 for a given true signal.
    ///
    /// - If trueSignal is 0, the only valid range is 0–1 (can't go lower).
    /// - If trueSignal is 8, the only valid range is 7–8 (can't go higher).
    /// - Otherwise, randomly pick either (trueSignal-1, trueSignal) or
    ///   (trueSignal, trueSignal+1).
    ///
    /// The range always contains the true signal, preserving the deduction
    /// property: the player knows the real value is one of exactly two options.
    private static func fogRange(
        for trueSignal: Int,
        rng: inout SplitMix64
    ) -> (min: Int, max: Int) {
        if trueSignal <= 0 {
            return (0, 1)
        } else if trueSignal >= 8 {
            return (7, 8)
        } else {
            // 50/50 chance: show low range or high range
            let goLow = rng.next() % 2 == 0
            if goLow {
                return (trueSignal - 1, trueSignal)
            } else {
                return (trueSignal, trueSignal + 1)
            }
        }
    }

    // MARK: - Fog Clearing (Biome 1)

    /// Clear fog on a single tile, revealing its exact signal instead of a range.
    ///
    /// Called when the player spends a beacon charge on a fogged tile.
    /// The tile's fogData.isCleared is set to true so it displays the exact
    /// signal rather than the min–max range.
    ///
    /// - Returns: true if the tile had fog that was cleared, false otherwise.
    @discardableResult
    static func clearFog(at coord: Coordinate, on board: inout Board) -> Bool {
        guard board.isValid(coord) else { return false }
        guard board[coord].fogData != nil, board[coord].hasFog else { return false }
        board[coord].fogData?.isCleared = true
        return true
    }
}
