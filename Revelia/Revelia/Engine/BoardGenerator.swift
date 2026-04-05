// Revelia/Engine/BoardGenerator.swift

import Foundation

/// Generates a game board from a LevelSpec and seed.
///
/// Board generation follows the spec's two-phase approach:
/// 1. **Pre-game (phase 1):** Create grid, place terrain and special designations
///    (fog zones, linked pairs, etc.) from the seed.
/// 2. **Post-first-scan (phase 2):** Place hazards excluding the 3×3 safe zone,
///    then compute all signals/clues.
struct BoardGenerator {

    // MARK: - Seed Generation

    /// Generate a truly random seed for a new game.
    /// Uses SystemRandomNumberGenerator (backed by the OS CSPRNG) to ensure
    /// every call produces an independent, high-entropy value.
    ///
    /// This is the ONLY way new-game seeds should be created. Level-derived or
    /// fixed seeds must never be used for normal gameplay — they cause board
    /// repetition across sessions.
    ///
    /// To replay a specific board, pass a stored seed to GameViewModel.init directly.
    static func generateSeed() -> UInt64 {
        var systemRNG = SystemRandomNumberGenerator()
        return systemRNG.next()
    }

    // MARK: - Phase 1: Pre-Game Setup

    /// Create a board with terrain and special tiles placed, but NO hazards yet.
    /// Called at level start, before the player's first scan.
    static func createEmptyBoard(for spec: LevelSpec, seed: UInt64) -> Board {
        var board = Board(width: spec.boardWidth, height: spec.boardHeight, gridShape: spec.gridShape)
        var rng = SplitMix64(seed: seed)

        // Place biome-specific designations (order matters for RNG determinism)
        if spec.hasFog {
            placeFogZones(on: &board, spec: spec, rng: &rng)
        }
        if spec.hasLinked {
            placeLinkedPairs(on: &board, spec: spec, rng: &rng)
        }
        if spec.hasInverted {
            markAllTilesInverted(on: &board)
        }
        if spec.hasLocked {
            placeLockedTiles(on: &board, spec: spec, rng: &rng)
        }
        // Biome 6 (Coral Basin): sonar tiles are placed in phase 2 (inside
        // placeHazards) rather than here, because their positions must be chosen to
        // avoid the 3×3 safe zone so that the intersection cells they create are
        // actually usable for hazard placement.

        return board
    }

    // MARK: - Phase 2: Hazard Placement (after first scan)

    /// Place hazards and compute signals after the player's first scan.
    ///
    /// For levels with linked pairs, retries with up to `linkedPairRetryLimit`
    /// different hazard-placement seeds if the required pair count is not met.
    /// Two failure paths can reduce the final pair count below spec:
    ///   1. A hazard lands on a Phase 1 linked tile, dissolving that pair.
    ///   2. `repairZeroZeroLinkedPairs` dissolves a pair when no non-zero
    ///      replacement partner exists (rare on small/sparse boards like L23).
    /// Retrying with a different seed varies hazard positions, making both
    /// failure modes statistically unlikely to persist across all attempts.
    ///
    /// - Parameters:
    ///   - board: The board from phase 1 (has terrain/specials but no hazards)
    ///   - firstScan: The coordinate the player clicked first
    ///   - spec: The level specification
    ///   - seed: The RNG seed (uses a separate sequence from phase 1)
    /// - Returns: A fully populated board ready for play
    static func placeHazards(
        on board: Board,
        firstScan: Coordinate,
        spec: LevelSpec,
        seed: UInt64
    ) -> Board {
        guard let requiredPairs = spec.linkedPairCount, requiredPairs > 0 else {
            // No pair requirement — run a single attempt.
            return placeHazardsAttempt(on: board, firstScan: firstScan, spec: spec, seed: seed)
        }

        // Linked level: try multiple hazard seeds until the pair count is met.
        // Seeds are derived deterministically so replays are stable once a valid
        // attempt is found (the first attempt that succeeds will always succeed
        // for the same game seed).
        var lastResult = placeHazardsAttempt(on: board, firstScan: firstScan, spec: spec, seed: seed)
        if actualLinkedPairCount(on: lastResult) >= requiredPairs { return lastResult }

        for attempt in 1..<linkedPairRetryLimit {
            // Mix the attempt index into the seed using a Knuth-style multiplicative
            // constant — keeps attempt seeds well-separated in the UInt64 space.
            let retrySeed = seed &+ UInt64(attempt) &* 0x9E3779B97F4A7C15
            let result = placeHazardsAttempt(on: board, firstScan: firstScan, spec: spec, seed: retrySeed)
            lastResult = result
            if actualLinkedPairCount(on: result) >= requiredPairs { return result }
        }

        // All attempts exhausted — return the last result as a best-effort fallback.
        // This is only reached on extremely sparse/small boards where geometry
        // makes it impossible to satisfy the pair count regardless of hazard layout.
        return lastResult
    }

