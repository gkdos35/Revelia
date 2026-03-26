# Signalfield — Tile Visual System Spec + Cowork Prompt

## Design Decisions Summary

- **Hidden tiles:** AI-generated watercolor texture images, clipped to tile shape (square or hex)
- **Revealed tiles:** No image. Semi-transparent dark overlay (75% opacity black or biome-tinted dark) over the gameplay background, so ~25% of the background shows through. Signal glyphs/numbers rendered on top in biome-accent color.
- **Flagged tiles:** Hidden texture image + biome-tinted glowing border + flag diamond symbol in biome accent color
- **Tile shape:** Soft rounded corners (square grid) or hexagon (hex grid) — same texture image, different clip mask
- **Transparency:** Fixed 25% background show-through on revealed tiles across all biomes
- **Signal number readability:** Numbers use biome-accent color with subtle text shadow/glow to ensure readability against the partially-visible background

---

## Biome Tile Palettes

### Biome 0: Training Range
- **Material:** Mossy meadow stone
- **Hidden texture:** `Training Range hidden tile.png`
- **Signal color:** #c2e090 (soft lime green)
- **Flag accent:** #d4a030 (warm gold)
- **Revealed overlay tint:** rgba(30, 50, 20, 0.75)

### Biome 1: Fog Marsh
- **Material:** Wet mossy swamp stone
- **Hidden texture:** `Fog Marsh hidden tile.png`
- **Signal color:** #80d4b4 (seafoam teal)
- **Flag accent:** #60c8a0 (bright teal-green)
- **Revealed overlay tint:** rgba(20, 40, 34, 0.75)

### Biome 2: Bioluminescence
- **Material:** Dark forest mushroom cap / seed pod
- **Hidden texture:** `Bioluminescence hidden tile.png`
- **Signal color:** #70e0e0 (electric cyan)
- **Flag accent:** #50c8d0 (bright cyan)
- **Revealed overlay tint:** rgba(15, 20, 35, 0.75)

### Biome 3: Frozen Mirrors
- **Material:** Polished glacier ice
- **Hidden texture:** `Frozen Mirrors hidden tile.png`
- **Signal color:** #a8daf0 (pale ice blue)
- **Flag accent:** #b8e4f8 (bright ice)
- **Revealed overlay tint:** rgba(30, 45, 60, 0.75)

### Biome 4: Ruins
- **Material:** Weathered carved sandstone
- **Hidden texture:** `Ruins hidden tile.png`
- **Signal color:** #e8c880 (warm gold)
- **Flag accent:** #d4a050 (amber)
- **Revealed overlay tint:** rgba(40, 30, 20, 0.75)

### Biome 5: The Underside
- **Material:** Smooth cave stone with mineral veins
- **Hidden texture:** `The Underside hidden tile.png`
- **Signal color:** #c0a0e0 (soft purple)
- **Flag accent:** #a880d0 (bright violet)
- **Revealed overlay tint:** rgba(25, 20, 30, 0.75)

### Biome 6: Coral Basin
- **Material:** Living coral / sea-tumbled shell
- **Hidden texture:** `Coral Basin hidden tile.png`
- **Signal color:** #f0a8a0 (warm coral pink)
- **Flag accent:** #e88880 (bright coral)
- **Revealed overlay tint:** rgba(20, 30, 45, 0.75)

### Biome 7: Quicksand
- **Material:** Crusted dried mud over wet sand
- **Hidden texture:** `Quicksand hidden tile.png`
- **Signal color:** #e8c070 (dusty gold)
- **Flag accent:** #d0a048 (dark amber)
- **Revealed overlay tint:** rgba(40, 30, 18, 0.75)

### Biome 8: The Delta
- **Material:** Multi-environment river stone
- **Hidden texture:** `The Delta hidden tile.png`
- **Signal color:** #d0c8b0 (warm neutral)
- **Flag accent:** #c0a878 (sandy gold)
- **Revealed overlay tint:** rgba(30, 28, 22, 0.75)

---

## Cowork Prompt

**Read CLAUDE.md first.** Then read `reference/signalfield-design-decisions.md` for biome mechanics context. Show me your plan before writing any code.

### Task: Biome-Themed Tile Visual System

#### Context
The gameplay screen now has watercolor background images per biome and a dark board zone overlay. The next layer is making the tiles themselves match each biome's theme. We have AI-generated watercolor texture images for each biome's hidden tiles, and a complete palette spec for all 9 biomes.

#### Assets
Tile texture images are in `reference/brand/tiles/` with this naming:
- `Training Range hidden tile.png`
- `Fog Marsh hidden tile.png`
- `Bioluminescence hidden tile.png`
- `Frozen Mirrors hidden tile.png`
- `Ruins hidden tile.png`
- `The Underside hidden tile.png`
- `Coral Basin hidden tile.png`
- `Quicksand hidden tile.png`
- `The Delta hidden tile.png`

#### What needs to happen

**1. Add all 9 tile texture images to the Xcode asset catalog.**
- Create an imageset for each, named like `TrainingRangeTile`, `FogMarshTile`, etc.
- Hex biomes (9–17) reuse the same tile textures as their square counterparts (0–8).

**2. Create a BiomeTheme data structure.**
Define a struct or enum that maps each biome to its visual properties:
- `tileTextureName: String` — asset catalog name for hidden tile image
- `signalColor: Color` — color for signal glyphs/numbers on revealed tiles
- `flagAccentColor: Color` — color for flag diamond and flagged tile border glow
- `revealedOverlayColor: Color` — biome-tinted dark color at 75% opacity for revealed tiles
- A lookup function that takes a level number and returns the correct BiomeTheme

