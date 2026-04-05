# Revelia — Pre-Launch Checklist
**Generated:** 2026-03-18
**Status:** Active development — campaign screens complete, entering polish phase
**Based on:** All 13 skill files + full codebase audit

> **How to read this:**
> Items are grouped by domain, then sorted by priority within each group.
> 🔴 = Must fix before App Store submission | 🟡 = Should ship at launch | 🟢 = Nice-to-have / post-launch

---

## 🧹 1. Pre-Ship Code Cleanup

These are things IN the current codebase that must be removed or resolved before release.

- [ ] 🔴 **Remove all debug shortcuts** from `ContentView.swift` before archiving for submission
  - Cmd+Shift+R (reset all progress)
  - Cmd+Shift+U (unlock all)
  - Cmd+Shift+C (clear current level)
  - Cmd+Shift+D (dump records)
- [ ] 🔴 **Remove diagnostic logging** added to `ProgressStore.recordResult` (stack trace printing)
- [ ] 🔴 **Remove `dumpRecords()` method** from `ProgressStore` (or gate behind a compile flag)
- [ ] 🔴 **Remove `backfillPrerequisites()`** from `ProgressStore` — only used by debug shortcut
- [ ] 🔴 **Fix right-click tag cycling bug** — rapid right-clicks require three clicks or a pause (noted in CLAUDE.md Known Bugs; fix is to remove the `clickCount == 1` guard from `rightMouseDown`)
- [ ] 🔴 Verify the `showingHex` fix (just implemented) works correctly in all navigation paths

---

## 🎮 2. Core Game Features (Missing / Incomplete)

Features called out in the spec or skill files that don't yet exist in the codebase.

### Settings System
- [ ] 🔴 **SettingsView** — No settings screen exists. No settings persistence exists. Required features:
  - Glyph / Number toggle (accessibility requirement)
  - Sound on/off (SFX volume + Ambient volume)
  - Colorblind mode toggle
  - Link to Privacy Policy
  - Support email contact
- [ ] 🔴 **Settings persistence** — Store in `Settings.json` in Application Support

### In-Progress Save / Resume
- [ ] 🔴 **SaveGame system** — No in-progress save exists. If the player quits mid-game, all progress on that level is lost. Spec calls for save on every tag/scan (debounced), on pause, on quit, and a "Continue" option at app launch.
- [ ] 🔴 **"Continue" entry point** — App currently always launches to the campaign map. Should check for a saved game on launch and offer to resume.

### Tutorial System
- [ ] 🔴 **Level 1 tutorial tooltips** — No guided onboarding exists. L1 should have 4–5 non-blocking tooltips teaching Scan, Tag, reading a signal, and the win condition.
- [ ] 🔴 **Biome intro tooltips** — Each biome's first level should have 1–2 tooltips explaining the new mechanic. `BiomeIntroOverlay` exists but confirm it's fully wired.
- [ ] 🟡 **Mechanic legend / help popover** — Accessible at any time during gameplay (keyboard shortcut `?` or `H`), showing current biome mechanic description and visual key for special tiles.

### First-Launch Experience
- [ ] 🔴 **Glyph choice screen on first launch** — Show the player a side-by-side preview of Glyph vs. Number mode and let them choose before entering the game. UX skill calls this a must-ship requirement.
- [ ] 🟡 **Brief splash screen** — Revelia logo + tagline (2–3 seconds on first launch).

### Chording
- [ ] 🟡 **Chording (Shift-click)** — Verify this is implemented. Shift-click a revealed tile whose signal count equals adjacent confirmed tags to auto-reveal remaining neighbors. Do NOT tutorial this — let experienced players discover it.

### Casual Shield System
- [ ] 🟡 **Verify Casual Shield is wired end-to-end** — Earned by clearing a biome's first level without mistakes, usable on any subsequent level in that biome. Shield absorbs one hazard hit, forfeits No-Guess bonus, reveals and auto-tags the hazard.

### Board Validator / No-Guess Enforcement
- [ ] 🟡 **Validator.swift** — No board validator exists. Spec calls for rejection of boards with unreachable safe areas. Should retry with incremented seed (up to 200 attempts).
- [ ] 🟡 **No-Guess Solver** — Optional but important: verify each generated board is solvable without guessing before awarding the No-Guess bonus / 3-star rating.

---

## 🎨 3. Art & Visual Assets

### App Icon
- [ ] 🔴 **App icon images are missing** — `AppIcon.appiconset` exists in xcassets but contains NO image files (all slots empty). A real 1024×1024 icon is required for App Store submission. Must be non-transparent, must not look like a mine or flag.

