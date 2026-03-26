// Signalfield/Models/BiomeTheme.swift

import SwiftUI

/// Visual palette for a single biome.
///
/// `BiomeTheme` drives all tile-level colour decisions in `TileView`:
/// hidden tile texture, signal glyph colour, flag accent, and the
/// semi-transparent overlay colour used for revealed tiles.
///
/// Usage:
/// ```swift
/// let theme = BiomeTheme.theme(for: levelSpec.biomeId)
/// ```
struct BiomeTheme {

    // MARK: - Properties

    /// Asset-catalog name for the watercolour texture image shown on hidden tiles.
    /// Used as `Image(theme.tileTextureName)` — must match an imageset in
    /// `Assets.xcassets` exactly (case-sensitive on macOS).
    let tileTextureName: String

    /// Colour used for signal glyphs/numbers on revealed tiles, the linked-pair
    /// dot indicator on hidden tiles, and the fogged-tile dashed border.
    ///
    /// Stored **opaque** (no alpha); opacity is applied at render time so the
    /// same value can serve multiple roles at different intensities.
    let signalColor: Color

    /// Colour used for the flag diamond symbol (◆), the flagged-tile solid
    /// border (1.5 pt), and the soft outer glow layered behind that border.
    /// Chosen to be complementary to the biome's tile texture palette so the
    /// flag reads clearly against any tile background.
    let flagAccentColor: Color

    /// Base tint used for revealed-tile overlay fills.
    ///
    /// Stored **opaque** (no alpha).  TileView applies:
    ///   - 0.75 opacity  for normal revealed tiles (signal > 0 or special mechanic)
    ///   - 0.60 opacity  for zero-signal ("blank") revealed tiles so they recede
    ///
    /// This lets approximately 25 % (normal) or 40 % (blank) of the biome
    /// background image bleed through the tile, creating a "cracked open to
    /// see the world beneath" appearance.
    let revealedOverlayColor: Color

    /// Accent colour used for biome pins on the continent map (BiomeSelectView).
    /// Each biome has a distinct colour so pins are quickly distinguishable.
    /// Hex biomes reuse the same pin colour as their square counterpart.
    let pinColor: Color

    /// Background fill colour for the Play button on the level-select info card.
    /// Chosen to evoke each biome's environment — earthy, naturalistic tones.
    let playButtonColor: Color

    // MARK: - Lookup

    /// Returns the `BiomeTheme` for a given biome ID.
    ///
    /// Hex biomes (9–17) reuse the same palette as their square counterparts
    /// (0–8) via `biomeId % 9`, mirroring the `gameplayImageName` mapping on
    /// `LevelSpec` and the `imageName(for:)` mapping in `BiomeLevelLayout`.
    static func theme(for biomeId: Int) -> BiomeTheme {
        switch biomeId % 9 {
        case 0:  return .trainingRange
        case 1:  return .fogMarsh
        case 2:  return .bioluminescence
        case 3:  return .frozenMirrors
        case 4:  return .ruins
        case 5:  return .theUnderside
        case 6:  return .coralBasin
        case 7:  return .quicksand
        default: return .theDelta
        }
    }
}

// MARK: - Per-Biome Palettes

extension BiomeTheme {

    // MARK: Biome 0 — Training Range
    // Material: mossy meadow stone
    // Signal: soft lime green  #c2e090
    // Flag:   rose pink        #e05888  (complementary to green tile)
    // Pin:    meadow green     #7ab648
    // Overlay base:            rgb(30, 50, 20)

    static let trainingRange = BiomeTheme(
        tileTextureName:     "TrainingRangeTile",
        signalColor:         Color(red: 0xC2/255, green: 0xE0/255, blue: 0x90/255),
        flagAccentColor:     Color(red: 0xE0/255, green: 0x58/255, blue: 0x88/255),
        revealedOverlayColor: Color(red: 30/255,  green: 50/255,  blue: 20/255),
        pinColor:            Color(red: 0x7A/255, green: 0xB6/255, blue: 0x48/255),
        playButtonColor:     Color(red: 0x7A/255, green: 0xAA/255, blue: 0x58/255)  // meadow green
    )

