// Signalfield/Models/Board.swift

import Foundation

/// The game board: a 2D grid of tiles plus board-level state.
struct Board: Equatable {
    let width: Int
    let height: Int
    private(set) var tiles: [Tile]  // Flat array, row-major order

    /// Total number of hazards on the board. Set after hazard placement.
    var hazardCount: Int

    /// Whether hazards have been placed yet (happens after first scan).
    var hazardsPlaced: Bool

    /// The grid topology for this board. Defaults to `.square` (classic 8-neighbor grid).
    /// Derived from `LevelSpec.gridShape` at board creation time.
    var gridShape: GridShape

    // MARK: - Grid Geometry

    /// The concrete geometry implementation for this board's grid shape.
    /// Provides topology, distance, and layout operations without branching on `gridShape`
    /// throughout the rest of the engine.
    var geometry: any GridGeometry {
        switch gridShape {
        case .square:     return SquareGridGeometry()
        case .hexagonal:  return HexagonalGridGeometry()
        }
    }

    /// All valid neighbors of `coord` on this board.
    ///
    /// Delegates to `geometry.neighbors(of:boardWidth:boardHeight:)`.
    /// Use this instead of `coord.neighbors(boardWidth:boardHeight:)` throughout the engine
    /// so that hex boards automatically get their 6-neighbor topology.
    func neighbors(of coord: Coordinate) -> [Coordinate] {
        geometry.neighbors(of: coord, boardWidth: width, boardHeight: height)
    }

    /// Sonar sight-line beams from `coord` in all primary directions.
    ///
    /// Returns one array per direction (4 for square: N/S/E/W; 6 for hex: N/NE/SE/S/SW/NW).
    /// Each inner array lists coordinates in order from the adjacent tile outward to the board edge.
    func sonarBeams(from coord: Coordinate) -> [[Coordinate]] {
        geometry.sonarBeams(from: coord, boardWidth: width, boardHeight: height)
    }

    // MARK: - Initialization

    /// Creates an empty board with all tiles in default (safe, hidden) state.
    init(width: Int, height: Int, gridShape: GridShape = .square) {
        self.width = width
        self.height = height
        self.hazardCount = 0
        self.hazardsPlaced = false
        self.gridShape = gridShape

        var grid: [Tile] = []
        grid.reserveCapacity(width * height)
        for row in 0..<height {
            for col in 0..<width {
                grid.append(Tile(coordinate: Coordinate(row: row, col: col)))
            }
        }
        self.tiles = grid
    }

    // MARK: - Tile Access

    /// Returns the flat index for a coordinate.
    private func index(for coord: Coordinate) -> Int {
        coord.row * width + coord.col
    }

    /// Returns true if the coordinate is within board bounds.
    func isValid(_ coord: Coordinate) -> Bool {
        coord.row >= 0 && coord.row < height && coord.col >= 0 && coord.col < width
    }

    /// Read access to a tile at the given coordinate.
    func tile(at coord: Coordinate) -> Tile {
        tiles[index(for: coord)]
    }

    /// Write access to a tile at the given coordinate.
    mutating func setTile(_ tile: Tile, at coord: Coordinate) {
        tiles[index(for: coord)] = tile
    }

    /// Subscript for convenient access by coordinate.
    subscript(coord: Coordinate) -> Tile {
        get { tile(at: coord) }
        set { setTile(newValue, at: coord) }
    }

    /// Subscript for access by (row, col) tuple.
    subscript(row: Int, col: Int) -> Tile {
        get { tile(at: Coordinate(row: row, col: col)) }
        set { setTile(newValue, at: Coordinate(row: row, col: col)) }
    }

    // MARK: - Queries

    /// All coordinates on the board.
    var allCoordinates: [Coordinate] {
        (0..<height).flatMap { row in
            (0..<width).map { col in Coordinate(row: row, col: col) }
        }
    }

    /// Count of tiles in a given state.
    func count(where predicate: (Tile) -> Bool) -> Int {
        tiles.filter(predicate).count
    }

    /// All safe tiles that are still hidden.
    var hiddenSafeTiles: [Tile] {
        tiles.filter { $0.kind == .safe && $0.isHidden }
    }

    /// All hazard tiles.
    var hazardTiles: [Tile] {
        tiles.filter { $0.isHazard }
    }

    /// Total number of safe tiles on the board.
    var safeTileCount: Int {
        tiles.filter { !$0.isHazard }.count
    }

    /// Number of safe tiles that have been revealed.
    var revealedSafeCount: Int {
        tiles.filter { !$0.isHazard && $0.isRevealed }.count
    }

    /// Number of hazards that have confirmed tags.
    var confirmedHazardCount: Int {
        tiles.filter { $0.isHazard && $0.hasConfirmedTag }.count
    }

    /// Number of confirmed tags placed on safe tiles (incorrect tags).
    var incorrectConfirmedTagCount: Int {
        tiles.filter { !$0.isHazard && $0.hasConfirmedTag }.count
    }
}
