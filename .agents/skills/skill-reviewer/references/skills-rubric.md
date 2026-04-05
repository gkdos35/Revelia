# Skills Rubric

Use this file as the standard for reviewing skills.

## Core idea
A strong skill is a reusable operational playbook that:
- is easy for the model to select
- is easy for humans to understand
- produces reliable output with minimal follow-up correction
- stays maintainable as tools, models, and context change

## The 10 review categories

### 1. Trigger clarity
The skill should make it obvious when it should fire.

Good signs:
- strong trigger words
- explicit scenarios
- clear boundaries between this skill and similar skills

Weak signs:
- vague description
- easily confused with other skills
- passive wording that models may skip

### 2. Single-task focus
A skill should do one clear job.

Good signs:
- one outcome
- one primary workflow
- one type of deliverable

Weak signs:
- multiple unrelated jobs bundled together
- setup, execution, analysis, and reporting all mixed together without structure

### 3. Step-by-step structure
Skills work best as playbooks.

Good signs:
- numbered steps
- clear flow
- concrete actions

Weak signs:
- long prose paragraphs
- hidden order of operations
- lots of explanation but little operational structure

### 4. Right level of prescriptiveness
Precise tasks need tighter steps. Creative tasks need more room.

Good signs:
- exact process for fragile tasks
- guidance without over-railroading for exploratory tasks

Weak signs:
- vague directions for precise work
- rigid directions for creative work

### 5. Output format clarity
The final deliverable should be explicit.

Good signs:
- sections, headings, or structure are specified
- required components are named
- success is easy to recognize

Weak signs:
- no clear definition of done
- unclear shape of the final deliverable

### 6. Output example quality
Show the shape of success.

Good signs:
- output template
- realistic mini-example
- example table, section structure, or schema

Weak signs:
- no example when format matters
- example too abstract to guide the model

### 7. Gotchas / failure prevention
Document where the model is likely to go wrong.

Good signs:
- clear "do not do X" warnings
- explicit handling of common bad assumptions
- instructions that prevent fabricated details, weak sourcing, missed edge cases, or conflict with finalized decisions

Weak signs:
- the skill assumes the model will naturally avoid mistakes
- known failure modes are undocumented

Scoring note:
- Give credit when guardrails are present implicitly, even if they could be made more explicit.
- Score lower only when meaningful failure prevention is actually missing or too weak to be reliable.

### 8. Context organization
Only carry the context the skill really needs.

Good signs:
- skill-specific material lives with the skill
- general personal or company context is referenced elsewhere
- context is not bloating the core instructions

Weak signs:
- everything stuffed into one file
- missing supporting context
- irrelevant reference material bundled into the skill

### 9. Clean input/output for chaining
A good skill can feed another skill.

Good signs:
- predictable outputs
- structured handoff
- minimal cleanup needed before reuse

Weak signs:
- outputs are inconsistent
- format changes run to run
- another skill would need manual cleanup before using the result

### 10. Maintainability / folder structure
A skill should be easy to update.

Good signs:
- compact main file
- separate `examples.md` for long examples
- separate `references/` for bulky supporting material
- obvious place to update context or templates

Weak signs:
- one giant file
- unclear ownership of examples or references
- difficult to tell what is core instruction vs supporting material

## Suggested scoring
- 17–20: strong
- 13–16: usable but worth tightening
- 9–12: meaningful rewrite recommended
- 0–8: likely rebuild candidate

## Highest-leverage fixes
These usually produce the biggest gains first:
1. Make the trigger louder and more explicit
2. Turn prose into steps
3. Add an output template or example
4. Add gotchas for common failure modes
5. Split bulky context into separate files

## Reevaluation triggers
Re-review a skill when:
- one month has passed without review
- the model changed
- the tool changed
- the outputs now need more correction
- examples or references may be stale
- the skill is now being shared across more people or teams
