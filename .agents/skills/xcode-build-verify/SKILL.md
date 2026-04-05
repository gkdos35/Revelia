---
name: xcode-build-verify
description: Use when a task changes Swift or SwiftUI code and should end with concrete local verification steps in Xcode. Do not use for non-code planning tasks.
---

# Xcode Build Verify

## Workflow

1. Read `AGENTS.md`.
2. Confirm the correct Xcode project and scheme before making assumptions.
3. Note the exact files changed.
4. Prepare a short Xcode verification checklist tailored to the change:
   - build
   - launch the affected screen or flow
   - reproduce the changed interaction
   - spot-check likely regression surfaces
5. If the change affects shared UI, call out the regression risk explicitly.

## Guardrails

- Do not assume the project, scheme, or target without checking.
- Do not claim verification was run if you are only providing recommended steps.
- Do not skip regression notes for shared views, shared gameplay flows, or reused UI components.

## Output Format

- Files changed
- Xcode verification
- Regression risks
- Not verified, if anything

## Example

```md
Files changed:
- `Views/GameView.swift`

Xcode verification:
- Build the `Signalfield` scheme
- Launch the gameplay screen
- Reproduce the updated interaction
- Spot-check HUD input and pause/settings flow

Regression risks:
- Shared gameplay UI changes can affect board input and HUD hit testing

Not verified:
- Full multi-level gameplay sweep in Xcode
```
