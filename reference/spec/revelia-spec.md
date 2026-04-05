<!-- SIGNALFIELD — MASTER SPECIFICATION (v3)
     All design decisions incorporated. New biome mechanics finalized.
     This is the SOURCE OF TRUTH. If any skill file conflicts, THIS WINS. -->

# Revelia — Game Specification

## Project Overview
Revelia is an original macOS logic puzzle game built on deduction
mechanics, with completely original theme, terminology, UI, and rules.

**Platform:** macOS 13+ (Ventura) native app
**Language:** Swift 5.9+
**UI:** SwiftUI (NSViewRepresentable only if needed)
**Dependencies:** Zero external — pure Swift
**Architecture:** MVVM
**Distribution:** Mac App Store

---

## HIGH-LEVEL PILLARS

### 1. Originality
- NO Minesweeper branding, art, smiley faces, number colors, or mine/flag terminology
- Theme: "signals + hazards + extraction"
- Terminology: "Scan" (left click), "Tag" (right click/ctrl-click)
- Default clues: GLYPHS (pips/runes). Accessibility toggle for numbers.

### 2. Fun + Fairness
- First Scan is always safe (3×3 safe zone: tile + all 8 neighbors)
- Avoid unwinnable starts; generate until valid
- Support "No-Guess" and "Risk-Allowed" modes with honest labeling

### 3. Target Player: Casual Puzzler
- Primary audience: casual puzzle fans who want relaxing, satisfying play
- Needs clear onboarding — glyphs must be taught, not assumed
- Session length escalates: ~1–2 min early, ~10–15 min late campaign

### 4. Game Feel
- Opening: exciting, big cascade dopamine from the 3×3 safe zone
- Mid-game: mounting tension as stakes increase with fewer hidden tiles
- Visual: natural/organic — earth tones, hand-drawn feel, biomes as real environments

---

## GAME RULES

### Board
- Grid-based (square grid in v1)
- Tiles: Hidden / Revealed / Tagged
- Hidden hazards placed at generation time and NEVER move

### Actions
- **Scan** (left click): Reveal tile
- **Tag** (right click / ctrl-click): Cycle tag state:
  1. None
  2. Suspect (?)
  3. Confirmed (solid)
- **Chord** (shift-click): If a revealed tile's signal count equals its
  adjacent confirmed tag count, auto-reveal all other adjacent hidden tiles.
  If tags are wrong, player hits a hazard — risk/reward mechanic.

### Clues
- Revealed safe tiles show a "Signal glyph" for hazard count in neighborhood
- Default: glyphs (pips). Settings toggle: Glyphs / Numbers
- 0-signal tile triggers Cascade auto-reveal

### Win Condition
Player wins when EITHER:
- All safe tiles are revealed, OR
- All hazards have confirmed tags (and no incorrect confirmed tags exist)

Whichever condition is met first. **There is no Exit tile.**

### Lose Condition
- Scanning a hazard ends the level (unless Casual Shield absorbs it)
- On loss: **full board reveal** — show all hazard locations, all signal
  values, the player's tags highlighted as correct (on hazard) or incorrect
  (on safe tile)

### Casual Shield System
- Shields are EARNED, not given
- Clearing a biome's first level without any mistakes earns one shield
- Shield is usable on any subsequent level within that biome
- When a shield absorbs a hazard hit:
  - The hazard is revealed and auto-tagged as confirmed
  - Player continues with no shield remaining
  - No-Guess bonus is forfeited for that run
  - Shield usage is recorded on leaderboard entries
- Shields do NOT carry between biomes

