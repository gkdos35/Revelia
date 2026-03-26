// Signalfield/Models/GridGeometry.swift

import CoreGraphics
import Foundation

// MARK: - Grid Shape

/// The shape of the board's tile grid.
///
/// Controls how neighbors are computed, how far signals propagate,
/// and how tiles are positioned and rendered.
enum GridShape: String, Codable, Equatable {
    /// Classic square grid — each interior tile has 8 diagonal + orthogonal neighbors.
    case square

    /// Flat-top hexagonal grid — each interior tile has 6 neighbors (N, NE, SE, S, SW, NW).
    /// Uses odd-q offset coordinates: odd columns are shifted down by half a hex height.
    case hexagonal
}

// MARK: - Grid Geometry Protocol

/// Abstracts all topology-dependent operations so the engine and view layer can
/// handle square and hexagonal boards without branching on grid shape everywhere.
///
/// Two concrete implementations are provided:
///   - `SquareGridGeometry`: the classic 8-neighbor square grid.
///   - `HexagonalGridGeometry`: flat-top hex grid with odd-q offset.
///
/// **Usage pattern:** Call `board.neighbors(of:)` and `board.sonarBeams(from:)` rather
/// than accessing the geometry directly; `Board` exposes these as convenience methods.
/// For placement logic (distances, corner/edge classification, lock thresholds),
/// access `board.geometry` directly in BoardGenerator.
protocol GridGeometry {

    // MARK: — Topology

    /// All valid neighbors of `coord` within the given board dimensions.
    func neighbors(of coord: Coordinate, boardWidth: Int, boardHeight: Int) -> [Coordinate]

    /// Sonar sight-line beams from `coord` in all primary directions.
    ///
    /// Returns one array per direction (4 for square: N/S/E/W; 6 for hex: N/NE/SE/S/SW/NW).
    /// Each inner array lists coordinates in order from the tile adjacent to `coord`
    /// outward to the board edge (empty if the edge is immediately adjacent).
    func sonarBeams(from coord: Coordinate, boardWidth: Int, boardHeight: Int) -> [[Coordinate]]

    /// Topological distance between two coordinates.
    /// Chebyshev (king-move) for square; hex distance (cube-coordinate max) for hexagonal.
    func distance(from a: Coordinate, to b: Coordinate) -> Int