    /// Maximum number of distinct hazard seeds to try before accepting a board
    /// that falls short of the required linked pair count.
    private static let linkedPairRetryLimit = 8

    /// Count the number of linked pairs currently on `board`.
    /// Each pair occupies exactly two tiles, so the tile count halves to the pair count.
    private static func actualLinkedPairCount(on board: Board) -> Int {
        board.allCoordinates.filter { board[$0].linkedData != nil }.count / 2
    }

    /// Single hazard-placement attempt. Called by `placeHazards`; may be called
    /// multiple times with different seeds when pair-count enforcement is active.
    private static func placeHazardsAttempt(
        on board: Board,
        firstScan: Coordinate,
        spec: LevelSpec,
        seed: UInt64
    ) -> Board {
        var board = board
        // Use a different seed derivation for hazard placement so phase 1
        // RNG sequence doesn't affect hazard positions and vice versa.
        var rng = SplitMix64(seed: seed &+ 0xDEAD_BEEF)

        // Build the 3×3 safe zone around the first scan
        let safeZone = safeZoneCoordinates(around: firstScan, board: board)

        // ── Biome 6: Coral Basin ──────────────────────────────────────────────
        // Sonar tiles are placed HERE (phase 2) so we know the safe zone and
        // can guarantee every intersection cell is outside it and usable for hazards.
        if spec.hasSonar {
            placeSonarTiles(on: &board, safeZone: safeZone, spec: spec, rng: &rng)
        }

        // ── Candidate pool ───────────────────────────────────────────────────────
        // For Coral Basin, hazards are restricted to intersection cells — positions
        // covered by at least one horizontal AND one vertical sonar sight line.
        // This is the hard constraint that guarantees every hazard is triangulatable.
        // All other biomes use the full board minus the safe zone.
        // Locked tiles (Biome 4) are ALWAYS excluded from both branches — they are
        // guaranteed safe and must never be hazards. Delta levels that combine
        // Sonar + Ruins may have locked tiles inside intersection cells; excluding
        // them here ensures hazards never collide with pre-placed locked tiles.
        var candidates: [Coordinate]
        if spec.hasSonar {
            candidates = sonarIntersectionCells(on: board, safeZone: safeZone)
                .filter { !board[$0].isLocked }
        } else {
            candidates = board.allCoordinates.filter { coord in
                !safeZone.contains(coord) && !board[coord].isLocked
            }
        }

        // Shuffle candidates deterministically, then take the first N
        rng.shuffle(&candidates)
        let hazardCount = min(spec.hazardCount, candidates.count)

        for i in 0..<hazardCount {
            // Before converting to hazard, clean up any biome mechanic data.
            // Hazards don't show signals, so mechanic designations are invalid on them.

            // Fog: just clear the fog data on this tile.
            board[candidates[i]].fogData = nil

            // Linked: clear BOTH this tile AND its partner to avoid orphaned pairs.
            // An orphaned linked tile (whose partner is a hazard) would display nil,
            // which the player can't reason about — cleaner to remove both.
            if let partnerCoord = board[candidates[i]].linkedData?.partnerCoord {
                board[partnerCoord].linkedData = nil
            }
            board[candidates[i]].linkedData = nil

            // Inverted: clear this tile. Hazards don't display signals so the
            // inverted designation is meaningless on them.
            board[candidates[i]].invertedData = nil

            // Sonar: clear this tile. A hazard tile cannot also be a sonar —
            // sonar candidates come from intersection cells, but we still guard
            // defensively in case of a coding error or future refactor.
            board[candidates[i]].sonarData = nil

            // Locked: clear this tile. Locked tiles are excluded from candidates
            // above, but clear defensively in case of future refactor.
            board[candidates[i]].lockedData = nil

            board[candidates[i]].kind = .hazard
        }
        board.hazardCount = hazardCount
        board.hazardsPlaced = true

        // Mark the safe zone
        for coord in safeZone {
            board[coord].isFirstScanProtected = true
        }

        // Compute signals for all tiles using the RuleEngine
        board = RuleEngine.computeAllSignals(on: board, spec: spec, seed: seed)

        // Repair zero-zero linked pairs now that partnerSignal values are known.
        // Must run after computeAllSignals so we can read the filled-in partnerSignals.
        if spec.hasLinked {
            repairZeroZeroLinkedPairs(on: &board, rng: &rng)
        }

        return board
    }

