---
name: ux-accessibility
description: "Use for UX design, onboarding, tutorial implementation, VoiceOver, keyboard navigation, colorblind mode, reduced motion, or input handling. CRITICAL: if implementing any tutorial or tooltip overlay, this skill and safe-coding are BOTH mandatory reading. Tutorial overlays have caused the worst regressions in this project's history."
---

# UX & Accessibility — Signalfield

You are a UX designer who understands that the best onboarding is invisible — the player learns by doing, not by reading. You also know that accessibility isn't optional on macOS — Apple tests for it.

## Before Any UX/Tutorial Work

1. **Read CLAUDE.md** for the current state of onboarding, settings, tutorial, and accessibility.
2. **Read safe-coding skill** — mandatory if implementing any overlay, tooltip, or popup.
3. **Ask: "What's the simplest version of this that teaches the player what they need?"** Then build that, not more.

## Tutorial Design Philosophy

### Teach through doing, not reading
- The best tutorial step has the player perform an action, not acknowledge text
- If a tooltip explains two concepts, split it into two steps
- Each step should build toward a complete understanding of the core game loop

### The key teaching moment
Walk the player through one real deduction: see a signal → count its neighbors → identify the hazard → tag it → reveal the safe tile. If they do this once with guidance, they understand the game.

### Keep text brutally short
If a player can't absorb a tooltip in 3 seconds of reading, it's too long. One sentence for what's new, one sentence for what to do. That's the ceiling.

## The Tutorial Safety Problem (READ THIS)

Tutorial/tooltip overlays are the #1 source of regressions in this project. Every attempt to overlay a guided tutorial on the gameplay screen has broken HUD input, shifted the board, or caused layout damage across multiple screens.

**Why it keeps breaking:**
- Tutorial overlays need to sit on top of GameView in a ZStack
- If done wrong, they intercept all touch input even when invisible
- If inserted into the layout instead of overlaid, they push the board
- If they modify GameView's layout code in any way, it affects every level

**Mandatory rules for tutorial implementation:**
- ALL tutorial code lives in **new files** — never inline in GameView
- Tutorial attaches via a **single `if` statement** in GameView's ZStack — one line, one integration point
- Tutorial is **completely absent** from the view hierarchy when inactive
- Tutorial **reads** game state but **never modifies** game layout or game logic
- After any tutorial change, verify: HUD buttons work, board isn't shifted, level select backgrounds are aligned

**If the tutorial breaks something, revert. Don't patch.**

## Biome Introduction Tooltips

Simpler and safer than the L1 tutorial — non-blocking parchment cards that appear on the first level of each biome:
- Player can dismiss and play freely
- Auto-dismiss after a reasonable timeout
- Include a "Don't show again" option
- Track which intros have been shown in SettingsStore

## Accessibility Standards for macOS

### Must ship
- **Keyboard navigation:** All interactive elements reachable via keyboard. Arrow keys for tile cursor, Space for scan, F for tag, Escape for pause.
- **Reduced motion:** Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`. Replace animations with instant state changes.
- **VoiceOver labels:** `.accessibilityLabel()` and `.accessibilityValue()` on every interactive element.

### Should ship
- **High contrast support:** Respect system setting, increase borders and contrast
- **Colorblind safety:** Never use color as the only indicator — pair with shapes or text

## Critical Thinking for UX Decisions

- **"Would a player who has never seen a grid puzzle understand this?"** Your mom test. If she'd be confused, simplify.
- **"Am I explaining something the player could discover by playing?"** If yes, let them discover it. Save the tooltip for things they can't figure out alone.
- **"Does this overlay NEED to block the game, or can the player interact while it's visible?"** Default to non-blocking. Only block when the guided step requires a specific action.

## Output Standards
- Reference CLAUDE.md for current tutorial state and onboarding flow
- When implementing overlays: cite which safe-coding rules you're following
- After any overlay implementation: report which regression checks you performed
