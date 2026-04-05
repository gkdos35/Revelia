// Revelia/Models/LevelSpec.swift

import Foundation

/// Defines the parameters for a single level.
/// Levels are data-driven: the engine reads a LevelSpec and generates a board from it.
///
/// Biome-specific parameters are optional — nil means "this mechanic isn't active."
/// This keeps Biome 0 levels clean and allows the engine to check which mechanics
/// apply by testing for nil.
struct LevelSpec: Codable, Equatable, Identifiable {
    let id: String
    let biomeId: Int
    let displayName: String
    let boardWidth: Int
    let boardHeight: Int
    let hazardDensity: Double   // Fraction of total tiles that are hazards (e.g., 0.15)
    let parTimeSeconds: Int     // Par time for 2-star rating

    // MARK: - Biome 1: Fog Marsh Parameters

    /// Exact number of fogged tiles to place on the board.
    /// Small counts (2–6) keep fog as a punctuation mark on the board rather
    /// than a dominant mechanic, preserving the cascade-open feeling.
    var fogCount: Int?

    /// Number of beacon charges the player starts with.
    /// Each charge lets the player target one fogged tile to clear its fog,
    /// revealing the exact signal. Charges are activated from the HUD, then
    /// the player clicks the fogged tile to spend the charge.
    var beaconCharges: Int?

    // MARK: - Biome 2: Bioluminescence Parameters

    /// Number of deep pulse charges the player starts with (Biome 2: Bioluminescence).
    /// Each charge activates a targeting mode; the next click sends a bioluminescent
    /// glow through a 3×3 area for 1 second, briefly revealing the true state of all
    /// tiles in that area before the glow fades and tiles revert to their normal state.
    var conductorCharges: Int?

    // MARK: - Biome 3: Frozen Mirrors Parameters

    /// Exact number of linked tile PAIRS to place.
    /// Each pair is two tiles that display each other's signal count.
    /// Small counts (1–4) keep the mechanic as a deduction puzzle layered on top
    /// of normal play, rather than transforming the whole board into a swap game.
    var linkedPairCount: Int?

    // MARK: - Biome 4: Ruins Parameters

    /// Exact number of locked tiles to place on the board.
    /// Locked tiles are always safe and never hazards. They won't reveal until
    /// enough surrounding neighbors have been uncovered (6 of 8 for interior
    /// tiles, 4 of 5 for edge tiles). They are never placed in corners.
    var lockedTileCount: Int?

    // MARK: - Biome 5: The Underside Parameters

    /// When true, every safe tile on the board displays its safe-neighbor count
    /// instead of its hazard-neighbor count. There is no per-tile count parameter —
    /// the mechanic applies to the whole board. Defaults to false.
    var isInvertedBoard: Bool = false

    // MARK: - Biome 6: Coral Basin Parameters

    /// Number of sonar tiles to place on the board.
    /// Sonars count hazards in all four cardinal directions (N/S/E/W) and display
    /// the combined total. Two or more sonars allow the player to triangulate exact
    /// hazard positions by cross-referencing their intersecting sight lines.
    ///
    /// Placement enforces unique rows AND columns for all sonars, ensuring each
    /// pair produces a distinct row×column intersection cell where hazards can be placed.
    /// With k sonars (unique rows+cols), up to k*(k−1) intersection cells exist.
    var sonarCount: Int = 0

    // MARK: - Biome 7: Quicksand Parameters

    /// When true, all revealed tile numbers gradually fade over a shared countdown timer.
    /// Clicking any hidden tile resurfaces all numbers and resets the countdown.
    /// The mechanic is purely visual and board-wide — no per-tile struct is needed.
    var isQuicksandBoard: Bool = false

    /// Duration in seconds for revealed numbers to fully fade from sight.
    /// Ranges from 6.0s on the first Quicksand levels down to 3.0s on the hardest.
    /// Ignored when isQuicksandBoard is false.
    var quicksandFadeSeconds: Double = 6.0

    // MARK: - Grid Shape

    /// The board topology for this level. Defaults to `.square` (the classic 8-neighbor grid
    /// used by all existing biomes 0–8). Set to `.hexagonal` for future hex levels.
    var gridShape: GridShape = .square

    // Future biomes will add optional params here as new biomes are built.

    /// Computed: number of hazards for this level (rounded to nearest int).
    var hazardCount: Int {
        let total = boardWidth * boardHeight
        return max(1, Int((Double(total) * hazardDensity).rounded()))
    }

    /// Total number of tiles on the board.
    var tileCount: Int {
        boardWidth * boardHeight
    }

    /// Total number of safe tiles on the board.
    var safeTileCount: Int {
        max(1, tileCount - hazardCount)
    }

    /// Aggregate mechanic difficulty used by scoring and star thresholds.
    /// Combines both biome type and how strongly that mechanic is present on this level.
    var mechanicComplexityScore: Double {
        var score = 0.0

        if hasFog {
            score += 0.45
            score += Double(fogCount ?? 0) * 0.04
            score += Double(beaconCharges ?? 0) * 0.12
        }
        if hasConductor {
            score += 0.55
            score += Double(conductorCharges ?? 0) * 0.18
        }
        if hasLinked {
            score += 0.65
            score += Double(linkedPairCount ?? 0) * 0.05
        }
        if hasLocked {
            score += 0.55
            score += Double(lockedTileCount ?? 0) * 0.03
        }
        if hasInverted {
            score += 0.80
        }
        if hasSonar {
            score += 0.70
            score += Double(sonarCount) * 0.08
        }
        if hasQuicksand {
            score += 0.70
            score += max(0, 6.0 - quicksandFadeSeconds) * 0.22
        }
        if biomeId % 9 == 8 {
            score += 0.60
        }

        return score
    }

    /// Whether this level has fog mechanics active.
    var hasFog: Bool { fogCount != nil }

    /// Whether this level has bioluminescence conductor charges active.
    var hasConductor: Bool { (conductorCharges ?? 0) > 0 }

    /// Whether this level has linked tile mechanics active.
    var hasLinked: Bool { linkedPairCount != nil }

    /// Whether this level has locked tile mechanics active.
    var hasLocked: Bool { (lockedTileCount ?? 0) > 0 }

    /// Whether this level uses the inverted (Underside) board mechanic.
    var hasInverted: Bool { isInvertedBoard }

    /// Whether this level has sonar tiles active.
    var hasSonar: Bool { sonarCount > 0 }

    /// Whether this level uses the quicksand (fading tiles) board mechanic.
    var hasQuicksand: Bool { isQuicksandBoard }

    /// The level's global number extracted from its ID string ("L47" → 47).
    /// Used on the level-select info card to show "Level 47" or "Level 47 — Hex".
    var absoluteLevelNumber: Int {
        Int(id.dropFirst()) ?? 0
    }

