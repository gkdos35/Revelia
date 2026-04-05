// Revelia/Models/TileExplosionData.swift
//
// Lightweight snapshot of a single tile's visual state at the moment of explosion.
// GameView builds an array of these from the revealed board and passes them to
// BoardExplosionScene so the SpriteKit overlay can recreate each tile as a sprite.

import AppKit   // NSColor

/// One tile's data for the explosion animation.
struct TileExplosionData {

    /// Board coordinate (used only for identification; positions are pre-computed).
    let coord: Coordinate

    /// Centre position of the tile relative to the board canvas origin (top-left).
    /// In SwiftUI's coordinate system (Y increases downward).
    let center: CGPoint

    /// Rendered size of this tile (width × height).
    /// Square tiles: tileSize × tileSize. Hex tiles: tileSize*2 × tileSize*√3.
    let size: CGSize

    /// Dominant fill colour for the tile in its revealed state.
    /// Hazard tiles → amber #C0603A. Safe tiles → biome's revealedOverlayColor.
    let fillColor: NSColor

    /// True if this tile is the hazard the player clicked (the explosion epicentre).
    let isExplosionOrigin: Bool

    /// BFS ring distance from the explosion origin.
    /// 0 = the origin tile, 1 = its immediate neighbours, etc.
    let ringDistance: Int
}