### Tile & Glyph Visual Polish
- [ ] 🔴 **Glyph system implementation** — Verify the game actually displays signal glyphs (pips/runes) by default, not just numbers. `GlyphMapper` utility does not appear to exist as a separate file.
- [ ] 🟡 **Glyph / Number toggle** wired to Settings and respected by TileView
- [ ] 🟡 **Tile visual states** — Verify all states render correctly: Hidden, Revealed, Tagged Suspect, Tagged Confirmed, and all special tile types per biome
- [ ] 🟡 **Hazard tile visual on loss** — Warm amber/rust color (#c0603a), NOT red

### Biome Visuals
- [ ] 🟡 **Biome watercolor images** in xcassets — images exist in `reference/brand/` and imagesets are registered in xcassets, but verify actual image data is assigned to each imageset slot
- [ ] 🟡 **Continent map image** — `ContinentMap.imageset` registered; verify image is assigned

### Animations
- [ ] 🟡 **Tile reveal animation** — Scale 0.95→1.0 + opacity fade (100ms)
- [ ] 🟡 **Cascade wave animation** — Staggered reveal ~30ms between wavefronts
- [ ] 🟡 **Win animation** — Warm glow radiating from last tile (< 2 seconds)
- [ ] 🟡 **Loss animation** — Hazard pulse amber-orange + subtle screen shake

### App Store Screenshots
- [ ] 🔴 **Screenshots not yet created** — Need 5–8 screenshots per size (2880×1800 and 2560×1600). Required before submission.
  - Gameplay in action (Biome 0)
  - A biome mechanic in action (Fog Marsh or Frozen Mirrors)
  - Campaign map screen
  - Victory screen with score
  - Settings / accessibility options

---

## 🔊 4. Sound & Audio

The entire audio system is missing. No `AudioManager`, no SFX, no ambient tracks.

- [ ] 🔴 **AudioManager.swift** — Skeleton singleton with mute support, even if it does nothing. Wire the mute state so Settings "Sound Off" toggle has a real effect.
- [ ] 🔴 **Core gameplay SFX** (source or create):
  - `scan-safe.wav` — tile reveal (satisfying tap)
  - `cascade-start.wav` — 0-signal cascade trigger (tap + rising whoosh)
  - `cascade-wave.wav` — each cascade wave pulse
  - `tag-suspect.wav` — pencil scratch / soft mark
  - `tag-confirmed.wav` — heavier stamp
  - `tag-remove.wav` — light erase
  - `hazard-hit.wav` — sharp alarm (NOT explosion)
  - `level-won.wav` — resonant chime (2–3 seconds)
  - `level-lost.wav` — brief descending tone
- [ ] 🟡 **Special tile SFX** — beacon sonar ping, fog clarify hiss, linked crystalline ping, sonar sweep
- [ ] 🟡 **Ambient tracks per biome** — 9 ambient loops (90–120s, `.m4a` format), one per biome
- [ ] 🟡 **Settings integration** — SFX volume and Ambient volume sliders in Settings
- [ ] 🟡 **Mute when app is in background** — Respect macOS system volume
- [ ] 🟡 **Audio license documentation** — Track all sourced audio in `THIRD-PARTY-LICENSES.md`

---

## ♿ 5. UX & Accessibility

- [ ] 🔴 **Full keyboard navigation** — Arrow keys move tile cursor; Space/Return to scan; F to tag cycle; Escape to pause. macOS users REQUIRE this. Show a visible focus ring on selected tile.
- [ ] 🔴 **Colorblind mode** — Never rely on color alone. Pair every indicator with a shape/icon. Swap red/green → blue/orange with patterns.
- [ ] 🔴 **Reduced Motion support** — Check `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`. When on: cascade reveals instantly, win confetti skipped, no scale animations, no screen shake.
- [ ] 🟡 **VoiceOver accessibility labels** on all interactive elements — menus, buttons, settings toggles. TileView needs `.accessibilityLabel()` describing tile state + grid position.
- [ ] 🟡 **High contrast support** — Check `accessibilityDisplayShouldIncreaseContrast`. Increase tile border thickness, heavier glyph strokes.
- [ ] 🟡 **Dynamic Type / text scaling** — HUD text (timer, score, count) should scale with system text size.
- [ ] 🟡 **Tooltip on hover** over biome mechanic icon or glyph (shows numeric equivalent)
- [ ] 🟢 **Custom key bindings** — Let players remap controls; store in Settings.json

---

## 🧪 6. QA & Testing

- [ ] 🔴 **Unit tests are empty** — `ReveliaTests.swift` is boilerplate only. Minimum required tests:
  - `SplitMix64`: same seed → same sequence, different seeds diverge
  - `BoardGenerator`: dimensions match spec, hazard count matches density, 3×3 safe zone enforced
  - `RuleEngine.getClue`: correct output for each biome variant
  - `CascadeEngine`: cascade stops correctly, never reveals hazards, reveals beacons
  - `ScoringCalculator`: formula matches spec, no-guess bonus, minimum 0 clamp
  - Codable round-trip for all persisted models
- [ ] 🔴 **Manual playthrough — full 148-level campaign** — play every level at least once to catch broken boards, wrong signal counts, or cascade bugs
- [ ] 🔴 **Test on both Intel and Apple Silicon** — crashes on either platform = App Store rejection
- [ ] 🔴 **Test on macOS 13 (minimum target) and macOS 15 (latest)** — verify no API compatibility issues
- [ ] 🟡 **Performance benchmarks** — Board generation (12×12) < 2s, tile reveal + cascade < 100ms, app launch to map < 1s
- [ ] 🟡 **Edge case testing**: minimum board size (6×6) max density; both win condition paths; board with first-scan large cascade; rapid clicking during cascade animation; window resize during gameplay
- [ ] 🟡 **Regression test after every engine change** — BoardGenerator, RuleEngine, CascadeEngine, GameViewModel are high-risk files

---

## 📊 7. Analytics & Player Stats

- [ ] 🟡 **Per-level attempt tracking** — Store `LevelAttemptStats` (outcome, time, scans, score, noGuess, usedCasualShield, etc.) in Progress.json. Currently only best-scores are stored.
- [ ] 🟡 **Aggregate stat computation** — Win rate, first-try win rate, average time per level. Used for difficulty balancing and a future player stats screen.
- [ ] 🟢 **Player Stats screen** — "Total play time, levels completed, win rate, best biome scores" — turns analytics into a feature players appreciate.

---

## ⚖️ 8. Legal & IP

- [ ] 🔴 **Privacy policy published online** — Required by Apple even for zero-data apps. Must be a live URL. Host on GitHub Pages (free). Template in the legal skill.
- [ ] 🔴 **Privacy policy URL in App Store Connect** — Can't submit without it.
- [ ] 🔴 **Audio asset license tracking** — Create `THIRD-PARTY-LICENSES.md` to document all sourced SFX/ambient audio. Required for App Store compliance.
- [ ] 🟡 **Trademark search for "Revelia"** — Search USPTO (tess2.uspto.gov) and App Store before launch. Backup names ready: "Revelia: Logic Extraction" or "Revelia Puzzle."
- [ ] 🟡 **Domain name registration** — Secure `revelia.com`, `.app`, or `.game`
- [ ] 🟡 **Social media handle reservation** — @revelia on Twitter/X before someone else takes it
- [ ] 🟢 **US Trademark filing** — ~$250–350, Class 9. File before or at launch; protection dates back to filing.
- [ ] 🟢 **US Copyright registration** — $65 online, strengthens position against clones.

---

## 🏪 9. App Store Submission Prep

- [ ] 🔴 **Bundle identifier** set: `com.[yourdomain].revelia`
- [ ] 🔴 **App Sandbox entitlements** — Enable App Sandbox + Hardened Runtime in Xcode project settings. Only needs file container access (Application Support). No network, no camera, no location.
- [ ] 🔴 **App version 1.0.0 / Build 1** set in Xcode
- [ ] 🔴 **App Store Connect record created** — App name, category (Games > Puzzle), age rating questionnaire
- [ ] 🔴 **App Store metadata written:**
  - Name: "Revelia" (verify global uniqueness in App Store Connect)
  - Subtitle: "Logic Puzzle · Signal & Extract" (30 char max)
  - Description: hook + gameplay + features + accessibility + differentiators (4000 char max)
  - Keywords: `puzzle,logic,deduction,strategy,brain,grid,campaign,biomes,signals,extraction` (100 char max)
  - Promotional text (170 char, updatable without new version)
- [ ] 🔴 **Age rating questionnaire** completed in App Store Connect — expected 4+
- [ ] 🔴 **Export compliance declaration** — Select "No" for encryption (no networking, no encryption used)
- [ ] 🟡 **TestFlight beta** — Upload at least one build, test on macOS 13 and 15, Intel and Apple Silicon
- [ ] 🟡 **Pricing decision** — Recommended: $2.99–$4.99 paid upfront, no IAP. Simpler review process and no StoreKit implementation needed.
- [ ] 🟡 **Apple Developer account certificates** configured — Mac App Distribution + Mac Installer Distribution

---

## 📣 10. Marketing

- [ ] 🔴 **Support email address** — `revelia@yourdomain.com` or dedicated Gmail. Goes in App Store listing, privacy policy, and in-app Settings. Required at launch.
- [ ] 🟡 **Landing page** — One-page site with: game name + tagline, 3–4 screenshots, "coming to Mac App Store" badge, email signup. Can be GitHub Pages.
- [ ] 🟡 **Press kit** — Fact sheet, short + long description, 5–10 PNGs (uncompressed), 2–3 gameplay GIFs, logo, trailer link. Host on presskit.html or the landing page.
- [ ] 🟡 **Gameplay trailer** — Even a 30–60 second screen recording with music. Shows cascades, biome mechanics, the map.
- [ ] 🟡 **Devlogs (4–6 posts)** — Post to r/indiegaming, r/macgaming, r/puzzlevideogames, IndieDB 4–8 weeks before launch. Show gameplay GIFs and interesting design decisions.
- [ ] 🟡 **Social media accounts** — Reserve @revelia handle on Twitter/X before launch
- [ ] 🟡 **Launch week press outreach** — Email 20–30 outlets and YouTubers who cover puzzle/indie games 2 weeks before launch. Include: hook, trailer link, press kit link, promo code offer.
- [ ] 🟡 **Launch day Reddit posts** — r/macgaming, r/indiegaming, r/puzzlevideogames. Be genuine, show gameplay, don't hard-sell.
- [ ] 🟢 **Product Hunt submission** — Free exposure on launch day.

---

## 🌍 11. Localization (Infrastructure Now, Translation Later)

- [ ] 🟡 **Enable String Catalog in Xcode** — The app currently appears to use hardcoded strings throughout SwiftUI views. Switch to `.xcstrings` String Catalog. SwiftUI `Text()` handles lookup automatically.
- [ ] 🟡 **Use Swift formatters for all numbers/times** — `score.formatted()`, `Duration.seconds(elapsed).formatted(...)` — never manual string formatting (breaks locales like German, French)
- [ ] 🟡 **No fixed-width labels** — German text runs 30% longer than English. All labels must size naturally.
- [ ] 🟢 **Localize App Store metadata** for top 2–3 languages (free, high-impact, no app code needed)
- [ ] 🟢 **Commission translations for top markets** post-launch — Simplified Chinese, Japanese, German (each ~$50–100 for ~200–300 strings)

---

## 🤝 12. Community & Support

- [ ] 🟡 **Bug report guidance in-app** — Add to Settings: "Having an issue? Email [support address] with your macOS version, level, seed, and what happened."
- [ ] 🟡 **App Store review response templates** ready — Prepared responses for: positive review, "it's just Minesweeper," difficulty complaints, legitimate bugs.
- [ ] 🟡 **Seed sharing encouraged** — Ensure the seed is visible in HUD and end-of-level screen so players can share and report reproducible boards.
- [ ] 🟢 **Discord server** — Set up after reaching 50+ engaged players. Channels: #announcements, #general, #bug-reports, #strategies, #seed-sharing.

---

## 🔮 13. Post-Launch / Future Features

These are intentionally deferred and don't block launch.

- [ ] 🟢 **Specimen Collection** — Meta-reward system for 3-star completions. Full design in CLAUDE.md. Build after Task 3b is stable.
- [ ] 🟢 **Daily challenge mode** — One daily board, same seed for all players, leaderboard.
- [ ] 🟢 **Player Stats screen** — In-app analytics display: total time, levels completed, win rate, streaks.
- [ ] 🟢 **iOS port** — Primary future revenue opportunity after Mac App Store launch.
- [ ] 🟢 **Monetization** — Free core + optional rewarded ads + one-time Pro unlock ($4–6). Requires StoreKit 2. Post-launch only.
- [ ] 🟢 **Custom key bindings** — Let players remap controls; store in Settings.json.

---

## 📋 Summary — Launch Blockers

The following are hard requirements for App Store approval. Nothing else matters until these are done:

| # | What | Why It Blocks |
|---|------|---------------|
| 1 | Remove debug shortcuts + diagnostic logging | Shipping dev tools = bad |
| 2 | Fix right-click tag cycling bug | Core interaction is broken |
| 3 | App icon (1024×1024 + all sizes) | Xcode will not archive without it |
| 4 | Privacy policy (live URL) | Apple requires it for all apps |
| 5 | SettingsView with glyph/number toggle + sound on/off | Required for accessibility; Apple may flag |
| 6 | App Sandbox + Hardened Runtime enabled | Required for Mac App Store |
| 7 | App Store metadata + screenshots | Required fields in App Store Connect |
| 8 | Audio: even a muted AudioManager skeleton | App should not be completely silent |
| 9 | Keyboard navigation (arrow keys + space/F) | macOS HIG requirement; Apple tests this |
| 10 | First-launch glyph choice + Level 1 tutorial | App Store rule 4.2: minimum functionality |

---

*Checklist generated by consulting all 13 project skills: game-design, development, qa-testing, art-assets, app-store, project-mgmt, marketing, sound-audio, legal, ux-accessibility, analytics, localization, community-support.*
