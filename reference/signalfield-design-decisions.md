# Signalfield Design Decisions — Completed (v3)

> All design questions answered. Biome mechanics revised twice and finalised.
> This document is kept as a decision record.

## Core Decisions

**Q1. Session length:** Escalating — Training Range ~1–2 min, The Delta ~10–15 min
**Q2. First-scan safety:** 3×3 safe zone (tile + all 8 neighbors)
**Q3. After losing:** Full board reveal (all hazards, signals, correct/incorrect tags)
**Q4. Chording:** Yes, included (shift-click). Not taught in tutorial.
**Q5. Casual Shield:** Earned by clearing a biome's first level without mistakes.
**Q6. Win condition:** NO Exit tile. Win when all safe tiles revealed OR all hazards tagged.
**Q7. Scoring:** Efficiency-based. score = 100000 - time×20 - totalActions×30 + noGuess×15000.

## Biome Mechanics (Revised)

Biomes went through two rounds of revision. The first pass (v2) replaced the
original biomes 2/3/4 (Ice Flats, Clockwork Ruins, Volcanic Field) because they
failed the core design test: each mechanic must modify what information a clue
provides while keeping that information precise.

- Ice Flats → **Frozen Mirrors (Linked Tiles):** presentation mechanic replaced with spatial reasoning mechanic
- Clockwork Ruins → **Cracked Ruins (Liar Tiles):** artificial information withholding replaced with branching logic
- Volcanic Field → **Coral Basin (Sum Tiles):** imprecise rescaled values replaced with exact combined counts

The second pass (v3) further refined the progression to better fit the game's
organic theme and create a richer, more varied arc:

- **Cracked Ruins (Liar Tiles)** → **Ruins (Locked Tiles):** liar ambiguity swapped for a strategic tile-ordering mechanic that rewards planning the reveal sequence
- **Coral Reef (Directional) + Neon Circuit (Blockers)** → **The Underside (Inverted Signals) + Quicksand (Fading Signals):** line-constraint and blind-spot mechanics replaced with inverted deduction and time-pressure mechanics that broaden the reasoning palette
- **Bioluminescence (Conductor Pulse)** added as biome 2: a one-use area reveal that creates a memorable information-burst moment without approximation or ambiguity

**Final biome order (v3):**
| # | Name | Mechanic | Why it works |
|---|------|----------|-------------|
| 0 | Training Range | Baseline | Standard deduction |
| 1 | Fog Marsh | Fogged ranges + beacons | Intersecting imprecise ranges = precise deduction |
| 2 | Bioluminescence | Conductor Pulse (area flash) | Timed reveal burst — use it or lose the moment |
| 3 | Frozen Mirrors | Linked tile pairs (≥1 non-zero) | Spatial remapping of exact clues |
| 4 | Ruins | Locked tiles (neighbor threshold) | Strategic ordering — plan your uncovering sequence |
| 5 | The Underside | Inverted signals (safe count) | Inverted deduction — high signal means safety |
| 6 | Coral Basin | Sonar tiles (NSEW, range K) | Triangulation from directional line constraints |
| 7 | Quicksand | Fading signals | Time-pressure deduction — read clues before they sink |
| 8 | The Delta | Confluence (all mechanics) | Final chapter — all prior mechanics combined |

## Cascade Rules
- Stops at: fogged tiles, locked tiles (until unlocked by neighbor threshold), blocker tiles
- Reveals: beacons (triggers fog-clearing in radius)
- Linked tiles: cascade uses TRUE own signal (not the displayed partner signal)
- Sonar tiles: cascade only if all directional counts total 0
- Quicksand tiles: cascade normally; fading applies only to already-revealed tiles
- Bioluminescence pulse: not a cascade — it is an active targeted reveal, not BFS propagation

## Board Generation Constraints
- **Frozen Mirrors:** At least one tile in every linked pair must have a non-zero signal count. Pairs where both tiles are zero provide no useful information and must be re-selected. The required pair count per level is a hard minimum (1 pair at L23/L97, scaling to 5 at L30/L104) — if the generator cannot place the required number of valid pairs, retry board generation.
- **Fog Marsh:** Minimum 2-tile spacing between fog tiles.
- **Ruins:** Locked tiles never contain hazards and are never placed on corner positions.