    // MARK: - Fog Marsh (Biome 1) Placement

    /// Minimum Chebyshev distance between any two fogged tiles.
    /// A value of 3 means at least 2 empty tiles separate every fog pair,
    /// preventing clusters that create unsolvable guess zones and preserving
    /// cascade flow between fog tiles.
    private static let fogMinSeparation = 3

    /// Place fog zones on the board (no beacon tiles — beacons are now player charges).
    /// Called during phase 1 (pre-first-scan).
    ///
    /// Placement rules:
    /// 1. **Exact count:** `spec.fogCount` tiles are placed (not a density fraction).
    /// 2. **Spacing:** Every fog tile must be at least `fogMinSeparation` Chebyshev
    ///    distance from every other fog tile. This prevents clusters.
    /// 3. **Cascade preservation:** Fog tiles prefer interior positions (≥ 1 tile
    ///    from board edge) so they don't wall off edge-originating cascades.
    ///    Edge tiles are only used as a fallback if interior candidates run out.
    private static func placeFogZones(
        on board: inout Board,
        spec: LevelSpec,
        rng: inout SplitMix64
    ) {
        guard let fogCount = spec.fogCount else { return }

        // Partition candidates into interior (preferred) and edge (fallback).
        // Interior tiles have at least 1 tile of padding from the board edge,
        // so placing fog there is less likely to block edge-originating cascades.
        let geometry = board.geometry
        var interiorCoords: [Coordinate] = []
        var edgeCoords: [Coordinate] = []
        for coord in board.allCoordinates {
            if geometry.isInterior(coord, boardWidth: board.width, boardHeight: board.height) {
                interiorCoords.append(coord)
            } else {
                edgeCoords.append(coord)
            }
        }

        // Shuffle both pools deterministically
        rng.shuffle(&interiorCoords)
        rng.shuffle(&edgeCoords)

        // Try interior candidates first, then fall back to edge candidates
        let orderedCandidates = interiorCoords + edgeCoords

        var foggedCoords: [Coordinate] = []
        for coord in orderedCandidates {
            if foggedCoords.count >= fogCount { break }
            if isTooClose(coord, to: foggedCoords, minDistance: fogMinSeparation, geometry: geometry) { continue }
            board[coord].fogData = FogData(signalMin: 0, signalMax: 0, isCleared: false)
            foggedCoords.append(coord)
        }
    }

    /// Returns true if `candidate` is within `minDistance` (topological) of any coordinate in `placed`.
    private static func isTooClose(
        _ candidate: Coordinate,
        to placed: [Coordinate],
        minDistance: Int,
        geometry: any GridGeometry
    ) -> Bool {
        placed.contains { geometry.distance(from: candidate, to: $0) < minDistance }
    }

    /// Returns true if `candidate` is within `minDistance` (topological) of any coordinate in `used`.
    private static func isTooCloseToSet(
        _ candidate: Coordinate,
        in used: Set<Coordinate>,
        minDistance: Int,
        geometry: any GridGeometry
    ) -> Bool {
        used.contains { geometry.distance(from: candidate, to: $0) < minDistance }
    }

