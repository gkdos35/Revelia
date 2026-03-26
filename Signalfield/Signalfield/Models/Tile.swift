// Signalfield/Models/Tile.swift

import Foundation

// MARK: - Tile State

/// Whether the tile has been revealed, is still hidden, or has been exploded (hazard hit).
enum TileState: Codable, Equatable {
    case hidden
    case revealed
    case exploded  // Hazard that was scanned (game over trigger)
}

// MARK: - Tag State

/// Player-applied tag cycling: none → suspect → confirmed → none.
enum TagState: Codable, Equatable {
    case none
    case suspect    // "?" marker — reminder, doesn't count for win condition
    case confirmed  // Solid marker — counts toward hazard-tag win condition
}

// MARK: - Tile Kind

/// What the tile fundamentally IS — orthogonal to what mechanic applies.
/// Later biomes add .blocker (Biome 6: inert terrain, neither safe nor hazard).
enum TileKind: Codable, Equatable {
    case safe
    case hazard
}

// MARK: - Coordinate

/// A position on the board. Row 0 is the top row.
struct Coordinate: Hashable, Codable, Equatable {
    let row: Int
    let col: Int

    /// Returns all valid 8-neighbors within the given board dimensions.
    func neighbors(boardWidth: Int, boardHeight: Int) -> [Coordinate] {
        var result: [Coordinate] = []
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if nr >= 0 && nr < boardHeight && nc >= 0 && nc < boardWidth {
                    result.append(Coordinate(row: nr, col: nc))
                }
            }
        }
        return result
    }
}

// MARK: - Biome Mechanic Data Structs
//
// Each biome's special tile data lives in its own struct, stored as an optional
// on Tile. nil means "this mechanic doesn't apply to this tile."
//
// This scales to all 7 biomes without polluting Tile with 20 flat optionals,
// and handles confluence levels naturally (a tile can have e.g. both fogData and
// invertedData non-nil simultaneously).

/// Biome 1 — Fog Marsh: tile displays a range instead of an exact signal (fogData).
/// The range is always exactly 1 apart (e.g., "2–3"), never wider.
struct FogData: Codable, Equatable {
    /// The fogged range minimum. Always exactly signalMax - 1.
    var signalMin: Int

    /// The fogged range maximum. Always exactly signalMin + 1.
    var signalMax: Int

    /// Whether a beacon has cleared this tile's fog, revealing the exact signal.
    var isCleared: Bool
}

/// Biome 3 — Frozen Mirrors: tile displays its PARTNER's signal instead of its own.
///
/// Each linked tile references one other tile (its partner). The player sees the
/// partner's true hazard count, not the tile's own count. This is the "mirror" effect:
/// the two tiles swap signals with each other.
///
/// Key rules:
/// - `tile.signal` is ALWAYS the tile's own true hazard count — used for cascade logic.
/// - `linkedData.partnerSignal` is what gets displayed to the player.
/// - Cascade propagation uses `tile.signal` (own count), so a linked tile with own
///   signal 0 WILL cascade even if its displayed (partner) signal is non-zero.
/// - `partnerSignal` is nil until phase 2 (after hazard placement + signal computation).
struct LinkedData: Codable, Equatable {
    /// The board coordinate of this tile's linked partner.
    let partnerCoord: Coordinate

    /// 0-based index of which pair this tile belongs to (first pair = 0, second = 1 …).
    /// Used by TileView to assign a distinct per-pair color so both halves share
    /// the same tint, making the connection visually obvious after reveal.
    let pairIndex: Int

    /// The partner's true hazard count. Displayed in place of this tile's own signal.
    /// Set to nil during phase 1 (pre-first-scan); filled after `computeAllSignals`.
    var partnerSignal: Int?
}

/// Biome 5 — The Underside: tile displays the count of SAFE neighbors instead of hazardous ones.
///
/// In The Underside the entire board is inverted — every revealed tile shows how many
/// of its 8 neighbors are safe rather than dangerous. A high count means few hazards
/// nearby; a low count means many hazards nearby. This is the exact complement of
/// the normal signal.
///
/// Key rules:
/// - `tile.signal` is ALWAYS the tile's own TRUE hazard count — used for all game logic
///   including cascade. Cascade fires when `signal == 0` regardless of displayed value.
/// - `invertedData.safeNeighborCount` = total neighbors − hazard neighbors. This is what
///   the player sees after reveal.
/// - Zero-hazard tiles (signal == 0) still cascade normally. Their displayed safe count
///   (e.g. 8 for an interior tile) is non-zero, but the cascade engine uses true signal.
/// - The struct is per-tile so that confluence levels can mix inverted and normal tiles.
struct InvertedData: Codable, Equatable {
    /// Pre-computed safe-neighbor count: total neighbors − trueHazardCount.
    /// Nil during phase 1 (pre-first-scan); filled by RuleEngine Pass 4 after
    /// true signals are known.
    var safeNeighborCount: Int?
}

