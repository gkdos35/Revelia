@AGENTS.md
# Revelia — Master Project Instructions

## About This Project
Revelia is an original macOS logic puzzle game inspired by deduction puzzle mechanics (Minesweeper-like), with a completely original theme, terminology, UI, and rule set. It is a native macOS 13+ app built in Swift 5.9+ with SwiftUI, using MVVM architecture and zero external dependencies.

**Current stage:** Active development — campaign complete, visual polish done, How to Play + biome intros built, specimen collection and audio systems implemented, now in polish / ship-readiness work.
**Platform:** macOS 13+ (Ventura) — native desktop app
**Tech stack:** Swift 5.9+, SwiftUI, SpriteKit (explosion FX), Xcode, MVVM architecture
**Team size:** Solo developer (me) + Claude as co-builder
**Target distribution:** Mac App Store

## Core Identity — NEVER Violate These
- This is NOT Minesweeper. Never use Minesweeper branding, terminology, art, or color schemes.
- Terminology: "Scan" (left click), "Tag" (right click), "Hazards" (not mines), "Signals" (not numbers), "Cascade" (not flood-fill).
- Signal clues are displayed as **Arabic numerals**. (`GlyphMapper.swift` exists in the codebase but is dormant/unused — do not wire it up without explicit instruction.)
- **Win condition:** Player wins when EITHER all safe tiles are revealed OR all hazards have confirmed tags — whichever happens first. There is NO Exit tile.
- **First Scan:** ALWAYS safe. 3×3 safe zone (clicked tile + all 8 neighbors). No exceptions.
- **Chording:** Included. Shift-click a revealed tile whose signal count is satisfied by adjacent confirmed tags to auto-reveal remaining adjacent tiles.
- **Casual Shield:** Earned, not given. Clearing a biome's first level without mistakes earns one shield usable on any subsequent level in that biome. Using a shield reveals the hazard, auto-tags it, and forfeits No-Guess bonus.
- Every playthrough generates a new randomized board from a seed. Levels define parameters, not fixed grids.

## Key Design Decisions (Finalized)
- **Session length:** Escalating — Training Range ~1–2 min, The Delta ~10–15 min
- **After losing:** Full board reveal (all hazards, signals, correct/incorrect tags shown), then SpriteKit chain-reaction explosion animation (~1.7s)
- **Scoring:** Bonus-driven with a 100,000 completion floor. Large score separation comes from fast completion time, action efficiency, clean play (no incorrect confirmed tags), and helper-free play. Difficulty-scaled thresholds use a mix of tile count, safe tile count, hazard count, and mechanic complexity. Excellent runs can approach 1,000,000 points.
- **Cascade rules:** Stops at fogged tiles, locked tiles, and blocker tiles. Reveals beacons and triggers their effects. Linked tiles cascade using their OWN signal (not the displayed partner signal). Sonar tiles cascade only if all directional counts are 0. Standard cascade on normal tiles.
- **Target player:** Casual Puzzler (relaxing, needs onboarding, 2–5 min early sessions)
- **Game feel:** Exciting opening cascade → mounting mid-game tension → satisfying finish
- **Visual direction:** Natural/organic — earth tones, hand-drawn watercolor feel, biomes as real environments
- **Replay features:** Star ratings (1–3), achievement badges, seed sharing, par scores
- **The Delta chapter (L63–L74 square / L137–L148 hex):** Final chapter combining all mechanics from biomes 1–7. Each level layers two or more prior mechanics simultaneously.

## Game State Machine
```
NotStarted → WaitingForFirstScan → Playing → Won
                                           → Lost
                                    → Paused → Playing (resume)
```
- **WaitingForFirstScan:** Board terrain/specials placed, but hazards NOT placed yet. First click triggers hazard placement excluding 3×3 zone around that tile.
- **Playing:** Timer running, inputs active.
- **Won:** All safe tiles revealed OR all hazards have confirmed tags (whichever first).
- **Lost:** Hazard scanned (unless Casual Shield absorbs it). Full board reveal, then explosion animation.

## Board Generation Order
1. Create empty grid from LevelSpec dimensions
2. Place terrain and special tile designations from seed
3. WAIT for first scan
4. Place hazards from seed, excluding 3×3 zone around first scan
5. Compute all clues via RuleEngine
6. Run Validator; if invalid, increment seed and retry (up to 200 attempts)

## Tagging System
Two-stage cycle: None → Suspect (?) → Confirmed (solid ◆) → None
- **Suspect:** Visual marker only, no mechanical effect
- **Confirmed:** Counts toward chord and win condition
- Right-click cycles through states