    /// True if `coord` is a corner tile (minimum possible neighbor count on a finite board).
    func isCorner(_ coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Bool

    /// True if `coord` sits on the board's outer boundary
    /// (includes both corner and non-corner edge tiles; excludes interior tiles).
    func isOnBoardEdge(_ coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Bool

    /// The neighbor-reveal unlock threshold for a locked tile at `coord`.
    /// For square: interior → 6 (need 6 of 8 revealed); edge → 4 (need 4 of 5 revealed).
    func lockThreshold(at coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Int

    // MARK: — Layout (view layer)

    /// Pixel position of the top-left corner of the tile at `coord` in Canvas space.
    /// `tileSize` is the primary size measure (circumradius for hex, side length for square).
    /// `spacing` is the gap in points between adjacent tiles.
    func tileOrigin(at coord: Coordinate, tileSize: CGFloat, spacing: CGFloat) -> CGPoint

    /// Total pixel size of the board canvas (all tiles plus inter-tile spacing).
    func boardCanvasSize(boardWidth: Int, boardHeight: Int, tileSize: CGFloat, spacing: CGFloat) -> CGSize

    /// Board coordinate for a point in Canvas space; nil if the point is outside the board.
    func coordinate(at point: CGPoint, boardWidth: Int, boardHeight: Int, tileSize: CGFloat, spacing: CGFloat) -> Coordinate?

    /// The rendered pixel width of one tile (equals `tileSize` for square; 2×tileSize for hex).
    func tileWidth(_ tileSize: CGFloat) -> CGFloat

    /// The rendered pixel height of one tile (equals `tileSize` for square; √3×tileSize for hex).
    func tileHeight(_ tileSize: CGFloat) -> CGFloat
}

// MARK: — Default extension

extension GridGeometry {
    /// True if `coord` is an interior tile (not on any board boundary).
    func isInterior(_ coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Bool {
        !isOnBoardEdge(coord, boardWidth: boardWidth, boardHeight: boardHeight)
    }
}

// MARK: - Square Grid Geometry

/// Classic 8-neighbor square grid.
///
/// - Neighbor count: up to 8 (corners have 3, edges have 5, interior have 8).
/// - Distance: Chebyshev (king-move), max(|Δrow|, |Δcol|).
/// - Sonar: 4 cardinal beams (N, S, E, W).
/// - Tile size: square, width == height == tileSize.
struct SquareGridGeometry: GridGeometry {

    // MARK: Topology

    func neighbors(of coord: Coordinate, boardWidth: Int, boardHeight: Int) -> [Coordinate] {
        var result: [Coordinate] = []
        for dr in -1...1 {
            for dc in -1...1 {
                guard !(dr == 0 && dc == 0) else { continue }
                let nr = coord.row + dr
                let nc = coord.col + dc
                guard nr >= 0, nr < boardHeight, nc >= 0, nc < boardWidth else { continue }
                result.append(Coordinate(row: nr, col: nc))
            }
        }
        return result
    }

    func sonarBeams(from coord: Coordinate, boardWidth: Int, boardHeight: Int) -> [[Coordinate]] {
        // N, S, E, W — 4 cardinal directions
        let directions: [(dRow: Int, dCol: Int)] = [(-1, 0), (1, 0), (0, 1), (0, -1)]
        return directions.map { dir in
            var beam: [Coordinate] = []
            var r = coord.row + dir.dRow
            var c = coord.col + dir.dCol
            while r >= 0 && r < boardHeight && c >= 0 && c < boardWidth {
                beam.append(Coordinate(row: r, col: c))
                r += dir.dRow
                c += dir.dCol
            }
            return beam
        }
    }

    func distance(from a: Coordinate, to b: Coordinate) -> Int {
        max(abs(a.row - b.row), abs(a.col - b.col))  // Chebyshev
    }

    func isCorner(_ coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Bool {
        let rowEdge = coord.row == 0 || coord.row == boardHeight - 1
        let colEdge = coord.col == 0 || coord.col == boardWidth  - 1
        return rowEdge && colEdge
    }

    func isOnBoardEdge(_ coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Bool {
        coord.row == 0 || coord.row == boardHeight - 1 ||
        coord.col == 0 || coord.col == boardWidth  - 1
    }

    func lockThreshold(at coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Int {
        // Interior tiles have 8 neighbors → require 6 revealed to unlock.
        // Edge tiles (non-corner) have 5 neighbors → require 4 revealed.
        isOnBoardEdge(coord, boardWidth: boardWidth, boardHeight: boardHeight) ? 4 : 6
    }

    // MARK: Layout

    func tileOrigin(at coord: Coordinate, tileSize: CGFloat, spacing: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(coord.col) * (tileSize + spacing),
            y: CGFloat(coord.row) * (tileSize + spacing)
        )
    }

    func boardCanvasSize(boardWidth: Int, boardHeight: Int, tileSize: CGFloat, spacing: CGFloat) -> CGSize {
        CGSize(
            width:  CGFloat(boardWidth)  * (tileSize + spacing) - spacing,
            height: CGFloat(boardHeight) * (tileSize + spacing) - spacing
        )
    }

    func coordinate(at point: CGPoint, boardWidth: Int, boardHeight: Int, tileSize: CGFloat, spacing: CGFloat) -> Coordinate? {
        let col = Int(point.x / (tileSize + spacing))
        let row = Int(point.y / (tileSize + spacing))
        guard row >= 0, row < boardHeight, col >= 0, col < boardWidth else { return nil }
        return Coordinate(row: row, col: col)
    }

    func tileWidth(_ tileSize: CGFloat)  -> CGFloat { tileSize }
    func tileHeight(_ tileSize: CGFloat) -> CGFloat { tileSize }
}

// MARK: - Hexagonal Grid Geometry

/// Flat-top hexagonal grid with odd-q offset (odd columns shifted DOWN by half a hex height).
///
/// **Coordinate system:**
/// - `coord.col` = q (column index), `coord.row` = r (row index).
/// - Even columns (col % 2 == 0) have tile centers at the baseline row positions.
/// - Odd columns  (col % 2 == 1) have tile centers shifted down by half a hex height.
///
/// **Neighbor table (6 neighbors per interior tile):**
/// ```
/// Even column (col % 2 == 0):
///   N  (row−1, col  )   NE (row−1, col+1)   SE (row,   col+1)
///   S  (row+1, col  )   SW (row,   col−1)   NW (row−1, col−1)
///
/// Odd column (col % 2 == 1):
///   N  (row−1, col  )   NE (row,   col+1)   SE (row+1, col+1)
///   S  (row+1, col  )   SW (row+1, col−1)   NW (row,   col−1)
/// ```
///
/// **Sonar:** 6 directional beams (N, NE, SE, S, SW, NW) walking to the board edge.
/// Walking is performed by repeatedly applying the column-aware step offsets above,
/// so the beam path correctly accounts for column-parity shifts at each step.
///
/// **Tile size:** `tileSize` = circumradius (center to vertex).
/// Rendered size: width = 2×tileSize, height = √3×tileSize.
struct HexagonalGridGeometry: GridGeometry {

    // MARK: Topology

    func neighbors(of coord: Coordinate, boardWidth: Int, boardHeight: Int) -> [Coordinate] {
        let offsets = neighborOffsets(forCol: coord.col)
        return offsets.compactMap { (dr, dc) in
            let nr = coord.row + dr
            let nc = coord.col + dc
            guard nr >= 0, nr < boardHeight, nc >= 0, nc < boardWidth else { return nil }
            return Coordinate(row: nr, col: nc)
        }
    }

    func sonarBeams(from coord: Coordinate, boardWidth: Int, boardHeight: Int) -> [[Coordinate]] {
        // Walk in each of the 6 hex directions.
        // Direction indices: 0=N, 1=NE, 2=SE, 3=S, 4=SW, 5=NW.
        return (0..<6).map { dirIndex in
            var beam: [Coordinate] = []
            var current = coord
            while true {
                let offsets = neighborOffsets(forCol: current.col)
                let (dr, dc) = offsets[dirIndex]
                let nr = current.row + dr
                let nc = current.col + dc
                guard nr >= 0, nr < boardHeight, nc >= 0, nc < boardWidth else { break }
                current = Coordinate(row: nr, col: nc)
                beam.append(current)
            }
            return beam
        }
    }

    func distance(from a: Coordinate, to b: Coordinate) -> Int {
        // Convert offset coords to cube coords, then use hex distance formula.
        let (aq, ar, as_) = offsetToCube(col: a.col, row: a.row)
        let (bq, br, bs)  = offsetToCube(col: b.col, row: b.row)
        return max(abs(aq - bq), abs(ar - br), abs(as_ - bs))
    }

    func isCorner(_ coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Bool {
        let rowEdge = coord.row == 0 || coord.row == boardHeight - 1
        let colEdge = coord.col == 0 || coord.col == boardWidth  - 1
        return rowEdge && colEdge
    }

    func isOnBoardEdge(_ coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Bool {
        coord.row == 0 || coord.row == boardHeight - 1 ||
        coord.col == 0 || coord.col == boardWidth  - 1
    }

    func lockThreshold(at coord: Coordinate, boardWidth: Int, boardHeight: Int) -> Int {
        // Interior hex tiles have 6 neighbors → require 5 revealed to unlock.
        // Edge tiles have fewer neighbors → require 4.
        let nCount = neighbors(of: coord, boardWidth: boardWidth, boardHeight: boardHeight).count
        return nCount == 6 ? 5 : 4
    }

    // MARK: Layout
    //
    // For flat-top hex, `tileSize` is the circumradius (center-to-vertex distance R).
    //   Hex tip-to-tip width  = 2 × R       (tileSize * 2.0)
    //   Hex flat-to-flat height = √3 × R    (tileSize * √3 ≈ tileSize * 1.7320508)
    //   Column step (center-to-center) = 1.5 × R
    //   Row step   (center-to-center, within column) = √3 × R
    //   Odd-column downward shift = (√3 / 2) × R

    private let sqrt3: CGFloat = 1.7320508075688772

    func tileOrigin(at coord: Coordinate, tileSize: CGFloat, spacing: CGFloat) -> CGPoint {
        let hexH      = tileSize * sqrt3           // flat-to-flat height = √3·R
        let colStep   = tileSize * 1.5 + spacing   // horizontal center-to-center
        let rowStep   = hexH + spacing             // vertical center-to-center
        let oddOffset = hexH * 0.5 + spacing * 0.5 // downward shift for odd columns
        let x = CGFloat(coord.col) * colStep
        let y = CGFloat(coord.row) * rowStep + (coord.col % 2 == 1 ? oddOffset : 0)
        return CGPoint(x: x, y: y)
    }

    func boardCanvasSize(boardWidth: Int, boardHeight: Int, tileSize: CGFloat, spacing: CGFloat) -> CGSize {
        let hexH      = tileSize * sqrt3
        let colStep   = tileSize * 1.5 + spacing
        let rowStep   = hexH + spacing
        let oddOffset = hexH * 0.5 + spacing * 0.5
        // Width: each column contributes a 1.5·R horizontal step; last column adds 0.5·R for its right tip.
        let w = CGFloat(boardWidth) * colStep + tileSize * 0.5
        // Height: rows contribute rowStep each minus one trailing spacing;
        //         add odd-column downward shift if there are multiple columns.
        let h = CGFloat(boardHeight) * rowStep - spacing
                + (boardWidth > 1 ? oddOffset : 0)
        return CGSize(width: w, height: h)
    }

    func coordinate(at point: CGPoint, boardWidth: Int, boardHeight: Int, tileSize: CGFloat, spacing: CGFloat) -> Coordinate? {
        let hexH      = tileSize * sqrt3
        let colStep   = tileSize * 1.5 + spacing
        let rowStep   = hexH + spacing
        let oddOffset = hexH * 0.5 + spacing * 0.5
        // Estimate the column from x, then scan a ±1 column band and all plausible
        // rows within each column, returning the hex whose center is closest to point.
        let approxCol = Int(point.x / colStep)
        var bestCoord: Coordinate?
        var bestDistSq = CGFloat.infinity
        for dc in -1...2 {
            let c = approxCol + dc
            guard c >= 0, c < boardWidth else { continue }
            let yOffset = (c % 2 == 1) ? oddOffset : 0
            let approxRow = Int((point.y - yOffset) / rowStep)
            for dr in -1...2 {
                let r = approxRow + dr
                guard r >= 0, r < boardHeight else { continue }
                let origin = tileOrigin(at: Coordinate(row: r, col: c), tileSize: tileSize, spacing: spacing)
                // Center of this hex tile
                let cx = origin.x + tileSize          // tileWidth/2 = tileSize (since tileWidth=2*tileSize)
                let cy = origin.y + hexH * 0.5
                let dx = point.x - cx
                let dy = point.y - cy
                let distSq = dx * dx + dy * dy
                if distSq < bestDistSq {
                    bestDistSq = distSq
                    bestCoord  = Coordinate(row: r, col: c)
                }
            }
        }
        return bestCoord
    }

    func tileWidth(_ tileSize: CGFloat)  -> CGFloat { tileSize * 2.0 }
    func tileHeight(_ tileSize: CGFloat) -> CGFloat { tileSize * sqrt3 }

    // MARK: Private helpers

    /// The 6 neighbor offsets for a tile in the given column.
    ///
    /// Order: [N, NE, SE, S, SW, NW] (indices 0–5 match the sonar beam direction indices).
    private func neighborOffsets(forCol col: Int) -> [(dRow: Int, dCol: Int)] {
        if col % 2 == 0 {
            // Even column (baseline position)
            return [(-1,  0), (-1,  1), ( 0,  1),   // N, NE, SE
                    ( 1,  0), ( 0, -1), (-1, -1)]    // S, SW, NW
        } else {
            // Odd column (shifted down by half a hex height)
            return [(-1,  0), ( 0,  1), ( 1,  1),   // N, NE, SE
                    ( 1,  0), ( 1, -1), ( 0, -1)]    // S, SW, NW
        }
    }

    /// Convert offset coordinates (col=q, row=r) to cube coordinates (q, r, s)
    /// for hex distance calculation. Uses odd-q convention (odd columns shifted down).
    private func offsetToCube(col: Int, row: Int) -> (q: Int, r: Int, s: Int) {
        let q = col
        let r = row - (col - (col & 1)) / 2
        let s = -q - r
        return (q, r, s)
    }
}