/// Biome 6 — Coral Basin: tile scans in all primary directions and displays
/// the TOTAL hazard count across all sight lines combined.
///
/// On square boards the four cardinal beams are N/S/E/W.
/// On hexagonal boards the six primary beams are N/NE/SE/S/SW/NW
/// (matching the 6 hex neighbor directions); the E/W fields are unused (nil).
///
/// Key rules:
/// - `tile.signal` is overwritten in RuleEngine Pass 5 to be the directional total.
///   CascadeEngine uses `signal == 0` for cascade, so a sonar with all-clear
///   sight lines cascades normally.
/// - `displayedSignal` falls through to `return signal`, which is the total.
/// - Normal (non-sonar) safe tiles on the same board use neighbor-count signals.
/// - Per-tile struct design supports future confluence levels that mix sonar
///   and other mechanic tiles without structural changes.
struct SonarData: Codable, Equatable {

    // MARK: Square grid directions (N/S/E/W)

    /// Hazard count along the N sight line (all tiles above, same column).
    var northCount: Int?
    /// Hazard count along the S sight line (all tiles below, same column).
    var southCount: Int?
    /// Hazard count along the E sight line (all tiles to the right, same row).
    /// Square grids only — nil on hexagonal boards.
    var eastCount: Int?
    /// Hazard count along the W sight line (all tiles to the left, same row).
    /// Square grids only — nil on hexagonal boards.
    var westCount: Int?

    // MARK: Additional hex grid directions (NE/SE/SW/NW)
    // These fields are nil on square boards and populated only on hexagonal boards.

    /// Hazard count along the NE beam. Hex grids only.
    var northEastCount: Int?
    /// Hazard count along the SE beam. Hex grids only.
    var southEastCount: Int?
    /// Hazard count along the SW beam. Hex grids only.
    var southWestCount: Int?
    /// Hazard count along the NW beam. Hex grids only.
    var northWestCount: Int?

    /// Sum of all directional counts for this tile's grid type.
    ///
    /// Square boards: N + S + E + W (4 beams).
    /// Hex boards:    N + NE + SE + S + SW + NW (6 beams).
    ///
    /// Nil until RuleEngine Pass 5 fills the individual counts (i.e., before
    /// hazards are placed and signals are computed).
    var totalCount: Int? {
        if northEastCount != nil {
            // Hex board: use all 6 directional fields
            guard let n  = northCount,     let ne = northEastCount,
                  let se = southEastCount, let s  = southCount,
                  let sw = southWestCount, let nw = northWestCount else { return nil }
            return n + ne + se + s + sw + nw
        }
        // Square board: use 4 cardinal fields
        guard let n = northCount, let s = southCount,
              let e = eastCount,  let w = westCount else { return nil }
        return n + s + e + w
    }
}

/// Biome 4 — Ruins: tile is locked and will not reveal until enough of its surrounding
/// neighbors have been uncovered by the player.
///
/// Locked tiles are ALWAYS safe — they are never hazards. The player knows a locked
/// tile is safe, but can't read its signal until it unlocks.
///
/// Key rules:
/// - `tile.signal` is the tile's true hazard count (set by RuleEngine Pass 1).
///   Displayed normally after unlock, just like any other revealed tile.
/// - Cascade STOPS at locked tiles. They cannot be revealed by BFS — only by the
///   unlock mechanic (enough neighbors revealed).
/// - A locked tile that unlocks with `signal == 0` triggers a cascade normally
///   from its position, spreading outward from the newly unlocked tile.
/// - Never in corners (corners have only 3 neighbors, making them too easy/hard to unlock).
/// - Placement: interior tiles (8 neighbors) need 6 revealed; edge tiles (5 neighbors)
///   need 4 revealed.
struct LockedData: Codable, Equatable {
    /// Number of neighbors that must be revealed to unlock this tile.
    /// Set at placement time: 6 for interior tiles (8 neighbors),
    /// 4 for edge tiles (5 neighbors). Immutable after placement.
    let unlockThreshold: Int

    /// How many more neighbor reveals are needed before this tile unlocks.
    /// Starts equal to `unlockThreshold` and decrements as neighbors are revealed.
    /// When it reaches 0, the tile unlocks and is revealed automatically.
    var remainingNeighborsNeeded: Int
}