## Star Ratings
- ★ Complete the level
- ★★ Complete the level, beat the difficulty-scaled decent-time threshold, and place no incorrect confirmed tags
- ★★★ Complete the level, beat the difficulty-scaled fast-time threshold, stay within the difficulty-scaled low-action threshold, place no incorrect confirmed tags, use no helper tools, and use no Casual Shield

Thresholds scale using a mix of tile count, safe tile count, hazard count, and mechanic complexity. Early levels should still require meaningful mastery for 3 stars.

## Keyboard Shortcuts (Gameplay)
| Key | Action |
|-----|--------|
| Arrow keys | Move tile cursor |
| Space / Return | Scan focused tile |
| Shift+Space | Chord (auto-reveal if signal satisfied) |
| F | Tag cycle (none → suspect → confirmed → none) |
| Escape | Pause |

## Performance Targets
- Board generation + validation: < 2 seconds (largest board)
- Tile reveal + cascade: < 100ms
- App launch to home screen: < 1 second

## High-Risk Files
Changes to these files have caused repeated regressions. Exercise extreme caution and always read the `safe-coding` skill first:
- `GameView.swift` — overlays here block input if done wrong
- `HUDView.swift` — changes affect every level
- `LevelSelectView.swift` — background alignment and icon positioning are tightly coupled
- `BiomeSelectView.swift` — map, fog, and pin positioning are interdependent
- `TileView.swift` — tile rendering for all biomes, all grid types, all states

## Game Structure Overview
- 9 Biomes (Training Range → The Delta), 74 square levels + 74 hex levels = 148 total
- Square campaign: L1–L74 (biomes 0–8); Hex campaign: L75–L148 (biomes 9–17, mirroring 0–8)
- Each biome introduces exactly ONE new deterministic mechanic
- The Delta (biome 8) is the confluence chapter — all prior mechanics combined
- Campaign progression with locks/unlocks, per-level leaderboards, save/resume
- Scoring: bonus-driven mastery system with a 100,000 completion floor and large separation for fast, efficient, clean, helper-free clears

## Biome Mechanics (Quick Reference)
| Biome | Name | Mechanic |
|-------|------|----------|
| 0 | Training Range | Baseline (no special mechanic) |
| 1 | Fog Marsh | Fogged Signals — range clues until Beacon clarifies |
| 2 | Bioluminescence | Conductor Pulse — one-use area flash briefly reveals hidden tiles |
| 3 | Frozen Mirrors | Linked Tiles — paired tiles display each other's signal (at least one tile per pair must have non-zero signal) |
| 4 | Ruins | Locked Tiles — tiles locked until enough surrounding neighbors revealed |
| 5 | The Underside | Inverted Signals — tiles show safe-neighbor count, not hazard count |
| 6 | Coral Basin | Sonar Tiles — NSEW directional hazard counts within scan range |
| 7 | Quicksand | Fading Signals — revealed numbers sink; any hidden scan resurfaces them |
| 8 | The Delta | Confluence — all prior mechanics combined in the final chapter |

## Key Rules — Always Follow These
- Never delete any files without my explicit confirmation
- Never modify files outside the designated output folder unless I say so
- Show me your plan before executing any multi-step task
- If unsure about a design decision, present options with tradeoffs — don't guess
- All code must compile. Never output pseudocode when real code is requested
- When writing Swift, follow Apple's API Design Guidelines and Swift style conventions
- Keep the full spec document (`reference/spec/revelia-spec.md`) as the source of truth

## Available Skills
When I ask about **game design** (mechanics, balancing, GDD, biome design, UX flows, puzzle theory), read `.claude/skills/game-design/SKILL.md` first.

When I ask about **development** (Swift code, SwiftUI, architecture, MVVM, Xcode project setup, algorithms), read `.claude/skills/development/SKILL.md` first.

When **fixing bugs, testing, or validating features**, read `.claude/skills/qa-testing/SKILL.md` first. For complex bugs, also use `.claude/skills/systematic-debugging/SKILL.md`. This includes the self-directed diagnose → fix → verify loop — Cowork handles the full investigation in one pass.

When I ask about **art and assets** (visual design, icons, tile graphics, app icon, screenshots, style guide), read `.claude/skills/art-assets/SKILL.md` first.

When I ask about **App Store** (submission, review guidelines, metadata, pricing, TestFlight, certificates), read `.claude/skills/app-store/SKILL.md` first.

