# Revelia — Shared Agent Instructions

## Project identity
Revelia is an original native macOS logic puzzle game built in Swift 5.9+ with SwiftUI, using MVVM architecture and zero external dependencies.

This is NOT Minesweeper. Never use Minesweeper branding, terminology, art, or color schemes.

Platform: macOS 13+  
Primary toolchain: Xcode, SwiftUI, Swift 5.9+  
Distribution target: Mac App Store

## Source of truth
The master spec is the source of truth:

- `reference/spec/revelia-spec.md`

Use the spec and existing code before proposing behavior changes.

## Core game rules that must not be violated
- Terminology:
  - Scan = left click
  - Tag = right click
  - Hazards = not mines
  - Signals = not numbers
  - Cascade = not flood-fill
- Signal clues are displayed as Arabic numerals.
- Win condition: player wins when either all safe tiles are revealed OR all hazards have confirmed tags.
- First Scan must always be safe with a 3×3 safe zone around the clicked tile.
- Chording is included.
- Casual Shield is earned, not given.
- Boards are generated from seeds; levels define parameters, not fixed layouts.

## Working rules
- Show a short plan before any task that touches more than 1 file.
- Prefer minimal, compiling changes.
- Never delete files without explicit approval.
- Never modify files outside the intended scope of the task.
- Do not change core game rules unless explicitly asked.
- If unsure about a design decision, present options with tradeoffs instead of guessing.
- When real code is requested, provide real code, not pseudocode.
- Before finalizing, verify that edits are internally consistent with existing architecture.

## File safety rules
Treat these as high-risk files and change them cautiously:
- `GameView.swift`
- `HUDView.swift`
- `LevelSelectView.swift`
- `BiomeSelectView.swift`
- `TileView.swift`

Do not modify `reference/` or `archive/` unless explicitly asked.  
Treat `outputs/` as a workspace/output area, not core app source.

## Required reading before work
Before modifying any existing code, read:

- `.claude/skills/safe-coding/skill.md`

Use these additional skills when relevant:
- Bug fixing / testing:
  - `.claude/skills/qa-testing/skill.md`
- Complex debugging:
  - `.claude/skills/systematic-debugging/SKILL.md`
- Tasks touching more than 2 files or adding a new system:
  - `.claude/skills/task-decomposition/skill.md`
- Swift / SwiftUI / MVVM / Xcode work:
  - `.claude/skills/development/skill.md`
- Game design / mechanics / balancing:
  - `.claude/skills/game-design/skill.md`
- UX / accessibility review:
  - `.claude/skills/ux-accessibility/skill.md`
- Project planning, milestones, or sprint shaping:
  - `.agents/skills/project-mgmt/skill.md`
- Shipping readiness, launch blockers, or release checklists:
  - `.agents/skills/release readiness/skill.md`
- Xcode builds, scheme checks, and compile verification:
  - `.agents/skills/xcode-build-verify/SKILL.md`
- Art direction, asset generation, icons, or visual polish:
  - `.agents/skills/art-assets/skill.md`
- Sound design, music, SFX planning, or audio implementation:
  - `.agents/skills/sound-audio/skill.md`
- App Store prep, metadata, pricing, or submission work:
  - `.agents/skills/app-store/skill.md`
- Marketing, launch messaging, trailers, press kit, or devlogs:
  - `.agents/skills/marketing/skill.md`
- Legal or IP questions such as trademark, copyright, or policy needs:
  - `.agents/skills/legal/skill.md`
- Localization, string workflow, or multilingual release prep:
  - `.agents/skills/localization/skill.md`
- Analytics, player metrics, or balancing from player data:
  - `.agents/skills/analytics/skill.md`
- Community management, support replies, patch notes, or review handling:
  - `.agents/skills/community-support/skill.md`
- Skill audits or prompt-playbook reviews:
  - `.agents/skills/skill-reviewer/SKILL.md`

## Architecture guardrails
- Respect MVVM structure.
- Respect the existing grid-shape abstraction (`GridGeometry`, square + hex support).
- Do not wire up dormant/unused systems unless explicitly asked.
- Do not replace sheet-based tutorial/mechanic intro presentation with overlay-based approaches unless explicitly asked.
- Preserve the current terminology, visual direction, and puzzle identity.

## Scoring / Stars Guardrail
- Completed runs have a 100,000 score floor, with large bonus-driven separation for mastery play.
- Major score separation should come from fast completion time, action efficiency, clean play, and helper-free play.
- 3-star clears must require all-of-the-above performance: fast time, low actions, no incorrect confirmed tags, no helper-tool use, and no Casual Shield use.
- Do not simplify the scoring/star system back to narrow-range scoring or easy 3-star gates unless explicitly asked.

## Current project focus
Current development focus is Specimen Collection:
- Step 1: data model + catalog + persistence
- Steps 2–3: unlock triggers + cabinet UI

Other current priorities include:
- audio system
- save/resume
- launch blockers
- level select icon alignment polish

## Privacy policy status
- Draft privacy policy text exists at `reference/privacy-policy.md`.
- Draft hostable static page exists at `reference/privacy.html`.
- Current policy position: Revelia is local-first, stores gameplay/settings data locally on device, and currently has no in-app third-party analytics, telemetry, ads, or account system.
- Still required before ship:
  - fill in developer/studio name
  - fill in privacy/support email
  - fill in website URL
  - host the policy at a live public URL
  - update the in-app Settings privacy-policy link to the final URL
  - use the same final URL in App Store Connect

## Build / verification expectations
- Use the existing Xcode project in this repository.
- Inspect the available project/scheme configuration before making build-specific assumptions.
- For code changes, prefer a small edit → verify → refine loop.
- If a task may affect app-wide UI behavior, explicitly call out regression risk.

## Version control
- Review existing diffs before making broad edits.
- Prefer small, reviewable commits.
- If a fix fails, diagnose before attempting a broader rewrite.

## What a good response looks like in this repo
A good response for this project usually:
1. states the plan briefly,
2. identifies files to inspect or change,
3. makes the smallest viable change,
4. explains risks/regression areas,
5. suggests how to verify in Xcode.

## Skill review integration

- When asked to audit, score, improve, refactor, or re-evaluate any skill file or prompt-playbook workflow in this repo, use the `skill-reviewer` skill.
- Prefer critique first, then the smallest useful amendment plan, and only do a full rewrite when the file is fundamentally weak or the user explicitly asks for one.
- Preserve the original purpose of a skill unless the user asks to change its purpose.
- Preserve strong existing constraints, anti-goals, and "what this is not" sections unless replacing them with an explicitly stronger equivalent.
- When reviewing a skill, produce:
  1. a 10-category scorecard,
  2. the total score out of 20,
  3. the top 3 highest-leverage fixes,
  4. either a targeted patch or a full revised draft,
  5. a short changelog explaining why each change improves reliability.
- If the proposed changes replace most of the body, classify the result as a full revised draft rather than a targeted patch.
- Favor small, surgical improvements over large rewrites.
- Move long examples to `examples.md` and bulky support material to `references/` when that improves maintainability.