    /// The biome's human-readable name, derived from biomeId.
    /// Hex biomes (9–17) return the same name as their square counterpart (0–8).
    var biomeName: String {
        switch biomeId % 9 {
        case 0: return "Training Range"
        case 1: return "Fog Marsh"
        case 2: return "Bioluminescence"
        case 3: return "Frozen Mirrors"
        case 4: return "Ruins"
        case 5: return "The Underside"
        case 6: return "Coral Basin"
        case 7: return "Quicksand"
        default: return "The Delta"
        }
    }

    /// Short one-line description of the active mechanics.
    /// Shown on the level-select info card as a hint before playing.
    ///
    /// - Training Range (biome 0): returns "" — no mechanic line shown.
    /// - The Delta (biome 8 / 17): builds a comma-separated list of the mechanics
    ///   that are actually active in THIS particular level, using the short names
    ///   Fog / Pulse / Linked / Locked / Inverted / Sonar / Fading.
    /// - All other biomes: fixed string describing the biome's single mechanic.
    var mechanicHint: String {
        switch biomeId % 9 {
        case 0:
            return ""   // Training Range — baseline, no mechanic description needed
        case 1: return "Fogged tiles, beacon charges"
        case 2: return "Conductor pulse reveals"
        case 3: return "Linked tile pairs"
        case 4: return "Locked tile gates"
        case 5: return "Inverted signal counts"
        case 6: return "Sonar directional counts"
        case 7: return "Signals fade over time"
        default:
            // The Delta — list only the mechanics active in this specific level.
            var parts: [String] = []
            if hasFog       { parts.append("Fog") }
            if hasConductor { parts.append("Pulse") }
            if hasLinked    { parts.append("Linked") }
            if hasLocked    { parts.append("Locked") }
            if hasInverted  { parts.append("Inverted") }
            if hasSonar     { parts.append("Sonar") }
            if hasQuicksand { parts.append("Fading") }
            return parts.joined(separator: ", ")
        }
    }

    /// Asset catalog name for the full-bleed gameplay background image.
    /// Hex biomes (9–17) reuse the same images as their square counterparts (0–8)
    /// via the `biomeId % 9` mapping.
    var gameplayImageName: String {
        switch biomeId % 9 {
        case 0: return "TrainingRangeGameplay"
        case 1: return "FogMarshGameplay"
        case 2: return "BioluminescenceGameplay"
        case 3: return "FrozenMirrorsGameplay"
        case 4: return "RuinsGameplay"
        case 5: return "TheUndersideGameplay"
        case 6: return "CoralBasinGameplay"
        case 7: return "QuicksandGameplay"
        default: return "TheDeltaGameplay"
        }
    }
}

// MARK: - Biome 0 Levels (Training Range)

extension LevelSpec {
    /// All Training Range levels as defined in the spec.
    static let trainingRange: [LevelSpec] = [
        LevelSpec(id: "L1",  biomeId: 0, displayName: "Training Range 1",
                  boardWidth: 6, boardHeight: 6, hazardDensity: 0.12, parTimeSeconds: 60),
        LevelSpec(id: "L2",  biomeId: 0, displayName: "Training Range 2",
                  boardWidth: 6, boardHeight: 6, hazardDensity: 0.14, parTimeSeconds: 60),
        LevelSpec(id: "L3",  biomeId: 0, displayName: "Training Range 3",
                  boardWidth: 7, boardHeight: 7, hazardDensity: 0.14, parTimeSeconds: 90),
        LevelSpec(id: "L4",  biomeId: 0, displayName: "Training Range 4",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.15, parTimeSeconds: 120),
        LevelSpec(id: "L5",  biomeId: 0, displayName: "Training Range 5",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.16, parTimeSeconds: 120),
        LevelSpec(id: "L6",  biomeId: 0, displayName: "Training Range 6",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.17, parTimeSeconds: 90),
    ]
}

// MARK: - Biome 1 Levels (Fog Marsh)