    // MARK: Biome 1 — Fog Marsh
    // Material: wet mossy swamp stone
    // Signal: seafoam teal     #80d4b4
    // Flag:   warm orange      #e07848  (complementary to teal tile)
    // Pin:    mist teal        #4a9e8a
    // Overlay base:            rgb(20, 40, 34)

    static let fogMarsh = BiomeTheme(
        tileTextureName:     "FogMarshTile",
        signalColor:         Color(red: 0x80/255, green: 0xD4/255, blue: 0xB4/255),
        flagAccentColor:     Color(red: 0xE0/255, green: 0x78/255, blue: 0x48/255),
        revealedOverlayColor: Color(red: 20/255,  green: 40/255,  blue: 34/255),
        pinColor:            Color(red: 0x4A/255, green: 0x9E/255, blue: 0x8A/255),
        playButtonColor:     Color(red: 0x4A/255, green: 0x78/255, blue: 0x68/255)  // teal
    )

    // MARK: Biome 2 — Bioluminescence
    // Material: dark forest mushroom cap / seed pod
    // Signal: electric cyan    #70e0e0
    // Flag:   golden amber     #e0a030  (complementary to dark cyan tile)
    // Pin:    deep forest cyan #3a6e8a
    // Overlay base:            rgb(15, 20, 35)

    static let bioluminescence = BiomeTheme(
        tileTextureName:     "BioluminescenceTile",
        signalColor:         Color(red: 0x70/255, green: 0xE0/255, blue: 0xE0/255),
        flagAccentColor:     Color(red: 0xE0/255, green: 0xA0/255, blue: 0x30/255),
        revealedOverlayColor: Color(red: 15/255,  green: 20/255,  blue: 35/255),
        pinColor:            Color(red: 0x3A/255, green: 0x6E/255, blue: 0x8A/255),
        playButtonColor:     Color(red: 0x3A/255, green: 0x4A/255, blue: 0x70/255)  // deep indigo
    )

    // MARK: Biome 3 — Frozen Mirrors
    // Material: polished glacier ice
    // Signal: pale ice blue    #a8daf0
    // Flag:   terracotta       #e08860  (complementary to cold blue tile)
    // Pin:    glacier blue     #8ab8d8
    // Overlay base:            rgb(30, 45, 60)

    static let frozenMirrors = BiomeTheme(
        tileTextureName:     "FrozenMirrorsTile",
        signalColor:         Color(red: 0xA8/255, green: 0xDA/255, blue: 0xF0/255),
        flagAccentColor:     Color(red: 0xE0/255, green: 0x88/255, blue: 0x60/255),
        revealedOverlayColor: Color(red: 30/255,  green: 45/255,  blue: 60/255),
        pinColor:            Color(red: 0x8A/255, green: 0xB8/255, blue: 0xD8/255),
        playButtonColor:     Color(red: 0x88/255, green: 0xB8/255, blue: 0xD4/255)  // ice blue
    )

    // MARK: Biome 4 — Ruins
    // Material: weathered carved sandstone
    // Signal: warm gold        #e8c880
    // Flag:   slate blue       #7070d0  (complementary to warm sandy tile)
    // Pin:    ancient gold     #c8a050
    // Overlay base:            rgb(40, 30, 20)

    static let ruins = BiomeTheme(
        tileTextureName:     "RuinsTile",
        signalColor:         Color(red: 0xE8/255, green: 0xC8/255, blue: 0x80/255),
        flagAccentColor:     Color(red: 0x70/255, green: 0x70/255, blue: 0xD0/255),
        revealedOverlayColor: Color(red: 40/255,  green: 30/255,  blue: 20/255),
        pinColor:            Color(red: 0xC8/255, green: 0xA0/255, blue: 0x50/255),
        playButtonColor:     Color(red: 0xC4/255, green: 0xA0/255, blue: 0x60/255)  // sandstone gold
    )