    // MARK: - Frozen Mirrors (Biome 3) Placement

    /// Minimum Chebyshev distance between the two tiles in a linked pair.
    /// Partners that are too close (distance 1–2) make the mechanic trivial —
    /// the player can identify both tiles visually without deduction. A minimum
    /// of 3 ensures the "swap" is non-obvious at first glance.
    private static let linkedMinPairDistance = 3

    /// Minimum Chebyshev distance between ANY two tiles from DIFFERENT pairs.
    /// Looser than `linkedMinPairDistance` — we want pairs to be spread out
    /// but don't need the same strict isolation as fog tiles.
    private static let linkedMinInterPairSeparation = 2

    /// Place linked tile pairs on the board during phase 1 (pre-first-scan).
    ///
    /// For each pair, two tiles are selected such that:
    /// 1. Partners are at least `linkedMinPairDistance` apart (Chebyshev) — non-trivial
    /// 2. Tiles from different pairs are at least `linkedMinInterPairSeparation` apart
    /// 3. Interior tiles are preferred over edge tiles (same as fog zone placement)
    ///
    /// Each tile gets a `LinkedData` pointing to its partner with `partnerSignal: nil`;
    /// `partnerSignal` is filled in by `RuleEngine.computeAllSignals` after hazards
    /// are placed and true signals are known.
    private static func placeLinkedPairs(
        on board: inout Board,
        spec: LevelSpec,
        rng: inout SplitMix64
    ) {
        guard let pairCount = spec.linkedPairCount, pairCount > 0 else { return }

        let geometry = board.geometry

        // Partition into interior (preferred) and edge (fallback), same logic as fog zones
        var interior: [Coordinate] = []
        var edge: [Coordinate] = []
        for coord in board.allCoordinates {
            if geometry.isInterior(coord, boardWidth: board.width, boardHeight: board.height) {
                interior.append(coord)
            } else {
                edge.append(coord)
            }
        }
        rng.shuffle(&interior)
        rng.shuffle(&edge)
        let candidates = interior + edge

        var usedCoords = Set<Coordinate>()
        var pairsPlaced = 0

        for i in 0..<candidates.count {
            guard pairsPlaced < pairCount else { break }
            let coordA = candidates[i]
            guard !usedCoords.contains(coordA) else { continue }
            guard !isTooCloseToSet(coordA, in: usedCoords, minDistance: linkedMinInterPairSeparation, geometry: geometry) else { continue }
            // Delta levels (Fog + Frozen Mirrors): linked tiles must not overlap
            // fog tiles so each tile's mechanic role stays unambiguous.
            guard board[coordA].fogData == nil else { continue }

            // Search for a valid partner for coordA
            for j in (i + 1)..<candidates.count {
                let coordB = candidates[j]
                guard !usedCoords.contains(coordB) else { continue }
                guard !isTooCloseToSet(coordB, in: usedCoords, minDistance: linkedMinInterPairSeparation, geometry: geometry) else { continue }
                guard board[coordB].fogData == nil else { continue }

                // Partners must be far enough apart to be non-trivial
                let dist = geometry.distance(from: coordA, to: coordB)
                guard dist >= linkedMinPairDistance else { continue }

                // Place the linked pair — each tile points to the other.
                // pairsPlaced is used as the pair index so both tiles share
                // the same index (and therefore the same color in TileView).
                board[coordA].linkedData = LinkedData(partnerCoord: coordB, pairIndex: pairsPlaced, partnerSignal: nil)
                board[coordB].linkedData = LinkedData(partnerCoord: coordA, pairIndex: pairsPlaced, partnerSignal: nil)
                usedCoords.insert(coordA)
                usedCoords.insert(coordB)
                pairsPlaced += 1
                break
            }
        }
    }