extension LevelSpec {
    /// All Fog Marsh levels as defined in the spec.
    ///
    /// Fog counts are deliberately low (2–6) so fogged tiles act as isolated
    /// deduction puzzles rather than dominating the board. Combined with the
    /// spacing constraint in BoardGenerator (Chebyshev distance ≥ 3 between
    /// fog tiles), this preserves the cascade-open feeling from Biome 0.
    static let fogMarsh: [LevelSpec] = [
        LevelSpec(id: "L7",  biomeId: 1, displayName: "Fog Marsh 1",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.16, parTimeSeconds: 120,
                  fogCount: 2, beaconCharges: 1),
        LevelSpec(id: "L8",  biomeId: 1, displayName: "Fog Marsh 2",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.16, parTimeSeconds: 120,
                  fogCount: 2, beaconCharges: 1),
        LevelSpec(id: "L9",  biomeId: 1, displayName: "Fog Marsh 3",
                  boardWidth: 9, boardHeight: 9, hazardDensity: 0.17, parTimeSeconds: 150,
                  fogCount: 3, beaconCharges: 1),
        LevelSpec(id: "L10", biomeId: 1, displayName: "Fog Marsh 4",
                  boardWidth: 9, boardHeight: 9, hazardDensity: 0.17, parTimeSeconds: 150,
                  fogCount: 3, beaconCharges: 1),
        LevelSpec(id: "L11", biomeId: 1, displayName: "Fog Marsh 5",
                  boardWidth: 9, boardHeight: 9, hazardDensity: 0.18, parTimeSeconds: 180,
                  fogCount: 4, beaconCharges: 2),
        LevelSpec(id: "L12", biomeId: 1, displayName: "Fog Marsh 6",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.18, parTimeSeconds: 180,
                  fogCount: 4, beaconCharges: 2),
        LevelSpec(id: "L13", biomeId: 1, displayName: "Fog Marsh 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  fogCount: 5, beaconCharges: 2),
        LevelSpec(id: "L14", biomeId: 1, displayName: "Fog Marsh 8",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.20, parTimeSeconds: 210,
                  fogCount: 6, beaconCharges: 2),
    ]
}

// MARK: - Biome 2 Levels (Bioluminescence)

extension LevelSpec {
    /// All Bioluminescence levels (L15–L22).
    ///
    /// **Mechanic:** Each level gives the player one deep pulse charge. Activating
    /// it enters targeting mode; the next click sends a bioluminescent glow through
    /// a 3×3 area centered on the clicked tile for exactly 1 second. During the glow,
    /// all tiles in the area briefly show their true state — safe tiles display their
    /// exact signal, hazards show their indicator — before the glow fades and tiles
    /// revert to their normal hidden/revealed appearance. The pulse is read-only and
    /// changes no tile states; it is a pure information burst.
    ///
    /// **Grid reset:** Starts at 6×6 (smaller than where Fog Marsh ended at 10×10)
    /// and scales back up to 11×11 over the 8 levels.
    static let bioluminescence: [LevelSpec] = [
        // L15 — intro: 1 conductor charge, smallest grid to let the player find the rhythm
        LevelSpec(id: "L15", biomeId: 2, displayName: "Bioluminescence 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  conductorCharges: 1),
        // L16 — 1 charge, 7×7
        LevelSpec(id: "L16", biomeId: 2, displayName: "Bioluminescence 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  conductorCharges: 1),
        // L17 — 1 charge, 7×7
        LevelSpec(id: "L17", biomeId: 2, displayName: "Bioluminescence 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  conductorCharges: 1),
        // L18 — 1 charge, 8×8
        LevelSpec(id: "L18", biomeId: 2, displayName: "Bioluminescence 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  conductorCharges: 1),
        // L19 — 1 charge, 9×9
        LevelSpec(id: "L19", biomeId: 2, displayName: "Bioluminescence 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  conductorCharges: 1),
        // L20 — 1 charge, 9×9
        LevelSpec(id: "L20", biomeId: 2, displayName: "Bioluminescence 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 180,
                  conductorCharges: 1),
        // L21 — 1 charge, 10×10
        LevelSpec(id: "L21", biomeId: 2, displayName: "Bioluminescence 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  conductorCharges: 1),
        // L22 — 1 charge, 11×11; largest grid in the biome
        LevelSpec(id: "L22", biomeId: 2, displayName: "Bioluminescence 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.20, parTimeSeconds: 240,
                  conductorCharges: 1),
    ]
}

// MARK: - Biome 3 Levels (Frozen Mirrors)

extension LevelSpec {
    /// All Frozen Mirrors levels as defined in the spec.
    ///
    /// Grid sizes start small (6×6 at L23) and scale up to 11×11 by L30, following
    /// the principle that each biome's first level should start noticeably smaller
    /// than where the previous biome ended (Bioluminescence ended at 11×11).
    ///
    /// L23 is a deliberate intro tutorial: the smallest grid with exactly one pair.
    /// On a 6×6 board the pair is immediately prominent and the player will almost
    /// certainly need the link relationship to resolve at least one ambiguous tile —
    /// teaching the mechanic through play rather than reading alone.
    static let frozenMirrors: [LevelSpec] = [
        LevelSpec(id: "L23", biomeId: 3, displayName: "Frozen Mirrors 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  linkedPairCount: 1),
        LevelSpec(id: "L24", biomeId: 3, displayName: "Frozen Mirrors 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  linkedPairCount: 2),
        LevelSpec(id: "L25", biomeId: 3, displayName: "Frozen Mirrors 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  linkedPairCount: 2),
        LevelSpec(id: "L26", biomeId: 3, displayName: "Frozen Mirrors 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  linkedPairCount: 3),
        LevelSpec(id: "L27", biomeId: 3, displayName: "Frozen Mirrors 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  linkedPairCount: 3),
        LevelSpec(id: "L28", biomeId: 3, displayName: "Frozen Mirrors 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 180,
                  linkedPairCount: 4),
        LevelSpec(id: "L29", biomeId: 3, displayName: "Frozen Mirrors 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  linkedPairCount: 4),
        LevelSpec(id: "L30", biomeId: 3, displayName: "Frozen Mirrors 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.20, parTimeSeconds: 240,
                  linkedPairCount: 5),
    ]
}

// MARK: - Biome 4 Levels (Ruins)

extension LevelSpec {
    /// All Ruins levels (L31–L38).
    ///
    /// **Mechanic:** Locked tiles are always safe and never hazards. They won't
    /// reveal until enough surrounding neighbors have been uncovered: 6 out of 8
    /// for interior tiles, 4 out of 5 for edge tiles. They are never placed in
    /// corners. When the threshold is reached the tile unlocks with a satisfying
    /// animation and, if its signal is 0, cascades normally into its neighbors.
    /// While locked, they show a padlock icon and a countdown number showing how
    /// many more neighbors must be revealed before they unlock.
    ///
    /// **Grid reset:** Starts at 6×6 (smaller than where Frozen Mirrors ended at 11×11)
    /// and scales back up to 11×11 by L38, with locked count ramping from 1 to 5.
    static let ruins: [LevelSpec] = [
        // L31 — intro: 1 locked tile, smallest grid so the mechanic is unmissable
        LevelSpec(id: "L31", biomeId: 4, displayName: "Ruins 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  lockedTileCount: 1),
        // L32 — 1 locked, 7×7
        LevelSpec(id: "L32", biomeId: 4, displayName: "Ruins 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  lockedTileCount: 1),
        // L33 — 2 locked, 7×7
        LevelSpec(id: "L33", biomeId: 4, displayName: "Ruins 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  lockedTileCount: 2),
        // L34 — 2 locked, 8×8
        LevelSpec(id: "L34", biomeId: 4, displayName: "Ruins 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  lockedTileCount: 2),
        // L35 — 3 locked, 9×9
        LevelSpec(id: "L35", biomeId: 4, displayName: "Ruins 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  lockedTileCount: 3),
        // L36 — 3 locked, 9×9
        LevelSpec(id: "L36", biomeId: 4, displayName: "Ruins 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 180,
                  lockedTileCount: 3),
        // L37 — 4 locked, 10×10
        LevelSpec(id: "L37", biomeId: 4, displayName: "Ruins 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  lockedTileCount: 4),
        // L38 — 5 locked, 11×11; most constrained Ruins level
        LevelSpec(id: "L38", biomeId: 4, displayName: "Ruins 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.20, parTimeSeconds: 240,
                  lockedTileCount: 5),
    ]
}

// MARK: - Biome 5 Levels (The Underside)

extension LevelSpec {
    /// All Underside levels as defined in the spec.
    ///
    /// Every tile on an Underside board shows its safe-neighbor count instead of
    /// its hazard-neighbor count. No per-level count parameter is needed — the
    /// `isInvertedBoard: true` flag activates the mechanic for the whole board.
    ///
    /// Grid sizes start at 6×6 (L39) and scale up to 11×11 by L46, following the
    /// same biome-entry principle: start noticeably smaller than where the previous
    /// biome ended (Ruins ended at 11×11), ramp back up across 8 levels.
    ///
    /// Hazard density starts low (0.12) so the first board is spacious enough for
    /// the player to build intuition for inverted numbers before density increases.
    static let theUnderside: [LevelSpec] = [
        LevelSpec(id: "L39", biomeId: 5, displayName: "The Underside 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  isInvertedBoard: true),
        LevelSpec(id: "L40", biomeId: 5, displayName: "The Underside 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.13, parTimeSeconds: 120,
                  isInvertedBoard: true),
        LevelSpec(id: "L41", biomeId: 5, displayName: "The Underside 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  isInvertedBoard: true),
        LevelSpec(id: "L42", biomeId: 5, displayName: "The Underside 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.15, parTimeSeconds: 150,
                  isInvertedBoard: true),
        LevelSpec(id: "L43", biomeId: 5, displayName: "The Underside 5",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  isInvertedBoard: true),
        LevelSpec(id: "L44", biomeId: 5, displayName: "The Underside 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  isInvertedBoard: true),
        LevelSpec(id: "L45", biomeId: 5, displayName: "The Underside 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.18, parTimeSeconds: 210,
                  isInvertedBoard: true),
        LevelSpec(id: "L46", biomeId: 5, displayName: "The Underside 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.19, parTimeSeconds: 240,
                  isInvertedBoard: true),
    ]
}

// MARK: - Biome 6 Levels (Coral Basin)

extension LevelSpec {
    /// All Coral Basin levels as defined in the spec.
    ///
    /// **Mechanic:** Sonar tiles display the total count of hazards across
    /// all four cardinal sight lines (N + S + E + W). Players cross-reference two
    /// or more sonars to triangulate exact hazard positions.
    ///
    /// **Solvability guarantee:** Hazards are placed ONLY at cells covered by at
    /// least one horizontal and one vertical sonar sight line (H + V
    /// "intersection cells"). With k sonars placed in unique rows and unique
    /// columns, up to k*(k−1) intersection cells exist, all of which are provably
    /// triangulatable without guessing.
    ///
    /// **Density calibration:** Hazard density is kept low enough that the target
    /// hazard count (boardWidth×boardHeight×density) stays at or below the number
    /// of intersection cells, even after the 3×3 safe zone is subtracted.
    ///
    ///   k=2 → 2 cells   k=3 → 6   k=4 → 12   k=5 → 20   k=6 → 30
    ///
    /// Grid sizes reset to 6×6 at L47 and scale back up to 11×11 at L54,
    /// following the biome-entry reset convention (The Underside ended at 11×11).
    static let coralBasin: [LevelSpec] = [
        // L47 — intro: 3 sonars creates a healthier intersection pool after the
        // first-scan safe zone is removed, avoiding near-empty boards.
        LevelSpec(id: "L47", biomeId: 6, displayName: "Coral Basin 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.11, parTimeSeconds: 90,
                  sonarCount: 3),
        // L48 — 4 sonars gives the second level enough triangulatable space to
        // support a fuller opening board state.
        LevelSpec(id: "L48", biomeId: 6, displayName: "Coral Basin 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  sonarCount: 4),
        // L49 — keep the same board size but maintain a wider intersection pool.
        LevelSpec(id: "L49", biomeId: 6, displayName: "Coral Basin 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  sonarCount: 4),
        // L50 — continue the ramp with a denser first medium board.
        LevelSpec(id: "L50", biomeId: 6, displayName: "Coral Basin 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  sonarCount: 4),
        // L51 — 4 sonars → 12 cells → ≈11 hazards
        LevelSpec(id: "L51", biomeId: 6, displayName: "Coral Basin 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.13, parTimeSeconds: 180,
                  sonarCount: 4),
        // L52 — 5 sonars → 20 cells → ≈12 hazards
        LevelSpec(id: "L52", biomeId: 6, displayName: "Coral Basin 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.15, parTimeSeconds: 180,
                  sonarCount: 5),
        // L53 — 5 sonars → 20 cells → ≈16 hazards
        LevelSpec(id: "L53", biomeId: 6, displayName: "Coral Basin 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.16, parTimeSeconds: 210,
                  sonarCount: 5),
        // L54 — 6 sonars → 30 cells → ≈21 hazards
        LevelSpec(id: "L54", biomeId: 6, displayName: "Coral Basin 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 240,
                  sonarCount: 6),
    ]
}

// MARK: - Biome 7 Levels (Quicksand)

extension LevelSpec {
    /// All Quicksand levels (L55–L62).
    ///
    /// **Mechanic:** A shared countdown timer drives all revealed numbers fading
    /// simultaneously. The fade is linear so the player sees a constant, predictable
    /// rate of disappearance across the full countdown window. Clicking any hidden
    /// tile resurfaces all numbers instantly and resets the countdown.
    ///
    /// **Fade formula (in TileView):** `opacity = 1 − fadeProgress`
    /// producing a pure linear fade. The sand tint uses the same progress value
    /// directly (`progress × maxTint`), so the two layers are perfectly mirrored.
    ///
    /// **Timing:** Pairs of levels share a window, dropping by 1 s each pair:
    ///   L55–L56 → 6 s | L57–L58 → 5 s | L59–L60 → 4 s | L61–L62 → 3 s
    ///
    /// **Grid reset:** Starts at 6×6 (smaller than where Coral Basin ended at 11×11)
    /// and scales back up to 10×10 over the 8 levels.
    static let quicksand: [LevelSpec] = [
        // L55 — 6 s intro window, smallest grid to let the player find the rhythm
        LevelSpec(id: "L55", biomeId: 7, displayName: "Quicksand 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 120,
                  isQuicksandBoard: true, quicksandFadeSeconds: 6.0),
        // L56 — 6 s, 7×7
        LevelSpec(id: "L56", biomeId: 7, displayName: "Quicksand 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 150,
                  isQuicksandBoard: true, quicksandFadeSeconds: 6.0),
        // L57 — 5 s, 7×7
        LevelSpec(id: "L57", biomeId: 7, displayName: "Quicksand 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 150,
                  isQuicksandBoard: true, quicksandFadeSeconds: 5.0),
        // L58 — 5 s, 8×8
        LevelSpec(id: "L58", biomeId: 7, displayName: "Quicksand 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 180,
                  isQuicksandBoard: true, quicksandFadeSeconds: 5.0),
        // L59 — 4 s, 8×8; pressure noticeably increases
        LevelSpec(id: "L59", biomeId: 7, displayName: "Quicksand 5",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.17, parTimeSeconds: 180,
                  isQuicksandBoard: true, quicksandFadeSeconds: 4.0),
        // L60 — 4 s, 9×9; requires decisive scanning rhythm
        LevelSpec(id: "L60", biomeId: 7, displayName: "Quicksand 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 210,
                  isQuicksandBoard: true, quicksandFadeSeconds: 4.0),
        // L61 — 3 s; numbers disappear fast, memory becomes essential
        LevelSpec(id: "L61", biomeId: 7, displayName: "Quicksand 7",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.19, parTimeSeconds: 210,
                  isQuicksandBoard: true, quicksandFadeSeconds: 3.0),
        // L62 — 3 s, 10×10; hardest Quicksand level — relentless pace
        LevelSpec(id: "L62", biomeId: 7, displayName: "Quicksand 8",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.20, parTimeSeconds: 240,
                  isQuicksandBoard: true, quicksandFadeSeconds: 3.0),
    ]
}

// MARK: - Biome 8 Levels (The Delta)

extension LevelSpec {
    /// All Delta levels (L63–L74).
    ///
    /// **Concept:** The Delta is the game's final zone — 12 levels where mechanics
    /// from multiple biomes collide on the same board. Every level combines exactly
    /// two or more previously learned mechanics without additional tutorial support.
    /// Players entering The Delta have cleared all 7 biomes and are fully equipped.
    ///
    /// **Grid:** All 12 levels use a fixed 11×11 board. No ramp-up grid — the Delta
    /// assumes mastery.
    ///
    /// **Ordering principle:** Non-Quicksand combos first (L63–L69), then all Quicksand
    /// combos as the ultimate endgame challenge (L70–L74). Within each group, combos
    /// escalate from two-mechanic to three-mechanic.
    ///
    /// **Design notes per level:**
    ///   L63  Fog + Ruins                       — fog obscures, locked tiles delay; beacon helps uncork
    ///   L64  Sonar + Ruins                     — locked tiles must be factored into sight-line deductions
    ///   L65  Mirrors + Underside               — linked tiles display partner's safe-count; color pairs guide
    ///   L66  Pulse + Ruins                     — one flash to illuminate locked regions before they open
    ///   L67  Sonar + Mirrors                   — linked sight-line tiles create compound cross-references
    ///   L68  Sonar + Mirrors + Underside        — linked inverted sonar counts; most mechanically dense
    ///   L69  Ruins + Sonar + Underside          — locked sonar tiles on an inverted board
    ///   L70  Pulse + Quicksand                 — brief illumination against a ticking fade clock
    ///   L71  Underside + Quicksand             — safe-count logic under time pressure
    ///   L72  Fog + Quicksand                   — fog under time pressure; careful beacon management
    ///   L73  Fog + Quicksand + Ruins            — triple threat; fog cannot overlap locked tiles
    ///   L74  Pulse + Quicksand + Fog            — burst of light as the only memory aid when sand buries
    static let theDelta: [LevelSpec] = [

        // L63 — Fog Marsh + Ruins: fog tiles and locked tiles on the same board.
        // 3 fog tiles, 1 beacon charge to spend wisely. 2 locked tiles add temporal delay.
        LevelSpec(id: "L63", biomeId: 8, displayName: "The Delta 1",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 270,
                  fogCount: 3, beaconCharges: 1, lockedTileCount: 2),

        // L64 — Coral Basin + Ruins: sonar tiles and locked tiles.
        // 4 sonars for triangulation; 2 locked tiles that may sit in sight lines.
        // Low density (0.08) keeps hazard count within the sonar intersection budget.
        LevelSpec(id: "L64", biomeId: 8, displayName: "The Delta 2",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.08, parTimeSeconds: 270,
                  lockedTileCount: 2, sonarCount: 4),

        // L65 — Frozen Mirrors + The Underside: linked tiles on an inverted board.
        // The ↔ prefix on a linked tile shows the partner's safe-neighbor count, not
        // its hazard count. RuleEngine Pass 3 (inverted) runs before Pass 4 (linked)
        // so partnerSignal is correctly set to invertedData.safeNeighborCount.
        LevelSpec(id: "L65", biomeId: 8, displayName: "The Delta 3",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 270,
                  linkedPairCount: 3, isInvertedBoard: true),

        // L66 — Bioluminescence + Ruins: one pulse charge to illuminate locked-tile regions.
        // The flash reveals hidden tile states around locked tiles before their countdowns
        // fire, letting the player plan neighbors without guessing. 2 locked tiles create
        // two pressure points that the single charge must cover strategically.
        LevelSpec(id: "L66", biomeId: 8, displayName: "The Delta 4",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  conductorCharges: 1, lockedTileCount: 2),

        // L67 — Coral Basin + Frozen Mirrors: sonar sight lines cross linked pairs.
        // A linked tile may sit in a sonar's sight line — its OWN signal (not partner's)
        // is counted, since sonar counts hazards in cardinal directions, not tile signals.
        LevelSpec(id: "L67", biomeId: 8, displayName: "The Delta 5",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.09, parTimeSeconds: 270,
                  linkedPairCount: 2, sonarCount: 4),

        // L68 — Sonar + Frozen Mirrors + The Underside: mechanically dense three-way combo.
        // Linked tiles on an inverted board inside sonar sight lines. The linked ↔ tiles
        // show the partner's safe-count; sonars count hazards in cardinal directions.
        // Very low density (0.04) keeps hazard count within the sonar intersection budget.
        LevelSpec(id: "L68", biomeId: 8, displayName: "The Delta 6",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.04, parTimeSeconds: 240,
                  linkedPairCount: 2, isInvertedBoard: true, sonarCount: 3),

        // L69 — Ruins + Coral Basin + The Underside: locked sonar tiles on an inverted board.
        // BoardGenerator ensures sonar tiles are not placed on locked tiles. Non-sonar tiles
        // show safe counts; sonar tiles show directional hazard totals regardless of inversion.
        // Very low density keeps hazard count within the sonar intersection budget.
        LevelSpec(id: "L69", biomeId: 8, displayName: "The Delta 7",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.04, parTimeSeconds: 240,
                  lockedTileCount: 2, isInvertedBoard: true, sonarCount: 3),

        // ── Quicksand gauntlet (L70–L74) ────────────────────────────────────────────────

        // L70 — Bioluminescence + Quicksand: one pulse charge against a fading clock.
        // The pulse can resurface numbers AND reveal hidden state; timing matters.
        LevelSpec(id: "L70", biomeId: 8, displayName: "The Delta 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  conductorCharges: 1, isQuicksandBoard: true, quicksandFadeSeconds: 4.0),

        // L71 — The Underside + Quicksand: safe-count logic under time pressure.
        // Numbers fade while the player must reason about inverted values from memory.
        LevelSpec(id: "L71", biomeId: 8, displayName: "The Delta 9",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  isInvertedBoard: true, isQuicksandBoard: true, quicksandFadeSeconds: 4.0),

        // L72 — Fog Marsh + Quicksand: fogged tiles under a fading clock.
        // Beacon saves one tile from ambiguity; the rest must be read before the sand falls.
        LevelSpec(id: "L72", biomeId: 8, displayName: "The Delta 10",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  fogCount: 3, beaconCharges: 1, isQuicksandBoard: true, quicksandFadeSeconds: 4.0),

        // L73 — Fog + Quicksand + Ruins: triple-mechanic gauntlet.
        // Fog tiles cannot be locked (BoardGenerator enforces). The 2 locked tiles
        // unlock at their own pace while fog presses from the top.
        LevelSpec(id: "L73", biomeId: 8, displayName: "The Delta 11",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 240,
                  fogCount: 3, beaconCharges: 1, lockedTileCount: 2,
                  isQuicksandBoard: true, quicksandFadeSeconds: 4.0),

        // L74 — Bioluminescence + Quicksand + Fog Marsh: full memory-aid arsenal.
        // The pulse is the only way to see fogged values after sand buries them.
        // Tight fade window (3.5 s) punishes hesitation — the hardest level in the game.
        LevelSpec(id: "L74", biomeId: 8, displayName: "The Delta 12",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 240,
                  fogCount: 3, beaconCharges: 1, conductorCharges: 1,
                  isQuicksandBoard: true, quicksandFadeSeconds: 3.5),
    ]
}

// =============================================================================
// MARK: - HEXAGONAL CAMPAIGN (L75–L148)
//
// Every square-grid biome (Biomes 0–8) is reproduced exactly on a flat-top
// hexagonal grid with the same mechanics, same level count, same difficulty
// scaling, and same biome intro overlays (title suffixed with ": Hex Mode").
//
// Biome ID assignment for hex campaign:
//   9  = Training Range: Hex Mode      (L75 –L80)
//   10 = Fog Marsh: Hex Mode           (L81 –L88)
//   11 = Bioluminescence: Hex Mode     (L89 –L96)
//   12 = Frozen Mirrors: Hex Mode      (L97 –L104)
//   13 = Ruins: Hex Mode               (L105–L112)
//   14 = The Underside: Hex Mode       (L113–L120)
//   15 = Coral Basin: Hex Mode         (L121–L128)
//   16 = Quicksand: Hex Mode           (L129–L136)
//   17 = The Delta: Hex Mode           (L137–L148)
//
// Global hex rule adjustments (handled by HexagonalGridGeometry — no code
// changes needed beyond setting gridShape: .hexagonal):
//   • 6-neighbor topology — signals count hex adjacencies, not square ones
//   • Safe zone on first scan = center + 6 immediate neighbors (7 tiles)
//   • Locked tiles: interior → 5 neighbours to unlock; edge → 4
//   • Sonar scans 6 directions (N/NE/SE/S/SW/NW) instead of 4
// =============================================================================

// MARK: - Biome 9: Training Range — Hex Mode (L75–L80)

extension LevelSpec {
    /// Hex mirror of Biome 0 (L1–L6). Baseline gameplay, no special mechanics.
    /// Six levels matching the square Training Range size and density progression.
    /// No biome intro overlay (mirrors the square Training Range convention).
    static let trainingRangeHex: [LevelSpec] = [
        LevelSpec(id: "L75", biomeId: 9, displayName: "Training Range: Hex Mode 1",
                  boardWidth: 6, boardHeight: 6, hazardDensity: 0.12, parTimeSeconds: 60,
                  gridShape: .hexagonal),
        LevelSpec(id: "L76", biomeId: 9, displayName: "Training Range: Hex Mode 2",
                  boardWidth: 6, boardHeight: 6, hazardDensity: 0.14, parTimeSeconds: 60,
                  gridShape: .hexagonal),
        LevelSpec(id: "L77", biomeId: 9, displayName: "Training Range: Hex Mode 3",
                  boardWidth: 7, boardHeight: 7, hazardDensity: 0.14, parTimeSeconds: 90,
                  gridShape: .hexagonal),
        LevelSpec(id: "L78", biomeId: 9, displayName: "Training Range: Hex Mode 4",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.15, parTimeSeconds: 120,
                  gridShape: .hexagonal),
        LevelSpec(id: "L79", biomeId: 9, displayName: "Training Range: Hex Mode 5",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.16, parTimeSeconds: 120,
                  gridShape: .hexagonal),
        LevelSpec(id: "L80", biomeId: 9, displayName: "Training Range: Hex Mode 6",
                  boardWidth: 8, boardHeight: 8, hazardDensity: 0.17, parTimeSeconds: 90,
                  gridShape: .hexagonal),
    ]
}

// MARK: - Biome 10: Fog Marsh — Hex Mode (L81–L88)

extension LevelSpec {
    /// Hex mirror of Biome 1 (L7–L14). Fogged tiles + beacon charges.
    /// Fog spacing, beacon count, and density match the square Fog Marsh exactly.
    static let fogMarshHex: [LevelSpec] = [
        LevelSpec(id: "L81",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 1",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 120,
                  fogCount: 2, beaconCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L82",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 2",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 120,
                  fogCount: 2, beaconCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L83",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 3",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 150,
                  fogCount: 3, beaconCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L84",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 4",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 150,
                  fogCount: 3, beaconCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L85",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 180,
                  fogCount: 4, beaconCharges: 2, gridShape: .hexagonal),
        LevelSpec(id: "L86",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 6",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.18, parTimeSeconds: 180,
                  fogCount: 4, beaconCharges: 2, gridShape: .hexagonal),
        LevelSpec(id: "L87",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  fogCount: 5, beaconCharges: 2, gridShape: .hexagonal),
        LevelSpec(id: "L88",  biomeId: 10, displayName: "Fog Marsh: Hex Mode 8",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.20, parTimeSeconds: 210,
                  fogCount: 6, beaconCharges: 2, gridShape: .hexagonal),
    ]
}

// MARK: - Biome 11: Bioluminescence — Hex Mode (L89–L96)

extension LevelSpec {
    /// Hex mirror of Biome 2 (L15–L22). One conductor charge per level.
    /// Grid resets small (6×6) and scales back up to 11×11 over 8 levels.
    static let bioluminescenceHex: [LevelSpec] = [
        LevelSpec(id: "L89",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  conductorCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L90",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  conductorCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L91",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  conductorCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L92",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  conductorCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L93",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  conductorCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L94",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 180,
                  conductorCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L95",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  conductorCharges: 1, gridShape: .hexagonal),
        LevelSpec(id: "L96",  biomeId: 11, displayName: "Bioluminescence: Hex Mode 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.20, parTimeSeconds: 240,
                  conductorCharges: 1, gridShape: .hexagonal),
    ]
}

// MARK: - Biome 12: Frozen Mirrors — Hex Mode (L97–L104)

extension LevelSpec {
    /// Hex mirror of Biome 3 (L23–L30). Linked tile pairs.
    /// Pair counts and grid sizes match the square Frozen Mirrors exactly.
    static let frozenMirrorsHex: [LevelSpec] = [
        LevelSpec(id: "L97",  biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  linkedPairCount: 1, gridShape: .hexagonal),
        LevelSpec(id: "L98",  biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  linkedPairCount: 2, gridShape: .hexagonal),
        LevelSpec(id: "L99",  biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  linkedPairCount: 2, gridShape: .hexagonal),
        LevelSpec(id: "L100", biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  linkedPairCount: 3, gridShape: .hexagonal),
        LevelSpec(id: "L101", biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  linkedPairCount: 3, gridShape: .hexagonal),
        LevelSpec(id: "L102", biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 180,
                  linkedPairCount: 4, gridShape: .hexagonal),
        LevelSpec(id: "L103", biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  linkedPairCount: 4, gridShape: .hexagonal),
        LevelSpec(id: "L104", biomeId: 12, displayName: "Frozen Mirrors: Hex Mode 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.20, parTimeSeconds: 240,
                  linkedPairCount: 5, gridShape: .hexagonal),
    ]
}

// MARK: - Biome 13: Ruins — Hex Mode (L105–L112)

extension LevelSpec {
    /// Hex mirror of Biome 4 (L31–L38). Locked tiles.
    /// On hex grids: interior threshold = 5 (of 6 neighbours), edge threshold = 4.
    /// HexagonalGridGeometry.lockThreshold() returns these values automatically.
    static let ruinsHex: [LevelSpec] = [
        LevelSpec(id: "L105", biomeId: 13, displayName: "Ruins: Hex Mode 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  lockedTileCount: 1, gridShape: .hexagonal),
        LevelSpec(id: "L106", biomeId: 13, displayName: "Ruins: Hex Mode 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  lockedTileCount: 1, gridShape: .hexagonal),
        LevelSpec(id: "L107", biomeId: 13, displayName: "Ruins: Hex Mode 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  lockedTileCount: 2, gridShape: .hexagonal),
        LevelSpec(id: "L108", biomeId: 13, displayName: "Ruins: Hex Mode 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  lockedTileCount: 2, gridShape: .hexagonal),
        LevelSpec(id: "L109", biomeId: 13, displayName: "Ruins: Hex Mode 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  lockedTileCount: 3, gridShape: .hexagonal),
        LevelSpec(id: "L110", biomeId: 13, displayName: "Ruins: Hex Mode 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 180,
                  lockedTileCount: 3, gridShape: .hexagonal),
        LevelSpec(id: "L111", biomeId: 13, displayName: "Ruins: Hex Mode 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.19, parTimeSeconds: 210,
                  lockedTileCount: 4, gridShape: .hexagonal),
        LevelSpec(id: "L112", biomeId: 13, displayName: "Ruins: Hex Mode 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.20, parTimeSeconds: 240,
                  lockedTileCount: 5, gridShape: .hexagonal),
    ]
}

// MARK: - Biome 14: The Underside — Hex Mode (L113–L120)

extension LevelSpec {
    /// Hex mirror of Biome 5 (L39–L46). Board-wide inverted signal display.
    static let theUndersideHex: [LevelSpec] = [
        LevelSpec(id: "L113", biomeId: 14, displayName: "The Underside: Hex Mode 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 90,
                  isInvertedBoard: true, gridShape: .hexagonal),
        LevelSpec(id: "L114", biomeId: 14, displayName: "The Underside: Hex Mode 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.13, parTimeSeconds: 120,
                  isInvertedBoard: true, gridShape: .hexagonal),
        LevelSpec(id: "L115", biomeId: 14, displayName: "The Underside: Hex Mode 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  isInvertedBoard: true, gridShape: .hexagonal),
        LevelSpec(id: "L116", biomeId: 14, displayName: "The Underside: Hex Mode 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.15, parTimeSeconds: 150,
                  isInvertedBoard: true, gridShape: .hexagonal),
        LevelSpec(id: "L117", biomeId: 14, displayName: "The Underside: Hex Mode 5",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  isInvertedBoard: true, gridShape: .hexagonal),
        LevelSpec(id: "L118", biomeId: 14, displayName: "The Underside: Hex Mode 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.17, parTimeSeconds: 180,
                  isInvertedBoard: true, gridShape: .hexagonal),
        LevelSpec(id: "L119", biomeId: 14, displayName: "The Underside: Hex Mode 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.18, parTimeSeconds: 210,
                  isInvertedBoard: true, gridShape: .hexagonal),
        LevelSpec(id: "L120", biomeId: 14, displayName: "The Underside: Hex Mode 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.19, parTimeSeconds: 240,
                  isInvertedBoard: true, gridShape: .hexagonal),
    ]
}

// MARK: - Biome 15: Coral Basin — Hex Mode (L121–L128)

extension LevelSpec {
    /// Hex mirror of Biome 6 (L47–L54). Sonar tiles.
    ///
    /// On hex grids sonar scans 6 beams (N/NE/SE/S/SW/NW) instead of 4.
    /// Intersection cell counts and density calibration are identical to
    /// the square version since the k*(k−1) formula still applies.
    static let coralBasinHex: [LevelSpec] = [
        // Hex intro mirrors the square fix: 3 sonars so the safe zone does not
        // collapse the board to a near-empty state.
        LevelSpec(id: "L121", biomeId: 15, displayName: "Coral Basin: Hex Mode 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.11, parTimeSeconds: 90,
                  sonarCount: 3, gridShape: .hexagonal),
        // Increase the second hex level's sonar pool for more consistent openings.
        LevelSpec(id: "L122", biomeId: 15, displayName: "Coral Basin: Hex Mode 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 120,
                  sonarCount: 4, gridShape: .hexagonal),
        LevelSpec(id: "L123", biomeId: 15, displayName: "Coral Basin: Hex Mode 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 120,
                  sonarCount: 4, gridShape: .hexagonal),
        // Keep the denser medium-board ramp in sync with the square campaign.
        LevelSpec(id: "L124", biomeId: 15, displayName: "Coral Basin: Hex Mode 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 150,
                  sonarCount: 4, gridShape: .hexagonal),
        LevelSpec(id: "L125", biomeId: 15, displayName: "Coral Basin: Hex Mode 5",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.13, parTimeSeconds: 180,
                  sonarCount: 4, gridShape: .hexagonal),
        // k=5 → 20 cells
        LevelSpec(id: "L126", biomeId: 15, displayName: "Coral Basin: Hex Mode 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.15, parTimeSeconds: 180,
                  sonarCount: 5, gridShape: .hexagonal),
        LevelSpec(id: "L127", biomeId: 15, displayName: "Coral Basin: Hex Mode 7",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.16, parTimeSeconds: 210,
                  sonarCount: 5, gridShape: .hexagonal),
        // k=6 → 30 cells
        LevelSpec(id: "L128", biomeId: 15, displayName: "Coral Basin: Hex Mode 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 240,
                  sonarCount: 6, gridShape: .hexagonal),
    ]
}

// MARK: - Biome 16: Quicksand — Hex Mode (L129–L136)

extension LevelSpec {
    /// Hex mirror of Biome 7 (L55–L62). Fading revealed numbers.
    /// Fade windows match the square Quicksand pair schedule exactly.
    static let quicksandHex: [LevelSpec] = [
        // 6 s window
        LevelSpec(id: "L129", biomeId: 16, displayName: "Quicksand: Hex Mode 1",
                  boardWidth: 6,  boardHeight: 6,  hazardDensity: 0.12, parTimeSeconds: 120,
                  isQuicksandBoard: true, quicksandFadeSeconds: 6.0, gridShape: .hexagonal),
        LevelSpec(id: "L130", biomeId: 16, displayName: "Quicksand: Hex Mode 2",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.14, parTimeSeconds: 150,
                  isQuicksandBoard: true, quicksandFadeSeconds: 6.0, gridShape: .hexagonal),
        // 5 s window
        LevelSpec(id: "L131", biomeId: 16, displayName: "Quicksand: Hex Mode 3",
                  boardWidth: 7,  boardHeight: 7,  hazardDensity: 0.15, parTimeSeconds: 150,
                  isQuicksandBoard: true, quicksandFadeSeconds: 5.0, gridShape: .hexagonal),
        LevelSpec(id: "L132", biomeId: 16, displayName: "Quicksand: Hex Mode 4",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.16, parTimeSeconds: 180,
                  isQuicksandBoard: true, quicksandFadeSeconds: 5.0, gridShape: .hexagonal),
        // 4 s window
        LevelSpec(id: "L133", biomeId: 16, displayName: "Quicksand: Hex Mode 5",
                  boardWidth: 8,  boardHeight: 8,  hazardDensity: 0.17, parTimeSeconds: 180,
                  isQuicksandBoard: true, quicksandFadeSeconds: 4.0, gridShape: .hexagonal),
        LevelSpec(id: "L134", biomeId: 16, displayName: "Quicksand: Hex Mode 6",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.18, parTimeSeconds: 210,
                  isQuicksandBoard: true, quicksandFadeSeconds: 4.0, gridShape: .hexagonal),
        // 3 s window
        LevelSpec(id: "L135", biomeId: 16, displayName: "Quicksand: Hex Mode 7",
                  boardWidth: 9,  boardHeight: 9,  hazardDensity: 0.19, parTimeSeconds: 210,
                  isQuicksandBoard: true, quicksandFadeSeconds: 3.0, gridShape: .hexagonal),
        LevelSpec(id: "L136", biomeId: 16, displayName: "Quicksand: Hex Mode 8",
                  boardWidth: 10, boardHeight: 10, hazardDensity: 0.20, parTimeSeconds: 240,
                  isQuicksandBoard: true, quicksandFadeSeconds: 3.0, gridShape: .hexagonal),
    ]
}

// MARK: - Biome 17: The Delta — Hex Mode (L137–L148)

extension LevelSpec {
    /// Hex mirror of Biome 8 (L63–L74). All mechanics on a hexagonal board.
    ///
    /// All 12 Delta Hex levels use an 11×11 hex grid.
    /// Mechanic combinations follow the same order as the square Delta:
    ///   L137  Fog + Ruins
    ///   L138  Sonar + Ruins
    ///   L139  Frozen Mirrors + The Underside
    ///   L140  Bioluminescence + Ruins
    ///   L141  Sonar + Frozen Mirrors
    ///   L142  Sonar + Frozen Mirrors + The Underside
    ///   L143  Ruins + Sonar + The Underside
    ///   L144  Bioluminescence + Quicksand
    ///   L145  The Underside + Quicksand
    ///   L146  Fog + Quicksand
    ///   L147  Fog + Quicksand + Ruins
    ///   L148  Bioluminescence + Quicksand + Fog
    static let theDeltaHex: [LevelSpec] = [

        // L137 — Fog + Ruins
        LevelSpec(id: "L137", biomeId: 17, displayName: "The Delta: Hex Mode 1",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 270,
                  fogCount: 3, beaconCharges: 1, lockedTileCount: 2,
                  gridShape: .hexagonal),

        // L138 — Sonar + Ruins
        LevelSpec(id: "L138", biomeId: 17, displayName: "The Delta: Hex Mode 2",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.08, parTimeSeconds: 270,
                  lockedTileCount: 2, sonarCount: 4,
                  gridShape: .hexagonal),

        // L139 — Frozen Mirrors + The Underside
        LevelSpec(id: "L139", biomeId: 17, displayName: "The Delta: Hex Mode 3",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 270,
                  linkedPairCount: 3, isInvertedBoard: true,
                  gridShape: .hexagonal),

        // L140 — Bioluminescence + Ruins
        LevelSpec(id: "L140", biomeId: 17, displayName: "The Delta: Hex Mode 4",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  conductorCharges: 1, lockedTileCount: 2,
                  gridShape: .hexagonal),

        // L141 — Sonar + Frozen Mirrors
        LevelSpec(id: "L141", biomeId: 17, displayName: "The Delta: Hex Mode 5",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.09, parTimeSeconds: 270,
                  linkedPairCount: 2, sonarCount: 4,
                  gridShape: .hexagonal),

        // L142 — Sonar + Frozen Mirrors + The Underside
        LevelSpec(id: "L142", biomeId: 17, displayName: "The Delta: Hex Mode 6",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.04, parTimeSeconds: 240,
                  linkedPairCount: 2, isInvertedBoard: true, sonarCount: 3,
                  gridShape: .hexagonal),

        // L143 — Ruins + Sonar + The Underside
        LevelSpec(id: "L143", biomeId: 17, displayName: "The Delta: Hex Mode 7",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.04, parTimeSeconds: 240,
                  lockedTileCount: 2, isInvertedBoard: true, sonarCount: 3,
                  gridShape: .hexagonal),

        // L144 — Bioluminescence + Quicksand
        LevelSpec(id: "L144", biomeId: 17, displayName: "The Delta: Hex Mode 8",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  conductorCharges: 1, isQuicksandBoard: true, quicksandFadeSeconds: 4.0,
                  gridShape: .hexagonal),

        // L145 — The Underside + Quicksand
        LevelSpec(id: "L145", biomeId: 17, displayName: "The Delta: Hex Mode 9",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  isInvertedBoard: true, isQuicksandBoard: true, quicksandFadeSeconds: 4.0,
                  gridShape: .hexagonal),

        // L146 — Fog + Quicksand
        LevelSpec(id: "L146", biomeId: 17, displayName: "The Delta: Hex Mode 10",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 270,
                  fogCount: 3, beaconCharges: 1, isQuicksandBoard: true, quicksandFadeSeconds: 4.0,
                  gridShape: .hexagonal),

        // L147 — Fog + Quicksand + Ruins
        LevelSpec(id: "L147", biomeId: 17, displayName: "The Delta: Hex Mode 11",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.17, parTimeSeconds: 240,
                  fogCount: 3, beaconCharges: 1, lockedTileCount: 2,
                  isQuicksandBoard: true, quicksandFadeSeconds: 4.0,
                  gridShape: .hexagonal),

        // L148 — Bioluminescence + Quicksand + Fog
        LevelSpec(id: "L148", biomeId: 17, displayName: "The Delta: Hex Mode 12",
                  boardWidth: 11, boardHeight: 11, hazardDensity: 0.18, parTimeSeconds: 240,
                  fogCount: 3, beaconCharges: 1, conductorCharges: 1,
                  isQuicksandBoard: true, quicksandFadeSeconds: 3.5,
                  gridShape: .hexagonal),
    ]
}
