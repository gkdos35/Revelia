---
name: safe-coding
description: "ALWAYS read before modifying ANY existing Swift/SwiftUI file. Contains project-specific failure patterns, mandatory safety checks, and known regression traps. If your task touches GameView, HUDView, LevelSelectView, TileView, or BiomeSelectView — or adds any overlay, popup, or conditional view — this skill is NON-NEGOTIABLE."
---

# Safe Coding — Signalfield

Read this before modifying any existing file. These rules exist because every one of these mistakes has happened on this project — most of them more than once.

## Before You Write Any Code

**Stop and answer these questions:**
1. Which existing files will I need to modify? (List them.)
2. For each file: what else depends on it? What screens use it?
3. Could my change affect layout, sizing, positioning, or touch targets on ANY screen — even screens I'm not working on?
4. Can I accomplish this by creating NEW files instead of modifying existing ones?

If you're unsure about #3, **ask before proceeding.** Guessing has caused every major regression on this project.

## Gotchas — These Have Broken the App Before

### The Overlay Trap (caused 4+ regressions)
Adding overlays (tutorials, tooltips, popups, modals) to GameView is the single highest-risk change in this project. Every attempt has broken HUD input, shifted the board, or blocked touch across the entire app.

**What goes wrong:** A view added for the overlay stays in the view hierarchy even when invisible, intercepting all touches. Or the overlay is inserted into a VStack/HStack instead of a ZStack, pushing existing content.

**The rule:**
```swift
// ONLY acceptable pattern for overlays:
ZStack {
    ExistingContent()  // NEVER modify this
    if shouldShowOverlay {  // MUST use if, not opacity/hidden
        OverlayView()
    }
}
```
- `.opacity(0)` and `.hidden()` still intercept touches. Use `if` statements.
- The overlay must be **completely absent** from the view tree when inactive.
- After adding an overlay, test that HUD buttons work on 3+ different levels with the overlay NOT active.

### The Image Scaling Trap (caused 2+ regressions)
LevelSelectView has hand-placed level icons positioned on top of a watercolor background. The coordinates are normalized to the image dimensions. Any change to how the image scales breaks every icon position.

**What goes wrong:** A seemingly unrelated layout change (padding, frame, GeometryReader) causes the background image to scale differently. All level icons slide off the painted paths.

**The rule:** Never modify `.frame()`, `.scaledToFill()`, `.aspectRatio()`, `.padding()`, or any sizing modifier on LevelSelectView's background image unless that is the *explicit and sole purpose* of the task.

### The Patch-on-Patch Trap (caused tutorial to become unfixable)
When a fix doesn't work, applying another fix on top creates compounding damage that's harder to diagnose than the original bug.

**The rule:** After two failed attempts at the same bug, **STOP.** Paste the relevant code, explain what you tried, and ask for guidance. Do not try a third approach without approval.

## Mandatory Checklists

### Pre-Change (before writing code)
- [ ] Listed all files I will modify
- [ ] For each: identified what other screens/views depend on it
- [ ] Confirmed I'm not changing layout/sizing modifiers on anything I shouldn't be
- [ ] If adding an overlay: confirmed it uses ZStack + `if` pattern
- [ ] If this could be done in a new file instead: doing it in a new file

### Post-Change (before reporting done)
- [ ] App launches without crashing
- [ ] HUD buttons (pause, gear) are tappable during gameplay
- [ ] The screen I changed renders correctly
- [ ] At least 2 OTHER screens still render correctly (spot check)
- [ ] No unexpected dark overlays or blocked input anywhere
- [ ] Listed all files I modified in my response

## When Something Breaks

If your change broke something:
1. **Revert it.** Don't fix-forward.
2. Report what happened.
3. Propose a different approach that avoids the breakage.

If you can't figure out what's wrong:
1. Paste the relevant code (the actual modifier chain, not a summary).
2. Describe what you expected vs what happened.
3. Ask for help. This is not a failure — it prevents bigger failures.