## The Delta — Confluence Chapter
The Delta (biome 8) is the final chapter: L63–L74 (square) and L137–L148 (hex).
Rather than discrete standalone confluence levels, The Delta layers mechanics
progressively across its 12 levels, combining fog, linked tiles, sonar, locked
tiles, inverted signals, quicksand, and bioluminescence pulses as difficulty peaks.

Entry to The Delta triggers a dedicated intro overlay (DeltaIntroOverlay) that
summarises all 7 prior biome mechanics in one card. The same overlay fires for the
hex Delta at L137.

## End-of-Biome Flow
When the player completes the last level of any biome, the normal end-of-level
screen is replaced by a special biome-complete summary screen showing: biome name,
total stars earned across all levels, and a congratulatory message. A single "Return
to Map" button navigates back to BiomeSelectView. Mid-biome levels continue to show
the normal end-of-level screen with "Next Level" and "Retry."

### Biome Reveal Sequence
On returning to the map after biome completion, a cinematic multi-step reveal plays
(~5 seconds total, non-blocking — player can tap away at any time):

1. Pause (0.5s) — map renders with new biome still fogged
2. Camera pan (~1s) — map scrolls to center the newly unlocked region (easeInOut)
3. Fog dissolve + golden shimmer (~2s) — fog fades out while warm golden glow pulses over region
4. Text banner (~1.5s) — "[Biome Name] Unlocked!" fades in/out centered on screen
5. Pin appears — scales from 0 to full with slight bounce, biome now interactive

For L74/L148 (campaign complete): no pan, show "Campaign Complete!" banner with
golden shimmer across the entire map.

## Campaign Screen Design
Two-screen structure: Biome Select → Level Select.
- **Biome Select:** hand-painted watercolor continent map image (`reference/brand/continent-map.png`) as background. Map is pannable and slightly zoomable. Hex biomes share the same map region as their square counterpart (toggle, not separate regions).
- **Fog approach: SUBTRACTIVE.** A single white fog layer (opacity 0.80–0.85) covers the entire map. Unlocked biomes are subtracted as holes from the fog, revealing terrain. Gaussian blur (~15–20px) softens edges. This avoids gaps, overlaps, and residual fog bands between regions. Adjacent biome paths must share identical edge coordinates — every pixel of land belongs to exactly one biome.
- **Level Select:** hand-painted watercolor background per biome (`reference/brand/[BiomeName].png`). No code-drawn trail — the painted image contains the path. Level circles placed along the painted path (auto-detected or hardcoded coordinates). Three circle states: locked (faint translucent ~30% opacity), unlocked (glowing/pulsing, shows level number), completed (bronze/silver/gold fill by star count). Tap to expand details (stars, score, time), then tap Play. Hex biomes reuse square biome images. Back button returns to biome select.
- **Level locking:** strictly linear (must complete L7 to unlock L8). Hex biome entry points unlock after completing equivalent square biome.

## Player Experience
- **Target:** Casual Puzzler
- **Feel:** Exciting opening → mounting tension → satisfying finish
- **Visual:** Natural/organic — earth tones, hand-drawn, biomes as real environments
- **Replay:** Star ratings, specimen collection, achievement badges, seed sharing, par scores

## Specimen Collection (Meta-Reward System)
Each level has a unique specimen (creature or plant thematic to its biome). Earning
3 stars unlocks that level's specimen. Fully 3-starring an entire biome earns a
special rare specimen. Up to 166 total collectibles (148 level + 18 biome).

The collection cabinet is accessed from the biome select screen. Collected specimens
show image + name only. Uncollected specimens are completely hidden — the cabinet
grows as the player discovers, with no indication of total count or what's missing.

Specimens are themed per biome: meadow creatures for Training Range, bog amphibians
for Fog Marsh, glowing insects for Bioluminescence, arctic fauna for Frozen Mirrors,
fossils for Ruins, cave creatures for The Underside, sea life for Coral Basin, desert
species for Quicksand, and rare hybrid species for The Delta.

## Monetization Direction
Free core game + optional rewarded ads + one-time Pro unlock ($4–6, removes ads).
Some specimen collection content may be reserved for Pro as a premium incentive. TBD.
Subscription only considered if daily challenge mode proves strong retention.

## Bonus Questions (For Later)
- B1. Music vs ambient: TBD
- B2. Pricing model: Leaning free + Pro unlock (see above)
- B3. Post-launch biomes: TBD
- B4. iOS port: Primary revenue opportunity — build after Mac launch
- B5. Multiplayer: TBD