When I ask about **project management** (sprints, milestones, priorities, scheduling, status), read `.claude/skills/project-mgmt/SKILL.md` first.

When I ask about **marketing** (press kit, social media, community, launch plan, trailer, devlogs), read `.claude/skills/marketing/SKILL.md` first.

When I ask about **sound and audio** (SFX, music, ambiance, biome soundscapes, AVFoundation, audio sourcing), read `.claude/skills/sound-audio/SKILL.md` first.

When I ask about **legal or IP** (trademark, copyright, privacy policy, EULA, licenses, name protection), read `.claude/skills/legal/SKILL.md` first.

When I ask about **UX or accessibility** (VoiceOver, keyboard navigation, colorblind mode, onboarding, tutorial, reduced motion), read `.claude/skills/ux-accessibility/SKILL.md` first.

When I ask about **analytics or player data** (metrics, retention, playtesting data, balancing from data, player stats), read `.claude/skills/analytics/SKILL.md` first.

When I ask about **localization** (translation, i18n, string catalogs, multi-language support, RTL, locale formatting), read `.claude/skills/localization/SKILL.md` first.

When I ask about **community or support** (Discord, Reddit, player feedback, bug reports from users, patch notes, reviews), read `.claude/skills/community-support/SKILL.md` first.

**Before modifying ANY existing file**, read `.claude/skills/safe-coding/SKILL.md` first. This is mandatory, not optional.

When a task involves **more than 2 files or adds a new system**, read `.claude/skills/task-decomposition/SKILL.md` first. Break large work into small, independently verifiable steps.

When the conversation is about **shipping, launching, or "are we ready"**, read `.claude/skills/release-readiness/SKILL.md` first.

## Folder Structure
```
inbox/              — Drop raw files here for processing
outputs/            — Claude puts finished work here
reference/          — Source-of-truth documents (read-only intent)
  spec/             — The master spec and supporting docs
  brand/            — Logo, palette, typography, style guide
  competitors/      — Competitive research
  apple-guidelines/ — Relevant Apple HIG / review guideline excerpts
archive/            — Completed or superseded work
```

## Visual Design System

### BiomeTheme
Each biome has a `BiomeTheme` struct (`Models/BiomeTheme.swift`) with six properties:
- `tileTextureName` — asset catalog name for the watercolor texture on hidden tiles
- `signalColor` — colour for signal numbers, linked-pair dot indicators, fogged-tile dashed borders (stored opaque; opacity applied at render time)
- `flagAccentColor` — colour for the flag diamond symbol (◆), flagged-tile solid border, and outer glow
- `revealedOverlayColor` — base tint for revealed-tile overlay fills (stored opaque; TileView applies 0.75 opacity for normal tiles, 0.60 for blank/zero-signal tiles)
- `pinColor` — accent colour for biome pins on the campaign map
- `playButtonColor` — background colour for the Play button in the level-select info card

Access via `BiomeTheme.theme(for: biomeId)`. Hex biomes (9–17) reuse square palettes via `biomeId % 9`.

### Tile Rendering
- Hidden tiles: watercolor texture image + optional overlays (fog dashes, linked-pair dot, lock icon, conductor glow)
- Tile textures use an overscale-and-clip technique: image scaled to ~130% of tile size, centered, then clipped to tile shape. This crops edge artifacts from AI-generated images.
- Revealed tiles: watercolor texture at reduced opacity + `revealedOverlayColor` fill + signal number (Arabic numerals, `signalColor`)
- Flagged tiles: solid `flagAccentColor` border (1.5 pt) + outer glow + ◆ diamond symbol
- Hazard tiles (on loss reveal): warm amber/rust `#c0603a` — NOT red. Consistent across all biomes.
- Shape: `TileBackgroundShape` in `TileView.swift` — `RoundedRectangle` for square boards, flat-top hexagon for hex boards

### HUD (HUDView.swift)
Persistent top bar during gameplay:
- **Timer** (elapsed, MM:SS format)
- **Actions counter** (total scans + tags)
- **Hazards remaining** counter
- **Beacon charges** (Fog Marsh only — biome 1)
- **Conductor charges** (Bioluminescence only — biome 2)
- **Score** (live, running total)
- **State indicator** (playing / paused / won / lost)
- **Settings gear** (opens SettingsView sheet)

### Backgrounds
- `WelcomeView`: `welcome-background.png` full-bleed + gradient vignette + 18 floating particles
- `BiomeSelectView`: square campaign uses `ContinentMap`; hex campaign uses `ContinentMapHex`
- `LevelSelectView`: per-biome watercolor image (e.g. `Training Range.png`)
- `SettingsView`: `settings-background.png`