    /// Repair any linked pairs where both tiles display zero (each tile's partner has
    /// 0 hazard neighbors). Such pairs give the player no useful information —
    /// a linked pair showing ↔0 / ↔0 is indistinguishable from an unlinked zero tile.
    ///
    /// Called in phase 2, immediately after `RuleEngine.computeAllSignals` fills in
    /// `partnerSignal` on all surviving linked tiles — that is the earliest point at
    /// which zero-zero pairs can be detected (hazard positions aren't known in phase 1).
    ///
    /// **Strategy per zero-zero pair:**
    /// 1. Keep `coordA` (the first tile) as the anchor; try to find a replacement
    ///    partner from non-hazard, non-linked tiles that have ≥1 hazard neighbor.
    ///    The replacement must also be ≥ `linkedMinPairDistance` from `coordA`.
    /// 2. If a replacement is found: unlink old `coordB`, wire `(coordA, newPartner)`.
    /// 3. If no replacement exists (very rare on sparse boards): dissolve both tiles —
    ///    they become normal safe tiles. This is strictly better than leaving a useless
    ///    zero-zero pair in play.
    private static func repairZeroZeroLinkedPairs(
        on board: inout Board,
        rng: inout SplitMix64
    ) {
        let geometry = board.geometry

        // ── 1. Collect zero-zero pairs ────────────────────────────────────────────
        // Visit each pair exactly once (track both tiles to avoid double-processing).
        var zeroZeroPairs: [(coordA: Coordinate, coordB: Coordinate, pairIndex: Int)] = []
        var visited = Set<Coordinate>()

        for coord in board.allCoordinates {
            guard let ld = board[coord].linkedData else { continue }
            guard !visited.contains(coord) else { continue }
            visited.insert(coord)
            visited.insert(ld.partnerCoord)

            // A pair is zero-zero when the partner of EACH tile has 0 hazard neighbors.
            // (partnerSignal on tile A = hazard-neighbor count of tile B, and vice versa.)
            let partnerLd = board[ld.partnerCoord].linkedData
            if ld.partnerSignal == 0, partnerLd?.partnerSignal == 0 {
                zeroZeroPairs.append((coordA: coord,
                                      coordB: ld.partnerCoord,
                                      pairIndex: ld.pairIndex))
            }
        }

        guard !zeroZeroPairs.isEmpty else { return }

        // ── 2. Build replacement candidate pool ───────────────────────────────────
        // Eligible replacement tiles: not a hazard, not already linked, ≥1 hazard neighbor.
        // Shuffle with rng for deterministic randomness consistent with the board seed.
        var replacementPool: [Coordinate] = board.allCoordinates.filter { c in
            !board[c].isHazard &&
            board[c].linkedData == nil &&
            board.neighbors(of: c).contains(where: { board[$0].isHazard })
        }
        rng.shuffle(&replacementPool)

        // ── 3. Repair each zero-zero pair ─────────────────────────────────────────
        for pair in zeroZeroPairs {
            let coordA   = pair.coordA
            let coordB   = pair.coordB
            let pairIdx  = pair.pairIndex

            // coordA's own hazard count = what coordB would display after re-wiring.
            let sigA = board.neighbors(of: coordA).filter { board[$0].isHazard }.count

            // Search replacement pool for a valid partner for coordA.
            var newPartner:    Coordinate? = nil
            var poolIdxToRemove: Int?      = nil

            for (idx, candidate) in replacementPool.enumerated() {
                // Skip if already taken by a previous repair in this pass.
                guard board[candidate].linkedData == nil else { continue }
                guard candidate != coordA, candidate != coordB else { continue }

                let dist = geometry.distance(from: coordA, to: candidate)
                guard dist >= linkedMinPairDistance else { continue }

                newPartner      = candidate
                poolIdxToRemove = idx
                break
            }

            if let newB = newPartner, let poolIdx = poolIdxToRemove {
                // Re-wire: unlink old coordB, link coordA ↔ newB.
                let sigNewB = board.neighbors(of: newB).filter { board[$0].isHazard }.count
                board[coordB].linkedData = nil
                board[coordA].linkedData = LinkedData(partnerCoord: newB,
                                                       pairIndex:   pairIdx,
                                                       partnerSignal: sigNewB)
                board[newB].linkedData   = LinkedData(partnerCoord: coordA,
                                                       pairIndex:   pairIdx,
                                                       partnerSignal: sigA)
                replacementPool.remove(at: poolIdx)
            } else {
                // No valid replacement found — dissolve the pair so both tiles become
                // normal safe tiles rather than displaying useless zero-zero clues.
                board[coordA].linkedData = nil
                board[coordB].linkedData = nil
            }
        }
    }