    // MARK: Biome 5 — The Underside
    // Material: smooth cave stone with mineral veins
    // Signal: soft purple      #c0a0e0
    // Flag:   acid lime        #b8c840  (complementary to purple tile)
    // Pin:    cave purple      #7858a0
    // Overlay base:            rgb(25, 20, 30)

    static let theUnderside = BiomeTheme(
        tileTextureName:     "TheUndersideTile",
        signalColor:         Color(red: 0xC0/255, green: 0xA0/255, blue: 0xE0/255),
        flagAccentColor:     Color(red: 0xB8/255, green: 0xC8/255, blue: 0x40/255),
        revealedOverlayColor: Color(red: 25/255,  green: 20/255,  blue: 30/255),
        pinColor:            Color(red: 0x78/255, green: 0x58/255, blue: 0xA0/255),
        playButtonColor:     Color(red: 0x6A/255, green: 0x50/255, blue: 0x80/255)  // cave purple
    )

    // MARK: Biome 6 — Coral Basin
    // Material: living coral / sea-tumbled shell
    // Signal: warm coral pink  #f0a8a0
    // Flag:   tropical teal    #40b8b0  (complementary to warm coral tile)
    // Pin:    reef coral       #d87060
    // Overlay base:            rgb(20, 30, 45)

    static let coralBasin = BiomeTheme(
        tileTextureName:     "CoralBasinTile",
        signalColor:         Color(red: 0xF0/255, green: 0xA8/255, blue: 0xA0/255),
        flagAccentColor:     Color(red: 0x40/255, green: 0xB8/255, blue: 0xB0/255),
        revealedOverlayColor: Color(red: 20/255,  green: 30/255,  blue: 45/255),
        pinColor:            Color(red: 0xD8/255, green: 0x70/255, blue: 0x60/255),
        playButtonColor:     Color(red: 0xD0/255, green: 0x88/255, blue: 0x78/255)  // coral pink
    )

    // MARK: Biome 7 — Quicksand
    // Material: crusted dried mud over wet sand
    // Signal: dusty gold       #e8c070
    // Flag:   sky blue         #5090d0  (complementary to warm amber tile)
    // Pin:    desert amber     #c88030
    // Overlay base:            rgb(40, 30, 18)

    static let quicksand = BiomeTheme(
        tileTextureName:     "QuicksandTile",
        signalColor:         Color(red: 0xE8/255, green: 0xC0/255, blue: 0x70/255),
        flagAccentColor:     Color(red: 0x50/255, green: 0x90/255, blue: 0xD0/255),
        revealedOverlayColor: Color(red: 40/255,  green: 30/255,  blue: 18/255),
        pinColor:            Color(red: 0xC8/255, green: 0x80/255, blue: 0x30/255),
        playButtonColor:     Color(red: 0xC0/255, green: 0x96/255, blue: 0x3A/255)  // amber
    )

    // MARK: Biome 8 — The Delta
    // Material: multi-environment river stone
    // Signal: warm neutral     #d0c8b0
    // Flag:   cool blue        #60a0d8  (complementary to warm neutral tile)
    // Pin:    river slate      #4888a0
    // Overlay base:            rgb(30, 28, 22)

    static let theDelta = BiomeTheme(
        tileTextureName:     "TheDeltaTile",
        signalColor:         Color(red: 0xD0/255, green: 0xC8/255, blue: 0xB0/255),
        flagAccentColor:     Color(red: 0x60/255, green: 0xA0/255, blue: 0xD8/255),
        revealedOverlayColor: Color(red: 30/255,  green: 28/255,  blue: 22/255),
        pinColor:            Color(red: 0x48/255, green: 0x88/255, blue: 0xA0/255),
        playButtonColor:     Color(red: 0x5A/255, green: 0x8A/255, blue: 0x88/255)  // river teal
    )
}
