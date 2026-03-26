// Signalfield/Tutorial/TutorialBoard.swift
//
// Pre-built scripted board for the L1 tutorial.
//
// This board is used ONLY on L1 when hasCompletedL1Tutorial is false.
// After tutorial completion, L1 uses normal random board generation.
//
// Board layout (6×6, 4 hazards):
//      col:  0   1   2   3   4   5
// row 0:     0   0   0   1   H   1
// row 1:     0   0   0   1   1   1
// row 2:     0   0  [0]  0   0   0   ← first scan at (2,2)
// row 3:     1   1   1   0   0   0
// row 4:     1   H   2   1   2   1
// row 5:     1   1   2   H   2   H
//
// Tutorial step reference:
//   Step 2  — first scan:    (2,2)  → triggers 26-tile cascade
//   Step 3  — zero tile:     (1,1)  → blank = no hazards nearby
//   Step 4  — signal "1":    (3,1)  → highlight 8 neighbors (2 hidden)
//   Step 5  — signal "2":    (4,2)  → highlight 8 neighbors (both hazard-adjacent)
//   Step 6  — deduction:     (3,2)  → signal 1, exactly ONE hidden neighbor = (4,1)
//   Step 7  — tag hazard:    (4,1)  → player right-clicks to tag
//   Step 8  — reveal safe:   (4,0)  → safe because (3,1) signal satisfied by (4,1) tag

import Foundation

enum TutorialBoard {

    // MARK: - Key Coordinates

    /// The tile the player must click in Step 2 to start the cascade.
    static let firstScanCoord   = Coordinate(row: 2, col: 2)

    /// Step 3 spotlight — reveals a blank (signal 0) tile from the cascade.
    static let zeroCascadeCoord = Coordinate(row: 1, col: 1)

    /// Step 4 spotlight — a "1" signal tile with two hidden neighbors (ambiguous).
    static let signalOneCoord   = Coordinate(row: 3, col: 1)

    /// Step 5 spotlight — a "2" signal tile, showing multiple hazards possible.
    static let signalTwoCoord   = Coordinate(row: 4, col: 2)

    /// Step 6 spotlight — the deduction tile: signal "1", exactly ONE hidden neighbor.
    static let deductionCoord   = Coordinate(row: 3, col: 2)

    /// Step 7 — the hazard the player deduces and tags.
    static let hazardCoord      = Coordinate(row: 4, col: 1)

    /// Step 8 — a safe tile the player reveals after the hazard is tagged.
    static let safeTileCoord    = Coordinate(row: 4, col: 0)

    // MARK: - Board Construction

    /// Returns a fully pre-populated 6×6 Board:
    ///   - All tiles hidden
    ///   - Hazards placed at (0,4), (4,1), (5,3), (5,5)
    ///   - Signals pre-computed for every safe tile
    ///   - hazardsPlaced = true so GameViewModel skips phase-2 placement
    static func makeBoard() -> Board {
        var board = Board(width: 6, height: 6, gridShape: .square)
        board.hazardsPlaced = true
        board.hazardCount   = 4

        for row in 0..<6 {
            for col in 0..<6 {
                let coord = Coordinate(row: row, col: col)
                let isHazard = hazardSet.contains(coord)
                board[coord].kind   = isHazard ? .hazard : .safe
                board[coord].signal = isHazard ? nil : signalMap[row][col]
            }
        }

        return board
    }

    // MARK: - Private Data

    /// Coordinates of all 4 hazards on the tutorial board.
    private static let hazardSet: Set<Coordinate> = [
        Coordinate(row: 0, col: 4),
        Coordinate(row: 4, col: 1),
        Coordinate(row: 5, col: 3),
        Coordinate(row: 5, col: 5)
    ]

    /// Pre-computed signal for each safe tile. nil = hazard (not applicable).
    /// Row-major [row][col], matching the board layout diagram above.
    private static let signalMap: [[Int?]] = [
        //  col: 0   1   2   3    4    5
        /*row 0*/ [0,  0,  0,  1,  nil,  1],
        /*row 1*/ [0,  0,  0,  1,    1,  1],
        /*row 2*/ [0,  0,  0,  0,    0,  0],
        /*row 3*/ [1,  1,  1,  0,    0,  0],
        /*row 4*/ [1, nil,  2,  1,    2,  1],
        /*row 5*/ [1,  1,  2, nil,    2, nil]
    ]
}