// Future biome data structs will be added here as we build each biome:
// - Biome 2 (Bioluminescence): No per-tile struct needed. Illumination is a
//   transient board state in GameViewModel (a Set<Coordinate> of illuminated tiles).
// - Biome 7 (Quicksand): No per-tile struct needed. The fading mechanic is purely
//   visual and driven by GameViewModel.quicksandFadeProgress (a single Double for
//   the whole board). LevelSpec.isQuicksandBoard / quicksandFadeSeconds carry the
//   level parameters; TileView reads the progress value to compute opacity and tint.

// MARK: - Tile

/// A single tile on the game board.
struct Tile: Codable, Equatable {
    let coordinate: Coordinate
    var kind: TileKind
    var state: TileState
    var tagState: TagState

    /// The TRUE hazard count in the 8-neighborhood. Set after hazard placement.
    /// nil means clue hasn't been computed yet (board is in pre-game state).
    /// For fogged tiles, this is the exact value (used internally by cascade);
    /// the player sees fogData.signalMin–fogData.signalMax until fog is cleared.
    var signal: Int?

    /// Whether this tile is part of the 3×3 first-scan safe zone.
    var isFirstScanProtected: Bool

    // MARK: - Biome Mechanic Data (one optional per biome)

    /// Biome 1: Fog data. Non-nil if this tile is in a fog zone.
    var fogData: FogData?

    /// Biome 3: Linked data. Non-nil if this tile is one half of a mirrored pair.
    var linkedData: LinkedData?

    /// Biome 5: Inverted data. Non-nil if this tile shows safe neighbor count instead of hazard count.
    var invertedData: InvertedData?

    /// Biome 6: Sonar data. Non-nil if this tile scans cardinal directions.
    var sonarData: SonarData?

    /// Biome 4: Locked data. Non-nil if this tile is locked and awaiting neighbor reveals.
    /// Always nil on hazard tiles (locked tiles can never be hazards).
    var lockedData: LockedData?

    // Future biomes (will be added as we build each biome):
    // Biome 2 (Bioluminescence): No per-tile struct — illumination is transient state in GameViewModel.
    // Biome 7 (Quicksand): No per-tile struct — board-level flag in LevelSpec.

    init(coordinate: Coordinate) {
        self.coordinate = coordinate
        self.kind = .safe
        self.state = .hidden
        self.tagState = .none
        self.signal = nil
        self.isFirstScanProtected = false
        self.fogData = nil
        self.linkedData = nil
        self.invertedData = nil
        self.sonarData = nil
        self.lockedData = nil
    }

    // MARK: - Computed Properties

    /// True if the tile is safe and has been revealed.
    var isRevealed: Bool { state == .revealed }

    /// True if the tile is still hidden (not revealed, not exploded).
    var isHidden: Bool { state == .hidden }

    /// True if the tile has a confirmed tag (counts toward win condition).
    var hasConfirmedTag: Bool { tagState == .confirmed }

    /// True if this tile is a hazard.
    var isHazard: Bool { kind == .hazard }

    /// True if this tile is in a fog zone (regardless of whether fog has been cleared).
    var isFogged: Bool { fogData != nil }

    /// True if this tile is fogged AND the fog hasn't been cleared yet.
    var hasFog: Bool { fogData != nil && fogData?.isCleared == false }

    /// True if this tile is one half of a linked (mirrored) pair.
    var isLinked: Bool { linkedData != nil }

    /// True if this tile is in an inverted biome (shows safe neighbor count instead of hazard count).
    var isInverted: Bool { invertedData != nil }

    /// True if this tile is a sonar (scans cardinal directions instead of 8-neighbors).
    var isSonar: Bool { sonarData != nil }

    /// True if this tile is currently locked (Biome 4: Ruins).
    /// Locked tiles are always safe but won't reveal until enough neighbors are uncovered.
    var isLocked: Bool { lockedData != nil }

    /// The signal to display to the player. Applies biome mechanics in priority order:
    /// 1. Linked (Biome 2): show the partner tile's true hazard count.
    /// 2. Inverted (Biome 3): show safe neighbor count (computed in RuleEngine Pass 4).
    /// 3. Sonar (Biome 4): `signal` is already the N+S+E+W total (set by Pass 5),
    ///    so the default return handles it correctly — no special branch needed.
    /// 4. Default: show own true hazard count unchanged.
    ///
    /// `tile.signal` (the raw true hazard count, or the sonar directional total) is
    /// ALWAYS used for cascade logic — display mechanics never affect engine decisions.
    var displayedSignal: Int? {
        if let linked = linkedData {
            return linked.partnerSignal
        }
        if let inverted = invertedData {
            return inverted.safeNeighborCount  // nil until Phase 2 computes it
        }
        return signal  // Also correct for sonar tiles (signal = N+S+E+W after Pass 5)
    }

}