## Welcome / Home Screen (WelcomeView.swift)

The home/title screen is shown **every time the app launches**. There is no auto-advance timer — the player must tap a button to proceed.

**Implementation:**
- `WelcomeView` is a thin wrapper calling `TitleSplashView(onDismiss: onComplete)`
- `TitleSplashView` is also reused by the home button in `BiomeSelectView` so the player can return to this screen from the map
- `RootView` controls flow: `showingHome: Bool = true` starts true on every launch

**Layout (GeometryReader-based, centered):**
- Full-bleed `WelcomeBackground` image + gradient vignette
- `ParticleFieldView` — 18 non-interactive floating white circles, animated drift loop
- Hero logo: `ReveliaLogo` image, `geo.size.width * 0.55` wide
- Tagline: "Think. Solve. Don't explode."
- Four meadow-green buttons (220×44 pt, `#7AAA58`, cornerRadius 8):
  - **Play / Continue** (adaptive — "Continue" if any level is completed)
  - **Settings** (opens `SettingsView` sheet)
  - **How to Play** (opens `HowToPlayView` sheet — 6-page parchment guide)
  - **High Scores** (opens the local leaderboard flow)
- Play/Continue has a scale press animation (0.97 on tap)

**hasProgress logic:**
```swift
progressStore.data.levelRecords.values.contains { $0.completed }
```

## Settings System (SettingsStore.swift)

`SettingsStore` is a `final class ObservableObject` persisting to `settings.json` in Application Support.

**Persisted settings:**
- `backgroundMusicEnabled: Bool` (default `true`)
- `gameSoundsEnabled: Bool` (default `true`)
- `shownBiomeIntros: [Int]` — biome IDs where the player has tapped "Don't show again" on the mechanic intro sheet

**Access points:**
- Settings gear in HUDView (during gameplay)
- Settings button on WelcomeView (home screen)
- Settings button on BiomeSelectView (campaign map top bar)

`SettingsView` displays separate toggles for background music and game sounds, a reset-progress action that also clears local leaderboards, and a privacy-policy link.

## How to Play (HowToPlayView.swift)

A 6-page swipeable parchment guide presented as a `.sheet` from WelcomeView. Teaches core mechanics through large visual illustrations with minimal text. Uses Training Range tile textures from BiomeTheme for illustrations.

**Pages:** The Field → Scanning (+ cascade mention) → Reading Signals → Deduction (the key page) → Tagging → Winning

