---
name: skill-reviewer
description: Use this skill when the user asks to audit, score, improve, refactor, or re-evaluate a skill file, SKILL.md file, reusable markdown instruction file, or prompt-playbook workflow.
---

# Purpose
Review one skill at a time and improve reliability without changing its intended job.

# Inputs
You may be given:
- a path to a `SKILL.md` file
- a skill folder
- a reusable markdown workflow file
- a request to critique an existing skill without rewriting it

Read nearby examples or references only if they are needed to understand the skill's intended inputs, outputs, constraints, or previously finalized decisions.

# Evaluation standard
Use `references/skills-rubric.md` as the scoring and review standard.

# Process
1. Read the target skill or workflow file.
2. Read only the minimum supporting files needed for context.
3. Score it using the 10-category rubric from `references/skills-rubric.md`.
4. Identify the 3 highest-leverage improvements.
5. Identify the strongest existing elements that should be preserved.
6. Choose the lightest useful intervention:
   - critique only
   - amendment plan
   - targeted patch
   - full revised draft
7. Preserve the original job of the skill unless the user explicitly asks to broaden or narrow it.
8. If the skill is overloaded, recommend splitting it into separate skills.
9. If output structure matters and is vague, add a template or example.
10. If predictable model errors are missing, add a gotchas section.
11. If examples are too long for the main file, move or propose them in `examples.md`.

# Default intervention rules
- Start with critique plus the top fixes unless the user explicitly asks for a rewrite.
- Prefer a targeted patch over a full rewrite when the skill is structurally sound.
- If your proposed changes would replace most of the body, classify the result as a full revised draft, not a targeted patch.
- Recommend a full rebuild only when the skill scores very poorly or combines too many unrelated jobs.

# Preservation rules
- Preserve strong existing constraints, anti-goals, decision history, and "what this is not" sections unless you explicitly replace them with an equally strong or stronger version.
- When removing a section, state why it is safe to remove or where its content was merged.
- Do not accidentally strip project-specific terminology, boundaries, or finalized design decisions.
- Distinguish between guidance that is missing and guidance that is present but could be made more explicit.

# Revision rules
- Favor numbered steps over long prose.
- Make triggers more explicit than the original author probably thinks is necessary.
- Remove obvious statements that waste tokens.
- Avoid persona fluff unless it is clearly useful.
- Keep the main file compact when possible.
- Preserve useful team terminology and naming conventions.
- Match the level of prescriptiveness to the task: tighter for fragile tasks, looser for creative tasks.
- For exploratory or creative skills, do not force binary or triage-style decision labels unless the skill is primarily evaluative.

# Output format

## Scorecard
- Trigger clarity: X/2
- Single-task focus: X/2
- Step-by-step structure: X/2
- Right level of prescriptiveness: X/2
- Output format clarity: X/2
- Output example quality: X/2
- Gotchas / failure prevention: X/2
- Context organization: X/2
- Clean input/output for chaining: X/2
- Maintainability / folder structure: X/2
- Total: X/20

## Strong elements to preserve
- ...
- ...

## Top 3 improvements
1. ...
2. ...
3. ...

## Recommended intervention
Choose one:
- critique only
- amendment plan
- targeted patch
- full revised draft

## Amendments
If the intervention is:
- critique only: explain the issues and proposed fixes
- amendment plan: give a concise edit plan
- targeted patch: provide only the changed sections
- full revised draft: provide the revised markdown in full

## Changelog
- Change: ...
  - Why it helps: ...
- Preserved: ...
  - Why it should stay: ...

# Staleness checks
If the structure is still good but the results are drifting, check:
- whether examples are outdated
- whether reference files are stale
- whether the trigger no longer matches current usage
- whether the output format no longer matches what the user wants now