Use these exact values per biome:

| Biome | Signal Color | Flag Accent | Revealed Overlay (75% opacity) |
|-------|-------------|-------------|-------------------------------|
| 0 Training Range | #c2e090 | #d4a030 | rgba(30, 50, 20, 0.75) |
| 1 Fog Marsh | #80d4b4 | #60c8a0 | rgba(20, 40, 34, 0.75) |
| 2 Bioluminescence | #70e0e0 | #50c8d0 | rgba(15, 20, 35, 0.75) |
| 3 Frozen Mirrors | #a8daf0 | #b8e4f8 | rgba(30, 45, 60, 0.75) |
| 4 Ruins | #e8c880 | #d4a050 | rgba(40, 30, 20, 0.75) |
| 5 The Underside | #c0a0e0 | #a880d0 | rgba(25, 20, 30, 0.75) |
| 6 Coral Basin | #f0a8a0 | #e88880 | rgba(20, 30, 45, 0.75) |
| 7 Quicksand | #e8c070 | #d0a048 | rgba(40, 30, 18, 0.75) |
| 8 The Delta | #d0c8b0 | #c0a878 | rgba(30, 28, 22, 0.75) |

**3. Render hidden tiles using the texture image.**
- In TileView, when a tile is in the hidden state, display the biome's tile texture image clipped to the tile shape.
- For square grid levels: clip to a rounded rectangle (corner radius ~4–6px, matching current tile rounding).
- For hex grid levels: clip to a regular hexagon shape.
- The texture image should fill the tile area (aspect fill, centered, no stretching).
- The tile should have a very subtle border (0.5px, biome signal color at ~20% opacity) to define edges against the board zone overlay.

**4. Render revealed tiles as semi-transparent overlays.**
- When a tile is revealed, do NOT use a texture image.
- Instead, render a filled shape (rounded rect or hex, matching the grid) with the biome's `revealedOverlayColor` (75% opacity biome-tinted dark).
- This lets ~25% of the gameplay background image show through the tile, creating a "cracked open to see the world beneath" effect.
- Render the signal glyph/number on top in the biome's `signalColor`.
- Add a subtle text shadow (1px, black at 50% opacity) behind the signal glyph to ensure readability against the partially-visible background.
- Zero-signal revealed tiles: render the overlay shape at slightly lower opacity (~60%) with no number — they should recede more than numbered tiles.

**5. Render flagged tiles.**
- Flagged tiles show the hidden texture image (same as hidden state) PLUS:
  - A glowing border in the biome's `flagAccentColor` (1.5px solid, plus a soft outer glow/shadow of ~4px in the same color at 30% opacity)
  - The flag diamond symbol (◆) centered on the tile in the biome's `flagAccentColor`
  - A subtle text shadow on the diamond (1px, black at 40%)

**6. Handle special tile states layered on top of the base rendering.**
These are additive — they modify the base hidden/revealed/flagged appearance, not replace it:
- **Fogged tiles (Fog Marsh):** Hidden tile appearance + a dashed inner border (inset 3px, 1px dashed, biome signal color at 25% opacity) to indicate fog. When revealed after beacon, renders as normal revealed tile.
- **Linked tiles (Frozen Mirrors):** Hidden tile appearance + a small indicator dot (6–8px circle) in the bottom-right corner of the tile in the biome's signal color at 40% opacity. Both tiles in a linked pair show this dot.
- **Locked tiles (Ruins):** Hidden tile appearance but at reduced opacity (~50%) to indicate they can't yet be interacted with. When unlocked, snaps to full opacity hidden appearance.
- **Sonar tiles (Coral Basin):** Revealed tile appearance but signal shows directional counts. No visual change to the tile itself — the signal rendering handles this.
- **Quicksand fading tiles:** Revealed tile appearance where the signal glyph fades out over time (opacity animation from 100% to 0%). The tile overlay itself stays the same.
- **Bioluminescence pulse:** Not a tile state — this is an overlay effect on top of tiles. Do not modify tile rendering for this.

**7. Hazard tile on loss.**
When the board is revealed after a loss, hazard tiles should render with a warm amber/rust fill (#c0603a) — NOT red. This is consistent across all biomes. The hazard symbol renders in white or cream on top.

#### Do NOT change
- Game engine logic, mechanics, board generation, scoring, or cascade behavior
- Gameplay background images or board zone overlay (already implemented)
- HUD bar design or layout
- Level select or biome select screens
- Grid geometry, tile sizing, or board layout calculations
- Any existing image assets outside of tiles

#### Files likely involved
- `TileView.swift` — main file to modify for all tile rendering
- `Assets.xcassets` — new imagesets for tile textures
- New file: `BiomeTheme.swift` — biome palette data structure
- `GameViewModel.swift` — may need to expose current biome theme to views
- `GlyphMapper.swift` — signal glyph rendering may need color updates

#### Key Principles
- Hidden tiles are the visual showpieces — bright, textured, tactile
- Revealed tiles recede — dark, functional, numbers are the focus
- Flagged tiles are hidden tiles + accent glow — they stand out without losing their material identity
- Special states are additive layers, not replacement renders
- The same texture image works for both square and hex via different clip masks
- Signal readability always wins over visual flair