**Navigation:** Next/Back buttons (not swipe — swipe doesn't work well on macOS). Styled warm brown parchment buttons. Custom page indicator dots (warm brown). Close button (✕) on every page. "Start Playing" button on the last page.

**Architecture:** Completely self-contained in HowToPlayView.swift. Presented as a sheet — zero interaction with GameView or any game logic. This is intentional: a previous interactive tutorial overlay caused repeated layout regressions and was removed.

## Biome Mechanic Intros (BiomeMechanicView.swift)

Per-biome mechanic explanation pages presented as a `.sheet` when the player enters the first level of a new biome. Same parchment visual style and Next/Back navigation as How to Play.

**Content:** One or two pages per biome explaining the new mechanic with illustrations. Fog Marsh (2 pages), Bioluminescence (1), Frozen Mirrors (2), Ruins (1), The Underside (1), Coral Basin (1), Quicksand (1), The Delta (1).

**Dismissal:** "Got it" button dismisses the sheet. "Don't show again" checkbox stores the biome ID in `SettingsStore.shownBiomeIntros`.

**Architecture:** Presented as a `.sheet` from the game screen container — NOT a ZStack overlay on GameView. This is a hard rule. Sheets are managed by SwiftUI independently and cannot affect GameView's layout or touch handling.

**Important lesson learned:** An interactive tutorial overlay (spotlight + tooltips on live gameplay) was attempted and removed after causing cascading regressions across the app. The overlay approach fundamentally conflicted with the AppKit/SwiftUI hybrid view hierarchy used by BoardInputView. The sheet-based approach is architecturally safe and must not be changed to an overlay.

## Architecture Quick Reference

### Models
- `Models/GridGeometry.swift` — `GridGeometry` protocol + `SquareGridGeometry` + `HexagonalGridGeometry`
- `Models/Board.swift` — `gridShape`, `geometry`, `neighbors(of:)`, `sonarBeams(from:)`
- `Models/LevelSpec.swift` — Level parameters; `gridShape: GridShape = .square`; `mechanicHint` computed property
- `Models/BiomeTheme.swift` — Per-biome visual palette (6 colour/texture properties)
- `Models/TileExplosionData.swift` — Particle data for SpriteKit explosion FX
- `Models/RunStats.swift` — End-of-run statistics (score, time, stars, noGuess, shieldUsed)

### Engine
- `Engine/BoardGenerator.swift` — Uses `board.geometry` for all placement logic
- `Engine/RuleEngine.swift` — Uses `board.neighbors(of:)` and `board.sonarBeams(from:)`
- `Engine/CascadeEngine.swift` — Uses `board.neighbors(of:)` for BFS
- `Engine/ScoringCalculator.swift` — Implements the scoring formula

### Persistence
- `Persistence/ProgressStore.swift` — `@MainActor final class ObservableObject`; JSON to Application Support; per-level and per-biome records
- `Persistence/SettingsStore.swift` — `final class ObservableObject`; JSON to Application Support; `backgroundMusicEnabled`, `gameSoundsEnabled`, `shownBiomeIntros`
- `Persistence/SpecimenStore.swift` — specimen unlock persistence to `specimens.json`
- `Persistence/LeaderboardStore.swift` — local top-10 score/time leaderboards per level

### Views
- `Views/RootView.swift` — Top-level navigation (`showingHome` → `WelcomeView` → `BiomeSelectView` ↔ `ContentView`)
- `Views/WelcomeView.swift` — Home screen (`TitleSplashView` + `ParticleFieldView`)
- `Views/BiomeSelectView.swift` — Campaign map with subtractive fog, biome pins, globe toggle
- `Views/LevelSelectView.swift` — Per-biome level picker with watercolor background and parchment info cards
- `Utilities/BiomeLevelLayout.swift` — Hand-placed normalized coordinates for level circles on each biome's painted path
- `Views/ContentView.swift` — Container holding `GameView` + `HUDView` + end-of-run overlays
- `Views/GameView.swift` — Board rendering; dispatches to VStack/HStack (square) or ZStack+position (hex)
- `Views/TileView.swift` — Individual tile; `TileBackgroundShape` handles square vs hex shape
- `Views/BoardInputView.swift` — Mouse event routing; hex hit-testing via `HexagonalGridGeometry.coordinate(at:)`
- `Views/HUDView.swift` — Top-bar HUD (timer, actions, hazards, charges, score, state, settings gear)
- `Views/EndOfLevelView.swift` — Post-run overlay (frosted-glass card, star bloom, score countup, biome particles)
- `Views/BiomeCompleteView.swift` — Biome-final level summary screen (total stars, "Return to Map")
- `Views/HowToPlayView.swift` — 6-page swipeable parchment guide (presented as sheet from WelcomeView)
- `Views/BiomeMechanicView.swift` — Per-biome mechanic intro (presented as sheet on first level of each biome)
- `Views/SpecimenCabinetView.swift` — specimen collection hub with one biome card per cabinet section
- `Views/BiomeDisplayRoomView.swift` — per-biome specimen display room
- `Views/BoardExplosionView.swift` — SwiftUI wrapper that hosts the SpriteKit explosion scene
- `Views/SonarPulseOverlay.swift` — Animated directional pulse rings; uses `board.geometry.tileOrigin()`
- `Views/SettingsView.swift` — Settings modal (sound toggle, reset progress)

### Audio
- `Audio/AudioManager.swift` — central music/SFX service
- `Audio/AudioScreen.swift` — maps app screens to background-music tracks
- `Audio/AudioAssets.swift` — canonical asset-name mapping for music and sound effects

### Dormant / Unused
- `GlyphMapper.swift` — Maps signal values to glyph/pip characters. **Currently unused** — `TileView.swift` renders Arabic numerals directly. Do not wire up without explicit instruction.

## GridGeometry Architecture

The board engine is grid-shape–agnostic thanks to the `GridGeometry` protocol and two concrete implementations in `Models/GridGeometry.swift`.

### Overview

Grid coordinates use `(row: Int, col: Int)` — row 0 is top.

`GridGeometry` abstracts all topology-dependent operations — neighbor calculation, sonar beams, distance, edge/corner detection, lock thresholds, and rendering layout — behind a single protocol. Callers never branch on grid shape; they simply call `board.neighbors(of:)` or `board.geometry.tileOrigin(at:)` and get the correct result for whatever grid shape the board was created with.

### Two Supported Shapes

| Value | Type | Neighbors | Sonar beams |
|-------|------|-----------|-------------|
| `GridShape.square` | `SquareGridGeometry` | Up to 8 (diagonal + orthogonal) | 4 (N/S/E/W) |
| `GridShape.hexagonal` | `HexagonalGridGeometry` | Up to 6 | 6 (N/NE/SE/S/SW/NW) |

Hex grids use **flat-top** orientation with **odd-q offset** coordinates (odd columns shifted down by half a hex height). `HexagonalGridGeometry` internally converts to cube coordinates for mathematically clean distance calculation.

### Key API Pattern

```swift
// Always use board.neighbors(of:) — never coord.neighbors(boardWidth:boardHeight:)
let neighbors = board.neighbors(of: coord)        // 8 for square, 6 for hex

// Access geometry for distance, edge/corner classification, and layout
let geo = board.geometry
let origin = geo.tileOrigin(at: coord, tileSize: ts, spacing: sp)
let dist   = geo.distance(from: a, to: b)

// Sonar beams are geometry-aware (4 or 6 beams)
let beams = board.sonarBeams(from: coord)
```

### Adding the Grid Shape to a Level

All existing levels default to `.square` (the `gridShape` property on `LevelSpec` has a default value of `.square`). To create a hexagonal level, set `gridShape: .hexagonal` in the `LevelSpec` initializer — everything else (board generation, cascade, rule engine, rendering) adapts automatically.

## End-of-Level Flow

### Victory
`EndOfLevelView` shows a frosted-glass collapsible card with:
- Star bloom animation (1–3 stars fill in sequence)
- Score countup animation
- Biome-themed particle burst
- Stats: time, actions, best score, best time
- Buttons: **Next Level** (mid-biome) or **Return to Map** (biome-final)
- **Retry** always available

### Loss
- Full board reveal: all hazards exposed, signals shown, correct/incorrect tags coloured
- SpriteKit chain-reaction explosion animation (~1.7s, supports both square and hex boards)
- Post-explosion: `EndOfLevelView` card appears with **Retry** and **Return to Map** buttons

### Biome-Final Levels
When the player completes the last level of any biome (`BiomeCompleteView`):
- Biome name + total stars earned across all levels in the biome
- Congratulatory message
- Single button: **Return to Map** → navigates to `BiomeSelectView`

Biome-final level IDs: L6, L14, L22, L30, L38, L46, L54, L62, L74 (square); L80, L88, L96, L104, L112, L120, L128, L136, L148 (hex)

## Level Select Screen (LevelSelectView.swift)

### Layout
Each biome's level select screen uses a fitted watercolor artwork canvas with level icons placed at hand-authored normalized coordinates from `BiomeLevelLayout.swift`. The header stays fixed above the artwork area and the info card is positioned relative to the selected node.

### Layout Edit Workflow
`LevelSelectView` includes a lightweight coordinate-edit mode for repositioning nodes:
- **Cmd+Shift+L** — toggle layout edit mode
- Drag nodes visually on the biome art
- **Cmd+Shift+C** — copy the current biome's normalized `CGPoint` array to the clipboard
- Paste the exported array back into `Utilities/BiomeLevelLayout.swift`

Hex biomes intentionally reuse the same layout arrays as their square counterparts via `biomeId % 9`.

### Circle States
- **Locked:** faint translucent circle (~30% opacity), no level number, not interactive
- **Unlocked (not completed):** animated glow/pulse, shows level number, tappable
- **Completed:** solid filled circle by star rating — 1★ bronze `#CD7F32`, 2★ silver `#C0C0C0`, 3★ gold `#FFD700` — level number inside, small star indicators below

### Info Card (Parchment Pop-Up)
Tapping a circle expands a parchment-toned semi-transparent card (one at a time; tap elsewhere to collapse):
- Level number and name
- Mechanic hint (see below)
- Stars earned, best score, best time
- **Play** button (styled with `BiomeTheme.playButtonColor`)

### Mechanic Hint (`LevelSpec.mechanicHint`)
- **Training Range (biome 0):** Returns `""` — no mechanic row shown
- **Biomes 1–7:** Fixed short description (e.g. "Fogged tiles, beacon charges")
- **The Delta (biome 8 / 17):** Dynamic comma-separated list of active mechanics for that level, using short names: Fog, Pulse, Linked, Locked, Inverted, Sonar, Fading

The mechanic hint row in the card is conditionally rendered — hidden when `mechanicHint.isEmpty`.

## Campaign Map (BiomeSelectView.swift)

### Map Foundation
- Square campaign uses `ContinentMap`; hex campaign uses `ContinentMapHex`
- Subtractive fog: a single white fog layer (~0.80–0.85 opacity) covers the entire map; unlocked biome regions are punched out as holes using even-odd path clipping with Gaussian blur on edges
- Biome region boundary paths defined in code; adjacent biomes share identical edge coordinates (no gaps, no overlaps)

### Biome Pins
- **Locked:** lock icon, dimmed name
- **Unlocked:** white circle with coloured border (`BiomeTheme.pinColor`), biome name in white with shadow, tappable
- **Completed:** subtle golden glow on pin
- Hover/tap shows star count tooltip
- Hex campaign: pin shapes are hexagonal; square campaign: circular pins

### Campaign Toggle (Map Button)
Replaces the old segmented `Picker`. Implemented as a floating 58×58 pt circle button in the bottom-right corner:
- Background: `LevelIconBackground` watercolor texture, `scaledToFill` + `scaleEffect(1.30)` clipped to circle (crops painted border, same technique as level markers)
- Preview image shows the **destination** campaign, not the active one
- In square mode, the button shows the hex map preview with a large centred `H`
- In hex mode, the button shows the square map preview with no overlaid letter
- White circular border
- Scale pulse (to 1.05 then back) on tap
- **Only visible when `hexCampaignVisible`** (`progressStore.isCompleted("L74")`)

### Top Bar
- Biome title (left)
- Home button (returns to WelcomeView)
- Settings button (right)

### Hex Campaign Gating
The entire hex campaign (L75–L148) is locked until L74 is completed. `ProgressStore.isUnlocked(_:)` enforces:
- L1: always unlocked
- L75: unlocked only when L74 is completed
- All others: require previous level completed

### Biome Reveal Sequence (on return after biome completion)
Cinematic ~5s animation triggered by `RevealTrigger` passed from `ContentView` via `RootView`. Player can tap away at any time.

1. **Pause (0.5s):** Map renders with new biome still fogged
2. **Camera pan (~1s):** Smooth scroll to center newly unlocked region (easeInOut; skip if already centred)
3. **Fog dissolve + golden shimmer (~2s):** Fog over region fades (opacity 0.6 → 0) + warm golden pulse
4. **Text banner (~1.5s):** "[Biome Name] Unlocked!" fades in centred on screen, then fades out
5. **Pin appears:** Scales from 0 to full size with slight bounce; biome becomes interactive

**L74 / L148 (final levels):** No new biome — show "Campaign Complete!" banner with golden shimmer across the entire map.

### Biome Positions on Map (North to South)
- Frozen Mirrors: top centre (snowy peaks)
- Fog Marsh: upper left (misty teal coast)
- Ruins: upper right (sandy stone foothills)
- Training Range: centre (bright green meadow) — larger pin, campaign start
- Bioluminescence: left/centre-left (dense dark forest)
- The Underside: right/centre-right (dark cave in cliffs)
- Coral Basin: lower left (pink tropical shore)
- Quicksand: lower right (amber desert)
- The Delta: bottom centre (river meets ocean)

## What I'm Working On Right Now
- Phase: Polish and ship-readiness
- Current: Specimen collection polish, campaign-map polish, level icon layout cleanup, settings/accessibility improvements
- Next: Remove debug shortcuts, add UI smoke tests, add reduce-motion support, finish release checklist
- Blockers: Final visual QA across map / level-select / specimen screens and broader pre-ship hardening

### Version Control
The project uses git (initialized March 2026). Always commit after successful changes. Use `git diff` to diagnose regressions. Do not use destructive revert commands casually; inspect diffs first and preserve intentional local changes.

### Specimen Collection

A meta-reward system that gives 3-star finishes tangible meaning and drives replayability. This system is now implemented and in visual-polish mode.

**Core mechanic:**
- Each level has a unique specimen (creature or plant native to that biome)
- Earning 3 stars on a level unlocks that level's specimen
- Fully 3-starring every level in a biome earns a special rare specimen for that biome
- Total collectibles: up to 148 level specimens + 18 biome specimens (9 square + 9 hex) = 166

**Cabinet UI:**
- Accessed from the bottom-left button on the biome select screen
- `SpecimenCabinetView` shows one biome card per cabinet section
- `BiomeDisplayRoomView` shows the collected specimens for an individual biome
- Cabinet cards currently use translucent parchment styling over the cabinet background art
- Each collected specimen displays: image + name
- Uncollected specimens are completely hidden — the cabinet grows as the player discovers
- Players don't know how many specimens exist or what's coming next

**Specimen theming (per biome):**
- Training Range: common meadow creatures and wildflowers
- Fog Marsh: bog creatures, amphibians, marsh plants
- Bioluminescence: glowing insects, fungi, deep-forest flora
- Frozen Mirrors: arctic creatures, ice crystals, frost-adapted plants
- Ruins: fossils, ancient insects, stone-clinging moss and lichen
- The Underside: cave creatures, bats, subterranean fungi
- Coral Basin: sea creatures, coral varieties, shore plants
- Quicksand: desert creatures, cacti, heat-adapted species
- The Delta: rare hybrid species combining traits from multiple biomes

**Persistence:**
- `SpecimenStore.swift` — separate ObservableObject persisting to `specimens.json` in Application Support
- Tracks `unlockedSpecimenIds: Set<String>`
- Specimen unlock triggers when a level result is recorded with 3 stars
- Rare biome specimen unlocks when all level specimens in that biome (square or hex) are collected

### Known Bugs
- **Frozen Mirrors L23 zero pairs:** Generator should enforce pair count as hard minimum (retry generation if requirement not met) — verify this is working in testing
- **Reveal pin appears early:** Newly unlocked biome's pin was visible immediately on map load, then disappeared, then reappeared after shimmer. Fix: force pin hidden until Step 5 of reveal sequence regardless of `isUnlocked` state
- **Fog architecture — per-region overlaps/gaps:** REDESIGNED. Switched to subtractive fog approach — single fog layer covers entire map, unlocked regions subtracted as holes. See Campaign Map section above.

### Debug Shortcuts (Remove Before Release)
- **Cmd+Shift+R** — Reset all progress (wipe JSON, return to fresh state)
- **Cmd+Shift+U** — Toggle unlock-all mode (runtime only, no file changes)
- **Cmd+Shift+C** — Clear current level (marks complete with 3 stars, advances to next level or returns to map if end of biome)
- **Cmd+Shift+D** — Dump all level records to console (sorted by level number)

### App Store Preparation
- **Bundle ID:** `com.[yourdomain].revelia` (update when domain secured)
- **Category:** Games → Puzzle
- **Pricing:** Paid upfront ($2.99–$4.99), no IAP — simplest review process
- **App Sandbox:** App Container file access only. No network, camera, location, or special hardware.
- **Export compliance:** No encryption (no networking) — select "No"
- **Age rating:** Expected 4+ (no violence, mature content, or gambling)

### Privacy Policy
Revelia is currently local-first:
- no account system
- no in-app third-party analytics or telemetry SDKs
- no advertising SDKs
- no cross-app tracking
- gameplay/settings/progress data stored locally on device

Draft privacy policy assets now exist:
- `reference/privacy-policy.md` — editable source draft
- `reference/privacy.html` — simple hostable static page

Still required before ship:
- replace placeholders with real developer/studio name
- replace placeholders with real privacy/support email
- replace placeholders with real website URL
- host the privacy policy at a live public URL
- update the in-app Settings privacy-policy link to that final URL
- enter the same final URL in App Store Connect

### Audio
An implemented audio system now exists.

**Current behavior:**
- `AudioManager` owns background music and sound-effect playback
- `AudioScreen` maps app screens to music tracks (home, biome map, gameplay, victory, loss)
- `SettingsStore` independently controls `backgroundMusicEnabled` and `gameSoundsEnabled`
- Audio is synchronized from `ReveliaApp` and screen transitions in `RootView` / `BiomeSelectView`

**Still to finish:**
- Accessibility and comfort improvements, especially Reduce Motion / audio polish alignment
- Final asset-completeness audit
- Optional future work: music and SFX volume sliders
- All sourced audio must be tracked in `THIRD-PARTY-LICENSES.md` with license verification

### Release Notes for Future Claude Sessions
- Campaign map now has separate square and hex continent art assets
- The map toggle button previews the destination world, not the current one
- Level icon coordinates are maintained in `Utilities/BiomeLevelLayout.swift`; hex and square share the same arrays
- `LevelSelectView` has a built-in coordinate edit/export workflow for layout tuning
- Specimen collection UI is live; collection hub and per-biome display rooms are no longer placeholder work
- Settings now distinguish between background music and game sounds

### Future Features
- **Save/resume system** — Not started. Currently quitting mid-level loses all progress on that level.
- **Daily challenge mode** — One daily board, same seed for all players, time/score leaderboard display
- **iOS port** — Primary revenue opportunity after Mac launch
- **Monetization** — Free core game + optional rewarded ads + one-time Pro unlock ($4–6, removes ads)
