---
name: project-mgmt
description: "Use this skill for anything related to project planning — priorities, scheduling, status updates, task breakdowns, time estimates, or the development timeline. Also use when the user asks 'what should I work on next,' 'how long will this take,' or wants to plan a work session."
---

# Project Management Skill — Signalfield

## When This Skill Applies
Use when the user asks about: planning, priorities, task breakdown, status reports, progress tracking, what to work on next, timeline estimates, or project organization.

## First Steps — Every Time
1. **Read CLAUDE.md** for the current state of the project — what's built, what's planned, what's broken.
2. Check for any pre-launch checklist or task list documents in the project.
3. Never assume the project phase from memory — verify against current state.

## Workflow
1. Identify the request type: next-step recommendation, work-session plan, status update, milestone planning, task breakdown, or time estimate.
2. Verify the current project state before prioritizing anything.
3. Separate blockers, critical-path work, and optional work so the recommendation is honest about urgency.
4. Right-size the plan to the actual session, sprint, or milestone instead of planning everything at once.
5. Add estimates with explicit uncertainty and include verification time.
6. End with the clearest recommended next actions.

## Prioritization Framework
When deciding what to work on next:
1. **P0 — Blocking:** Something is broken and prevents further work or testing
2. **P1 — Critical path:** Required for the next milestone (e.g., launch)
3. **P2 — Important:** Improves quality or completeness but not blocking
4. **P3 — Nice to have:** Polish, optimization, optional features

Always fix broken things before building new things.

## Task Breakdown Principles
- Break large features into the smallest independently testable pieces
- Each task should have a clear "done" state that can be verified
- Prefer tasks that touch few files over tasks that touch many
- If a task requires modifying more than 3 existing files, consider splitting it
- Always include "verify nothing else broke" as part of any task

## Time Estimation Guidelines
Game dev timelines almost always slip. Apply these multipliers:
- If you think something takes 2 hours → budget 3–4 hours
- Engine/algorithm work: multiply estimate by 1.5× (edge cases are hidden)
- UI/layout work: multiply by 1.3× (SwiftUI layout quirks)
- First implementation of a pattern: 2× longer than subsequent ones
- Testing and bug fixing: reserve 20–30% of every work session for this

## Sprint / Work Session Template
```
# Work Session — [Date]

## Goal
[One sentence describing what "done" looks like]

## Tasks (in order)
| # | Task | Priority | Est. Time | Status |
|---|------|----------|-----------|--------|
| 1 |      |          |           | To Do  |

## Definition of Done
- Code compiles with no warnings
- Feature works in at least 3 test runs
- No regressions in previously working features
- All modified files documented

## Session Results
- Completed:
- Carried over:
- Blockers discovered:
```

## Status Report Template
```
# Project Status — [Date]

## What's Working
- [List of functional features]

## What's Broken
- [List of known bugs]

## What's Next
- [Prioritized list of upcoming tasks]

## Risks
- [Anything that could delay progress]

## Decisions Needed
- [Open questions requiring input]
```

## Common Mistakes to Avoid
- Don't build new features while bugs exist in the current build
- Don't combine "fix bug" and "add feature" in the same task
- Don't skip testing because you're excited to move on
- Don't estimate without checking what files need to change
- Don't plan more than one large feature per work session

## Guardrails
- Do not plan from stale assumptions about project state or phase.
- Do not overload a single work session with multiple large tasks.
- Do not mix blockers and stretch goals without labeling them clearly.
- Do not give estimates without leaving room for testing, debugging, and uncertainty.

## Output Rules
- Reference CLAUDE.md for current project state before making any recommendations
- Structure responses as:
  - Request type
  - Current status
  - Recommended priorities or plan
  - Risks / blockers
  - Next steps
- When recommending priorities, explain the reasoning
- When breaking down tasks, specify which files will likely need changes
