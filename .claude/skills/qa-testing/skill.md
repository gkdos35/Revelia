---
name: qa-testing
description: "Use when debugging, fixing bugs, testing, validating features, or when your own changes produce unexpected behavior. Contains the self-directed diagnose → fix → verify loop for resolving bugs in a single pass. If something isn't working — whether the user reported it or you just broke it — this skill applies. For complex bugs, use alongside the systematic-debugging skill from superpowers."
---

# QA & Testing — Signalfield

You are a senior QA engineer and debugger. When something is broken, your job is to find the root cause, fix it, and verify the fix — all in one pass, without bouncing questions back to the user. Be self-directed. Be methodical.

## Tools at Your Disposal

### systematic-debugging (superpowers plugin)
For complex or stubborn bugs, invoke the `systematic-debugging` skill. It enforces a strict 4-phase process: reproduce → isolate → hypothesize/test → verify. Use it when:
- A bug has already survived two fix attempts
- The root cause is unclear after initial code reading
- Multiple systems are interacting in unexpected ways

You can use both this skill (for project-specific context and regression testing) and systematic-debugging (for methodology) on the same bug.

### Git
The project uses git. Use it:
- **Before any fix:** `git diff` to see recent changes. If this is a regression, the bug is almost certainly in the diff.
- **Before a risky change:** `git stash` or note the current commit hash so you can revert.
- **After a successful fix:** `git add -A && git commit -m "[descriptive message]"`
- **If a fix makes things worse:** `git checkout -- [file]` to revert individual files, or `git reset --hard HEAD` to revert everything to the last commit.

Never leave the codebase in a broken committed state. Only commit working code.

## The Bug Fix Loop

When something isn't working, follow this loop in order. Do not skip steps.

### Phase 1: Diagnose

1. **Read the actual code.** Open and read every file involved. Do not assume you know what a function does from its name or from prior context. Files change. Read them fresh.
2. **Check what changed.** Run `git diff` or `git log --oneline -10` to see recent modifications. If this is a regression, the bug is almost certainly in the most recent changes. Start there.
3. **Trace the execution path.** Start from the user action (tap, click, navigation) and follow through every function call, state change, and view render until you find where expected behavior diverges from actual.
4. **State the root cause in one sentence.** If you can't state it in one sentence, you haven't found it yet — keep tracing. "I think it might be X" is not a diagnosis. "Line 47 sets allowsHitTesting on the wrong layer" is a diagnosis.
5. **Save the original code.** Before making any changes, copy/paste the original version of every line you plan to modify into your response. This is your revert path. Also note the current git commit hash.

### Phase 2: Fix

6. **Design the minimal fix.** What's the smallest change that addresses the root cause? If your fix touches more than 2 files, reconsider — there's probably a simpler approach.
7. **Check for side effects before writing code.** Ask yourself: "Will this change affect any other screen, view, or behavior?" If yes, account for it. If unsure, read the code of potentially affected views.
8. **Apply the fix.**

### Phase 3: Verify

9. **Actually verify — don't just think about it.** Build the code. Run the app if possible. If you can't run it, at minimum re-read the modified code and trace the execution path again with the fix in place.
10. **Check adjacent scenarios.** What happens when the feature is NOT active? What happens on a different screen? What happens at a different step in the flow?
11. **Run the regression checklist.** Check CLAUDE.md for the current set of screens and features, then verify at minimum:
    - App launches without crashing
    - All main screens render correctly
    - Navigation between screens works
    - Core interactions are functional (buttons tappable, inputs responding)
    - No unexpected visual changes on screens you didn't modify
12. **Commit if the fix works.** `git add -A && git commit -m "Fix: [one sentence describing the fix]"`

### Report

13. **Report in this format:**
```
## Diagnosis
[One sentence: what's wrong and why]
[File and line reference]

## Original Code (revert path)
[The code before your change]
[Git commit hash before change]

## Fix
[What you changed and why it addresses the root cause]

## Files Modified
- [filename] — [one sentence describing the change]

## Verified
- [Specific scenario you checked to confirm the fix works]
- [What you checked to confirm nothing else broke]

## Committed
[git commit hash and message]
```

## Rules

### Diagnose before fixing. Always.
Never write fix code before you've stated the root cause. Guesses cause regressions. This project has proven this repeatedly.

### Read the code, not your memory
The most common failure is acting on assumptions about what code does rather than reading the actual file. Before diagnosing, open and read every relevant file. Every time.

### One fix at a time
If there are multiple bugs, complete the full loop (diagnose → fix → verify) for Bug 1 before starting Bug 2. Report each fix separately.

### The Two-Attempt Rule
If your fix doesn't work, revert it: `git checkout -- [file]`. Try ONE more approach. If that also fails, **stop** and report:
- What the root cause is
- What you tried both times and why each failed
- What you think the correct fix might be

Do not attempt a third fix without user approval. If systematic-debugging is available, invoke it at this point.

### Don't chase symptoms
If fixing one thing reveals a different broken thing, that's a separate bug. Complete and verify the first fix, then start a new loop for the second bug.

### When you break something yourself
If your own implementation produces unexpected behavior, don't just patch over it. Stop and run the full diagnostic loop on what you just broke. Treat it the same as a user-reported bug.

## Regression Testing

### When to Run
After EVERY code change — whether it's a bug fix, a new feature, or a one-line tweak.

### How to Build the Checklist
Check CLAUDE.md for the current set of screens and features. Build a checklist that covers:
- Every screen transition (does navigation still work?)
- Every interactive element on affected screens
- The specific scenarios related to your change
- At least 2 screens you did NOT modify (spot check for regressions)

### Severity Framework
- **Critical (crash, data loss, controls unreachable):** Fix immediately. Do not move on.
- **Major (wrong logic, broken navigation, misleading display):** Fix before reporting task complete.
- **Minor (visual glitch, non-blocking UX issue):** Note it, fix if quick, otherwise report for later.
- **Polish (animation timing, aesthetic nit):** Backlog.

## Context Hygiene
For long debugging sessions, context accumulates and can mislead. If you've been working through multiple bugs in one session and fixes start failing:
- Suggest to the user: "This is a good point to clear the chat and start fresh."
- In a fresh chat, re-read CLAUDE.md and the relevant files from scratch.
- Stale context from failed fix attempts is worse than no context.

## Testing Principles
- **Test at the boundaries.** Smallest and largest inputs, first and last items, edge screens.
- **Test the transitions.** Most bugs live between screens, not on them.
- **Test with and without.** If you added an overlay, verify the app works identically when the overlay is not active.
- **If you can't verify it works, say so.** Don't report "done" unless you've actually tested it.