    // MARK: - The Underside (Biome 5) Setup

    /// Mark every tile on the board as inverted during phase 1 (pre-first-scan).
    ///
    /// For Underside levels, every safe tile displays its safe-neighbor count instead
    /// of its hazard-neighbor count. This is a board-wide toggle, not a per-tile
    /// placement — so we mark ALL tiles up front. When hazards are placed in phase 2,
    /// `placeHazards` clears `invertedData` on each hazard tile (hazards don't display
    /// signals). `RuleEngine.computeAllSignals` (Pass 4) then fills `safeNeighborCount`
    /// for all remaining inverted tiles after true signals are known.
    ///
    /// Using per-tile `InvertedData` (rather than a board-level flag) means confluence
    /// levels can mix inverted and non-inverted tiles without any structural changes.
    private static func markAllTilesInverted(on board: inout Board) {
        for coord in board.allCoordinates {
            board[coord].invertedData = InvertedData(safeNeighborCount: nil)
        }
    }

    // MARK: - Ruins (Biome 4) Placement

    /// Place locked tiles on the board during phase 1 (pre-first-scan).
    ///
    /// Placement rules:
    /// 1. **Never in corners** — corners have only 3 neighbors, making unlock
    ///    thresholds either trivially easy or impossibly hard.
    /// 2. **Interior tiles** (8 neighbors, not on any edge): threshold = 6.
    ///    The player must reveal 6 of 8 neighbors to unlock.
    /// 3. **Edge tiles** (5 neighbors, on one edge, not a corner): threshold = 4.
    ///    The player must reveal 4 of 5 neighbors to unlock.
    /// 4. **Minimum separation** of 3 (Chebyshev) between locked tiles to prevent
    ///    clusters that could create large blocked zones.
    /// 5. Interior tiles are preferred to preserve cascade flow near edges.
    private static func placeLockedTiles(
        on board: inout Board,
        spec: LevelSpec,
        rng: inout SplitMix64
    ) {
        guard let count = spec.lockedTileCount, count > 0 else { return }

        let geometry = board.geometry

        // Categorize tiles into interior and edge (exclude corners entirely).
        // Corners are excluded because they have the fewest neighbors, making unlock
        // thresholds either trivially easy or impossibly hard regardless of grid shape.
        var interior: [Coordinate] = []
        var edge: [Coordinate] = []

        for coord in board.allCoordinates {
            if geometry.isCorner(coord, boardWidth: board.width, boardHeight: board.height) {
                continue  // Skip corners
            }
            if geometry.isOnBoardEdge(coord, boardWidth: board.width, boardHeight: board.height) {
                edge.append(coord)
            } else {
                interior.append(coord)
            }
        }

        rng.shuffle(&interior)
        rng.shuffle(&edge)
        let candidates = interior + edge

        var placed: [Coordinate] = []
        let minSeparation = 3

        for coord in candidates {
            guard placed.count < count else { break }

            // Delta levels: locked tiles must not overlap fog or linked tiles.
            // Fog is placed before locked (phase 1 order), linked is also before locked.
            if board[coord].fogData != nil    { continue }
            if board[coord].linkedData != nil { continue }

            // Enforce minimum separation between locked tiles
            if isTooClose(coord, to: placed, minDistance: minSeparation, geometry: geometry) { continue }

            // Determine threshold based on board position (geometry-aware)
            let threshold = geometry.lockThreshold(at: coord, boardWidth: board.width, boardHeight: board.height)

            board[coord].lockedData = LockedData(
                unlockThreshold: threshold,
                remainingNeighborsNeeded: threshold
            )
            placed.append(coord)
        }
    }

    // MARK: - Coral Basin (Biome 6) Placement

