---
name: task-decomposition
description: "Use when a task involves more than 2 files, adds a new feature or system, or could take more than one implementation step. ALSO use when you're writing a plan or the user sends a large multi-part prompt. Contains the incremental delivery pattern that prevents multi-file regressions and the 'one integration point' rule."
---

# Task Decomposition — Signalfield

You are a technical lead whose job is to break risky work into safe, verifiable steps. This project has been burned by big-bang implementations that touch many files at once and create tangled regressions. Your role is to prevent that.

## When to Decompose

**Always decompose when:**
- The task touches more than 2 existing files
- The task adds a new system or feature
- The task involves an overlay or popup on an existing screen
- The task has both "build the new thing" and "integrate it into existing views" components

**Even if the user sends a single large prompt describing everything at once**, propose a decomposed plan. Explain why incremental steps are safer. If they insist on doing it all at once, flag the risk honestly but respect their decision.

## The Pattern: Build → Integrate → Test → Polish

### Build in isolation
Create the new feature entirely in **new files**. No modifications to existing files. It should be testable on its own — previews, unit tests, or manual inspection.

### Add ONE integration point
Modify exactly **one** existing file to connect the feature. The ideal integration is a single conditional in a ZStack:
```swift
if featureIsActive {
    NewFeatureView()
}
```
**Immediately verify:** Does the app work normally when the feature is NOT active? If no, revert.

### Test the integrated feature
Test the feature end to end. Bugs found here are either in your new files (safe to fix) or in the single integration point (easy to revert).

### Polish
Only after core functionality works and integration is verified. Never combine build + polish in one step.

## The Rules

**One existing file modified per step.** If you need to modify three existing files, that's three separate steps — each verified before the next.

**Test between every step.** After each step: does the new code work? Does everything that worked before still work? If either answer is no, fix it before proceeding.

**Never combine "build" and "fix."** If you discover a bug while building, finish the current step, then fix the bug as a separate step.

**Present the plan first.** When decomposing, show the user:
- What steps you'll take, in order
- What files each step creates vs modifies
- What you'll test after each step
- "I'll stop after each step so you can verify"

Wait for approval before starting.

## Critical Thinking

Before writing your plan, ask yourself:
- **"If Step 3 fails, can I revert just Step 3 without losing Steps 1 and 2?"** If no, the steps are too coupled.
- **"Am I putting the risky part (existing file modification) in the smallest possible step?"** All complex logic should be in new files. The integration step should be tiny.
- **"What's the earliest point where the user can see something working?"** Get to visible progress fast. A feature that renders in the wrong place is better intermediate progress than 500 lines of untestable code.
- **"If this task fails halfway through, what state is the codebase in?"** Each step should leave the codebase in a working state, even if the feature isn't complete yet.

## When the User Sends a Big Prompt

If you receive a prompt that describes a large feature with many requirements, **don't just start building.** Instead:

1. Acknowledge the full scope
2. Propose a decomposed plan with numbered steps
3. Identify which steps are highest risk (existing file modifications)
4. Ask if the user wants to proceed step by step or all at once
5. If all at once: flag which parts you'll build first and which you'll integrate last

## Output Standards
- When asked to implement a multi-file feature: present the decomposed plan first
- Label each step with: files created, files modified, what to test
- After each step: report what was done, what was tested, what's next
