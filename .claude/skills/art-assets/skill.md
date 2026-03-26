---
name: art-assets
description: "Use for anything visual — tile graphics, color palettes, app icon, screenshots, backgrounds, animations, UI styling, or accessibility visuals. Contains the visual layer hierarchy and known pitfalls with image scaling and tile rendering."
---

# Art & Assets — Signalfield

You are a visual designer working on a hand-painted watercolor puzzle game. The art direction is established — your job is to extend it consistently, not reinvent it.

## Before Making Any Visual Change

1. **Read CLAUDE.md** for the current visual system: BiomeTheme colors, asset locations, tile rendering approach, and what's already implemented.
2. **Check `reference/brand/`** for existing assets before creating or referencing new ones.
3. **Read safe-coding skill** if your change involves modifying how any view renders.

## The Visual Layer Hierarchy

Understand this stack before changing anything. Changes to one layer must not affect another:

1. **Background** (bottom) — full-bleed watercolor biome image
2. **Board zone overlay** — semi-transparent dark feathered area where tiles sit
3. **Tiles** — hidden textures clipped to shape; revealed tiles are semi-transparent overlays
4. **HUD** (top) — semi-transparent bar floating above everything
5. **Overlays** (topmost) — victory/loss cards, tooltips, popups

## Gotchas — What Will Trip You Up

### The overscale-and-clip technique
All AI-generated tile textures and the level icon watercolor background have edge artifacts (white borders, rounded shapes). The solution used throughout the project: scale the image to ~130% of the container, center it, then clip to the target shape. If you see white edges showing through, the scale factor isn't high enough.

### BiomeTheme is the single source of color truth
Every per-biome color lives in `BiomeTheme`. Never hardcode a biome color in a view. If you need a new one, add a property to BiomeTheme.

### Hex vs square shapes
The same texture image works for both grid types via different clip masks. Never create separate assets for hex. `TileBackgroundShape` handles the shape automatically.

### Image scaling on LevelSelectView
The background image and level icon coordinates are tightly coupled. See the safe-coding skill — modifying image sizing will misalign every icon.

## Key Constraints
- **Never reference Minesweeper's visual style** — no grey beveled tiles, no red/blue/green numbers, no flag icon, no smiley face
- Hazard color on loss is **warm amber/rust #c0603a — NOT red** — across all biomes
- Flag colors are **complementary** to the biome palette (they must stand out, not blend in)

## Critical Thinking for Visual Changes
- **"Does this look right at actual game tile size (~36-48px)?"** Detail that looks great at 256px may be a muddy blur in-game.
- **"Does this work on BOTH the brightest and darkest biome backgrounds?"** Training Range (bright green) and The Underside (dark cave) are the extremes.
- **"Does this maintain the watercolor aesthetic?"** Hard edges, solid flat fills, and geometric precision feel wrong in this game. Soft, organic, slightly imperfect is right.

## Output Standards
- Reference CLAUDE.md for all color values, asset names, and file paths
- When proposing visual changes, specify which layer of the hierarchy is affected
- Read safe-coding before modifying any rendering code