    /// Place sonar tiles on the board during phase 2 (after the safe zone is known).
    ///
    /// Placement strategy — all sonars are placed in UNIQUE rows AND unique columns.
    /// This is the key geometry that makes triangulation possible:
    ///
    ///   - Each pair of sonars (Ti, Tj) with unique rows AND columns produces
    ///     exactly 2 intersection cells: (Ti.row, Tj.col) and (Tj.row, Ti.col).
    ///   - With k sonars in k unique rows and k unique columns, there are
    ///     k*(k−1) total intersection cells.
    ///   - If two sonars shared a row or column, they would produce 0 intersection
    ///     cells with each other — wasted placement.
    ///
    /// Sonars are NOT placed in the safe zone so that the intersection cells
    /// they generate are usable as hazard positions.
    private static func placeSonarTiles(
        on board: inout Board,
        safeZone: Set<Coordinate>,
        spec: LevelSpec,
        rng: inout SplitMix64
    ) {
        // Exclude the safe zone AND any pre-placed locked tiles (Delta: Sonar + Ruins).
        // A locked tile cannot also be a sonar — their mechanics are incompatible.
        var candidates = board.allCoordinates.filter {
            !safeZone.contains($0) && !board[$0].isLocked
        }
        rng.shuffle(&candidates)

        var usedRows = Set<Int>()
        var usedCols = Set<Int>()
        var placed = 0

        for coord in candidates {
            guard placed < spec.sonarCount else { break }
            // Enforce unique row AND column to maximise triangulatable intersection cells.
            guard !usedRows.contains(coord.row) else { continue }
            guard !usedCols.contains(coord.col) else { continue }

            board[coord].sonarData = SonarData()
            // Delta levels (Sonar + Underside): clear any invertedData on this tile.
            // Sonar display always takes precedence — sonar tiles show their directional
            // count, not the inverted safe-neighbor count. Phase 1 marks ALL tiles as
            // inverted for Underside boards, so we must explicitly clear sonar tiles here.
            board[coord].invertedData = nil
            usedRows.insert(coord.row)
            usedCols.insert(coord.col)
            placed += 1
        }
    }

    /// Returns all coordinates that are triangulatable — covered by at least one
    /// horizontal AND one vertical sonar sight line — and not in the safe zone.
    ///
    /// A cell (r, c) is horizontally covered if there is a sonar in row r
    /// (a different column), giving the player a row-constrained hazard count.
    /// A cell (r, c) is vertically covered if there is a sonar in column c
    /// (a different row), giving a column-constrained hazard count.
    /// Together, H + V coverage means two different sonars pin the exact cell.
    ///
    /// Sonar cells themselves are excluded — they can't be hazards.
    private static func sonarIntersectionCells(
        on board: Board,
        safeZone: Set<Coordinate>
    ) -> [Coordinate] {
        // Build fast lookup sets: which rows and which columns contain a sonar?
        var sonarRows = Set<Int>()
        var sonarCols = Set<Int>()
        for coord in board.allCoordinates {
            if board[coord].isSonar {
                sonarRows.insert(coord.row)
                sonarCols.insert(coord.col)
            }
        }

        var result: [Coordinate] = []
        for coord in board.allCoordinates {
            if safeZone.contains(coord) { continue }
            if board[coord].isSonar   { continue }
            // H-coverage: a sonar exists somewhere in this cell's row
            // V-coverage: a sonar exists somewhere in this cell's column
            if sonarRows.contains(coord.row) && sonarCols.contains(coord.col) {
                result.append(coord)
            }
        }
        return result
    }

    // MARK: - Helpers

    /// Returns the set of coordinates in the safe zone around a center tile.
    ///
    /// For square grids this is the classic 3×3 zone (center + all 8 neighbors).
    /// For hex grids this is the center + all 6 immediate neighbors.
    /// Clipped to board bounds in both cases.
    private static func safeZoneCoordinates(around center: Coordinate, board: Board) -> Set<Coordinate> {
        var zone = Set<Coordinate>()
        zone.insert(center)
        for neighbor in board.neighbors(of: center) {
            zone.insert(neighbor)
        }
        return zone
    }
}