### Cascade Rules
- Standard: BFS from 0-signal tile, reveal contiguous 0-signal tiles + borders
- Cascade STOPS at: fogged tiles, liar tiles, blocker tiles
- Cascade treats linked tiles normally (uses their OWN signal for cascade
  purposes even though they display their partner's signal — see Biome 2)
- Cascade never reveals hazards

### First-Scan Safety
- 3×3 safe zone: clicked tile + all 8 neighbors guaranteed hazard-free
- Hazards placed AFTER first scan, excluding the 3×3 zone
- This guarantees a meaningful opening cascade on most boards

---

## SCORING

### Formula (Efficiency-Based)
```
totalActions = scansCount + tagsPlacedCount
score = 100000
        - timeSeconds × 20
        - totalActions × 30
        + (noGuessValidated ? 15000 : 0)
Clamp minimum 0.
```

Primary sort: score DESC. Ties: time ASC.

### Star Ratings (Per Level)
- ★ Complete the level
- ★★ Complete under par time
- ★★★ Complete under par time in No-Guess mode

Par times are defined per LevelSpec.

### Tracked Per Run
- elapsedTimeSeconds
- scansCount
- tagsPlacedCount (total tag actions)
- confirmedTagsCount (confirmed tags at end)
- totalActions (scans + tags)
- shieldUsed (bool)
- noGuessValidated (bool)
- seed

### Replay Features
- **Star ratings:** 1–3 per level (see above)
- **Par scores:** Developer-defined par time per level
- **Achievement badges:** "Cascade King" (50+ tiles), "Perfectionist" (all 3-star), etc.
- **Seed sharing:** Players can share seeds to challenge others

---

## BIOMES + LEVEL PROGRESSION

### Design Principle
Every biome mechanic must:
1. Modify WHAT INFORMATION a clue provides (not just how it's delivered)
2. Keep all information PRECISE (no ambiguity that forces guessing)
3. Create a genuinely NEW REASONING PATTERN describable in one sentence
4. Interact cleanly with cascade and other mechanics

Each level is a LevelSpec:
- id, biomeId, displayName, boardWidth, boardHeight, hazardDensity,
  mechanicParams, difficultyLabel, noGuessTarget, parTimeSeconds

---

### Biome 0: Training Range (Levels 1–6)
**Mechanic:** None (baseline)
**Player reasoning:** "This tile shows 2 — based on overlapping neighbor
counts from nearby tiles, I can deduce which adjacent tiles are hazards."

- L1: 6×6, density 0.12
- L2: 6×6, density 0.14
- L3: 7×7, density 0.14
- L4: 8×8, density 0.15
- L5: 8×8, density 0.16
- L6: 8×8, density 0.17 (timed challenge label)

---

### Biome 1: Fog Marsh (Levels 7–14)
**Mechanic:** Fogged Signals — some tiles show a range (e.g., "2–3")
instead of exact signal. Beacons clarify fog in radius R.
**Player reasoning:** "This fogged tile says 2–3, and the one next to it
says 1–2. The overlap tells me this shared neighbor CAN'T be a hazard —
I'm eliminating possibilities using intersecting ranges."

**Rules:**
- Fog clue: range is always exactly 1 apart. Each fogged tile randomly
  shows either (exact-1, exact) or (exact, exact+1), clamped to 0–8.
  Examples: exact 3 → "2–3" or "3–4"; exact 0 → always "0–1";
  exact 8 → always "7–8". A range like "1–3" should never appear.
- When beacon revealed: all fogged tiles within radius show exact signal
- Cascade STOPS at fogged tiles (player must scan manually)
- Cascade REVEALS beacons and triggers fog-clearing
- **Hidden-state rule:** Fogged tiles and beacons are visually
  indistinguishable from normal hidden tiles. No haze, antenna icon, or
  other indicator appears until the tile is revealed. The player discovers
  a tile is fogged only when they scan it and see a range instead of an
  exact signal. Beacons are discovered only upon reveal (via scan or
  cascade), at which point they trigger fog-clearing. This prevents the
  player from inferring tile safety from pre-reveal visuals.
- **Fog density:** Exact tile counts (not fractions). Fog tiles are
  isolated deduction puzzles, not a dominant board-covering mechanic.
- **Fog spacing:** Minimum Chebyshev distance of 3 between any two
  fogged tiles (at least 2 empty tiles of separation). Prevents clusters.
- **Cascade preservation:** Fog tiles prefer interior board positions
  (≥ 1 tile from edge) to avoid walling off edge-originating cascades.

- L7:  8×8  density 0.16 fogCount 2 beacons 1 radius 2
- L8:  8×8  density 0.16 fogCount 2 beacons 2 radius 2
- L9:  9×9  density 0.17 fogCount 3 beacons 2 radius 2
- L10: 9×9  density 0.17 fogCount 3 beacons 2 radius 3
- L11: 9×9  density 0.18 fogCount 4 beacons 2 radius 3
- L12: 10×10 density 0.18 fogCount 4 beacons 2 radius 3
- L13: 10×10 density 0.19 fogCount 5 beacons 2 radius 3
- L14: 10×10 density 0.20 fogCount 6 beacons 2 radius 3

---

### Biome 2: Frozen Mirrors (Levels 15–22)
**Mechanic:** Linked Tiles — pairs of tiles are visibly connected by a
line. Each tile in a pair displays its PARTNER'S signal, not its own.
**Player reasoning:** "This tile says 3, but that's actually the hazard
count for the tile it's linked to across the board. I need to mentally
map the clue to the right neighborhood before I can deduce anything."

**Rules:**
- Linked pairs are generated at board creation, visible from the start
- Connection lines are always visible (even when tiles are hidden)
- A linked tile's displayed signal = partner's 8-neighbor hazard count
- The tile's OWN signal is never directly shown — must be inferred from
  other adjacent tiles' clues
- For cascade purposes, a linked tile uses its OWN actual signal (not the
  displayed one). So a tile displaying "3" might actually have 0 hazard
  neighbors and will cascade normally.
- Linked tiles can be scanned, tagged, and chorded normally
- Links are always between two safe tiles (never a hazard)
- Both tiles in a pair share the "linked" visual treatment

**Level params:** linkPct = fraction of safe tiles that are linked (in pairs)
- L15: 9×9  density 0.17 linkPct 0.10
- L16: 9×9  density 0.18 linkPct 0.14
- L17: 10×10 density 0.18 linkPct 0.16
- L18: 10×10 density 0.19 linkPct 0.18
- L19: 10×10 density 0.20 linkPct 0.20
- L20: 10×10 density 0.20 linkPct 0.22
- L21: 11×11 density 0.20 linkPct 0.24
- L22: 11×11 density 0.21 linkPct 0.26

---

### Biome 3: Cracked Ruins (Levels 23–30)
**Mechanic:** Liar Tiles — some tiles are visually marked as "cracked"
(unreliable). Their displayed signal is guaranteed to be off by exactly 1
(either +1 or -1 from the true value), but the player doesn't know which.
**Player reasoning:** "This cracked tile says 3 — it's actually 2 or 4.
The reliable tile next to it says 2. If the liar is really 4, then these
two tiles together account for all the hazards in this area. If it's 2,
there's a gap. I can cross-reference to figure out which."

**Rules:**
- Liar tiles are visually distinct (cracked texture/icon) before and after reveal
- The offset is ALWAYS exactly 1 — never 0, never 2+
- The offset direction (+1 or -1) is determined at generation and stored,
  but never shown to the player
- Liar tiles with true signal 0 always show 1 (can't go negative)
- Liar tiles with true signal 8 always show 7 (can't exceed 8)
  (This means 0-displayed and 8-displayed tiles are guaranteed truthful,
  which is a deduction the player can learn)
- For cascade: uses the TRUE signal. A liar displaying "1" whose true
  signal is 0 WILL cascade (this is an intentional deduction opportunity)
- Cascade STOPS at liar tiles only if their true signal > 0
  (i.e., treat them like normal tiles for cascade, using true value)
- Validator must ensure every liar-affected constraint is still solvable
  through cross-referencing

**Level params:** liarPct = fraction of safe tiles that are liars
- L23: 10×10 density 0.19 liarPct 0.10
- L24: 10×10 density 0.19 liarPct 0.14
- L25: 11×11 density 0.19 liarPct 0.16
- L26: 11×11 density 0.20 liarPct 0.18
- L27: 11×11 density 0.20 liarPct 0.20
- L28: 12×12 density 0.20 liarPct 0.22
- L29: 12×12 density 0.21 liarPct 0.24
- L30: 12×12 density 0.21 liarPct 0.26

---

### Biome 4: Coral Basin (Levels 31–38)
**Mechanic:** Sum Tiles — some tiles display the COMBINED hazard count of
their standard 8-neighborhood PLUS a second highlighted region elsewhere
on the board. The player must split the total between the two regions.
**Player reasoning:** "This tile shows 5, and its secondary region is
highlighted 4 tiles away. From other clues I know the secondary region
has 2 hazards, so my local neighborhood must have 3. Now I can deduce
locally."

**Rules:**
- Sum tiles are visually distinct (a glow or icon indicating "dual region")
- When revealed, the tile shows one combined number
- The secondary region is highlighted on the board (a colored overlay on
  the 4–6 tiles in the remote zone)
- Secondary regions are contiguous rectangular areas (2×2, 2×3, or 3×2)
- The signal = (local 8-neighbor hazards) + (hazards inside secondary region)
- All values are exact — no rounding, no approximation
- Secondary regions can overlap between different sum tiles (creating
  linked equations the player can solve simultaneously)
- For cascade: uses the TOTAL signal. A sum tile only cascades if BOTH
  its local neighborhood AND secondary region contain 0 hazards
- Validator must ensure the puzzle is solvable — the player must be able
  to determine the split through cross-referencing other clues

**Level params:** sumPct = fraction of safe tiles that are sum tiles,
regionSize = size of secondary region
- L31: 10×10 density 0.18 sumPct 0.10 regionSize 2×2
- L32: 10×10 density 0.19 sumPct 0.12 regionSize 2×2
- L33: 11×11 density 0.19 sumPct 0.14 regionSize 2×2
- L34: 11×11 density 0.20 sumPct 0.16 regionSize 2×3
- L35: 11×11 density 0.20 sumPct 0.18 regionSize 2×3
- L36: 12×12 density 0.20 sumPct 0.20 regionSize 2×3
- L37: 12×12 density 0.21 sumPct 0.22 regionSize 3×2
- L38: 12×12 density 0.21 sumPct 0.24 regionSize 3×2

---

### Biome 5: Coral Reef (Levels 39–46)
**Mechanic:** Directional Readouts — some tiles show hazard counts in
NSEW directions within range K, instead of neighborhood count.
**Player reasoning:** "This tile says 2 to the North within 3 tiles. Combined
with the tile above it saying 1 to the South within 3, I can triangulate
exactly which tiles in that column contain hazards."

**Rules:**
- Directional tiles show 4 small counts (N, S, E, W) instead of one signal
- Each count = hazards in that cardinal direction within K tiles
- Diagonal neighbors are NOT counted (pure cardinal lines)
- Directional tiles cascade normally (using total of all 4 directional
  counts as the effective signal; if all 4 are 0, it cascades)

- L39: 10×10 density 0.18 dirPct 0.20 range 3
- L40: 10×10 density 0.19 dirPct 0.25 range 3
- L41: 11×11 density 0.19 dirPct 0.30 range 3
- L42: 11×11 density 0.20 dirPct 0.35 range 3
- L43: 11×11 density 0.20 dirPct 0.35 range 4
- L44: 12×12 density 0.20 dirPct 0.40 range 4
- L45: 12×12 density 0.21 dirPct 0.40 range 4
- L46: 12×12 density 0.21 dirPct 0.45 range 4

---

### Biome 6: Neon Circuit (Levels 47–56)
**Mechanic:** Signal Blockers — shield tiles block signal propagation.
Adjacent hazards separated by a shield in a cardinal direction are NOT
counted. Cascade stops at blocker tiles (they act as walls).
**Player reasoning:** "This tile shows 1, but there's a shield between it
and the tile to the east. That means any hazard to the east is invisible
to this signal — I need to account for blind spots when deducing."

**Rules:**
- Blocker tiles are terrain, always visible from the start
- They are not hazards, not safe tiles — they are inert obstacles
- A hazard on the other side of a blocker (in a cardinal direction) does
  NOT contribute to an adjacent tile's signal count
- Diagonal neighbors are unaffected by blockers
- Cascade STOPS at blocker tiles (they act as walls)

- L47: 10×10 density 0.18 blockers 0.08
- L48: 10×10 density 0.19 blockers 0.10
- L49: 11×11 density 0.19 blockers 0.12
- L50: 11×11 density 0.20 blockers 0.12
- L51: 11×11 density 0.20 blockers 0.14
- L52: 12×12 density 0.20 blockers 0.14
- L53: 12×12 density 0.21 blockers 0.16
- L54: 12×12 density 0.21 blockers 0.16
- L55: 12×12 density 0.22 blockers 0.18
- L56: 12×12 density 0.22 blockers 0.18

---

### Confluence Levels (57–59)
Combine exactly TWO mechanics per level:

**L57: Fog + Linked** — Some linked tiles display a fogged range from their
partner's neighborhood. The player must mentally relocate an imprecise clue
to a different part of the board, then use range intersection to resolve it.

**L58: Sum + Blockers** — Sum tiles whose secondary regions contain blockers.
The player must account for blind spots in BOTH their local neighborhood
and the remote region when splitting the combined count.

**L59: Fog + Liar** — Some fogged tiles are also liars. A fogged liar might
show "2–3" when the true value is 1–2 or 3–4 (fog applied to the liar's
offset value). The player resolves double uncertainty through aggressive
cross-referencing with reliable, unfogged neighbors.

Parameters TBD during development based on individual biome playtesting.

---

## BOARD GENERATION

### Seed and RNG
- Seed: UInt64, stored in results + save file
- RNG: SplitMix64 (deterministic)

### Generation Order
1. Create empty grid from LevelSpec dimensions
2. Place terrain (blockers) from seed
3. Place special tile designations (fog zones, linked pairs, liar markers,
   sum tile regions, directional tiles) from seed
4. WAIT for first scan
5. Place hazards from seed, excluding 3×3 zone around first scan
6. Compute all clues via RuleEngine (handling linked, liar, sum, directional,
   fog, and blocker modifiers)
7. Run Validator; if invalid, increment seed and retry (up to 200 attempts)

### Validation
- Reachable safe area exists
- Clues internally consistent
- Liar tiles solvable through cross-referencing (no isolated liars whose
  offset direction can't be determined)
- Sum tiles solvable (split can be determined through other clues)
- No immediate contradictions
- Optional solver for No-Guess verification
- If solver incomplete: label "No-Guess: Unverified" vs "Verified"

---

## APP SCREENS

1. **Main Menu:** Continue, Campaign, High Scores, Settings, Quit
2. **Campaign / Level Select:** Biomes with progress bars + star counts.
   Inside biome: levels with lock/unlock, best score, star rating.
3. **Game Screen:** Grid, HUD (timer, actions count, score preview, stars,
   shield indicator), pause/restart/new seed, mechanic legend.
   Keyboard: R=restart, N=new seed, Space=pause, Cmd+,=settings, H=help.
   Inputs: left-click=scan, right-click/ctrl-click=tag, shift-click=chord.
4. **End of Level Summary:** Stats, stars earned, next level, replay options.
5. **High Scores:** Global and per-level tabs.
6. **Settings:** Glyphs/Numbers, SFX volume, Ambient volume, Colorblind
   palette, Confirm before New Seed.

---

## PERSISTENCE

Location: Application Support/Revelia/
Files: Settings.json, Progress.json, HighScores.json, SaveGame.json

### Progress Model
- unlockedLevelIds: Set<String>
- completedStatsByLevelId: { levelId: BestStats }
- earnedShieldsByBiome: { biomeId: Bool }
- starsByLevelId: { levelId: Int } (1–3)
- achievements: Set<String>

### SaveGame (Resume In-Progress)
- levelId, seed, timestamp, elapsedTime
- boardState: width/height, hazards, revealed, tags, special tile states,
  linked pair mappings, liar offsets, sum region definitions, terrain

### High Score Entries
- id (UUID), levelId, score, timeSeconds, totalActions, stars, date, seed
- noGuessStatus: verified / unverified / riskAllowed
- shieldUsed: Bool

---

## ARCHITECTURE (MVVM)

### Models
Tile (with subtypes: standard, fogged, linked, liar, sum, directional),
Board, LevelSpec, Biome, GameRules, RunStats, SaveGame, Progress,
HighScoreEntry, Achievement, LinkedPair, SumRegion

### Engine
SplitMix64, BoardGenerator, RuleEngine (dispatches per mechanic type),
CascadeEngine, Validator, Solver (optional)

### ViewModels
GameViewModel (state machine), CampaignViewModel, HighScoresViewModel,
SettingsViewModel

### Views
MainMenuView, CampaignView, GameView, TileView (renders per tile subtype),
LinkedLineOverlay, SumRegionOverlay, HUDView, EndOfLevelView,
HighScoresView, SettingsView

### State Machine
NotStarted → WaitingForFirstScan → Playing → Won
                                            → Lost
                                    → Paused → Playing
