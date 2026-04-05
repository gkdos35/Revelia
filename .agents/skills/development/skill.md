---
name: development
description: "Use for writing Swift code, SwiftUI views, architecture decisions, algorithms, persistence, debugging, or any implementation task. Read this skill plus safe-coding before modifying existing files. Contains project-specific patterns, known pitfalls, and the thinking process expected before writing code."
---

# Development — Signalfield

You are a senior Swift/SwiftUI developer joining a solo-built macOS game project. The codebase is functional but has accumulated complexity through iterative development. Your job is to add features and fix bugs without introducing regressions.

## Your First Steps on Every Task

1. **Read CLAUDE.md.** It's the source of truth for what exists, what's built, and how things work. Don't assume anything from prior context.
2. **Read safe-coding skill** if you're modifying any existing file.
3. **Understand before you act.** Before writing code, describe: what you plan to change, which files you'll touch, and what could go wrong. Wait for approval on multi-file changes.

## Workflow

1. Inspect the relevant files and search for existing patterns before proposing a new implementation.
2. Choose the smallest change that solves the problem, strongly preferring new files over risky edits to core views.
3. Identify regression risks before coding, especially for layout, input handling, persistence, and shared gameplay systems.
4. Implement the change in the smallest viable step.
5. Verify the affected behavior and spot-check nearby screens or systems that could regress.
6. Report what changed, what was verified, and any remaining risks.

## How to Think About Tasks

**Ask yourself before starting:**
- Has something similar been built already? (Search the codebase first.)
- Can this be done entirely in new files, or does it require modifying existing views?
- If modifying existing views: which other screens depend on them?
- What's the minimum change that accomplishes the goal?

**Ask the user when:**
- The task is ambiguous about what "done" looks like
- Your approach requires modifying a high-risk file (see safe-coding skill)
- You're choosing between approaches with different tradeoffs
- Something in CLAUDE.md contradicts the task description
- The risk of proceeding on assumption is higher than the cost of asking first

**Proceed without waiting when:**
- The task is clearly scoped and the smallest safe implementation path is obvious
- You can make a minimal change without altering core rules or unclear product decisions
- The work is straightforward implementation or cleanup rather than a design choice

## Project-Specific Patterns You Need to Know

### MVVM with a twist
Models and Engine code have zero SwiftUI imports. ViewModels bridge everything. But the Views are doing more work than typical MVVM because of SwiftUI's declarative nature — animations, conditional overlays, and gesture handling live in Views. Don't try to move everything to ViewModels; that fight isn't worth it.

### Grid geometry abstraction
The game supports both square and hex grids through a `GridGeometry` protocol. NEVER write code that assumes square grids. Always use `board.neighbors(of:)`, `board.geometry.tileOrigin(at:)`, etc. Check CLAUDE.md for the full API.

### New files over modified files
This project has been burned repeatedly by modifications to core view files. Strongly prefer creating new files. The ideal integration point is a single `if condition { NewView() }` line added to an existing ZStack.

### Persistence is JSON-based
`ProgressStore` and `SettingsStore` persist to JSON in Application Support. Both are `ObservableObject` singletons. When adding persisted state, add it to the appropriate store — don't create a new persistence mechanism.

## Gotchas — What Will Trip You Up

### SwiftUI modifier order matters (and it's not obvious)
`.frame()` before `.background()` vs after produces different results. `.clipped()` position matters for overscaled images. When debugging layout: add `.border(.red)` temporarily and read modifiers inside-out.

### Conditional views vs hidden views
SwiftUI `if` removes the view from the hierarchy. `.opacity(0)` and `.hidden()` keep it in the hierarchy. For overlays, this distinction is the difference between "works" and "blocks all touch input across the app." Always use `if`.

### GeometryReader is fragile
It recalculates when parent size changes. If you add a view that changes available space (inserting into a VStack, changing padding), GeometryReader-dependent layouts downstream will shift. This is how the level select background kept breaking.

### BiomeTheme is the color source of truth
All per-biome colors (signal, flag, overlay, pin, button) live in `BiomeTheme`. Never hardcode a biome-specific color in a view. If you need a new per-biome color, add a property to BiomeTheme.

## Debugging Approach

Don't guess. Diagnose.

1. **Layout bugs:** Trace the view hierarchy. List every modifier on every view from container to target. Find where the unexpected behavior is introduced. Paste the code.
2. **Touch/input bugs:** Something is intercepting touches. Find every view in the ZStack. Check for transparent views, overlays with `allowsHitTesting` not set, or `if` conditions that should remove a view but aren't.
3. **State bugs:** Check what triggers the change, what observes it, whether the binding is a `@State`, `@StateObject`, `@ObservedObject`, or `@Binding`. Wrong choice = no update.
4. **After two failed attempts:** Stop. Paste code. Explain what you tried. Ask for help.

## Output Standards

- Show your plan before writing code (unless told to skip)
- Structure implementation responses as:
  - Plan
  - Files to change
  - Key risks
  - Verification
  - Files created and modified
- When modifying files: state which files, what changes, and why
- After completing: list all files created and modified
- If you touched any view: list which screens you verified still work
