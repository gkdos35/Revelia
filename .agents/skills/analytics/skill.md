---
name: analytics
description: "Use this skill for anything related to player metrics and data — tracking stats, playtesting data collection, balancing decisions from data, player behavior analysis, retention metrics, or a player stats screen. Also use when the user asks 'is this level too hard,' 'how do I know if it's balanced,' or wants to analyze playtest results."
---

# Analytics & Player Data Skill — Signalfield

## When This Skill Applies
Use when the user asks about: player behavior tracking, analytics implementation, retention metrics, balancing from data, telemetry, App Store analytics, or measuring the game's performance with real players.

## First Steps — Every Time
1. **Read CLAUDE.md** for the current state of analytics, what data is being tracked, and what's planned.

## Workflow
1. Identify the request type: analytics implementation, metric design, playtest analysis, retention review, balance diagnosis, or player-stats feature planning.
2. Confirm the current tracking state and available data in `CLAUDE.md` before proposing changes.
3. Define the question that needs answering before choosing metrics or instrumentation.
4. Choose the minimum useful metrics that inform a real product, balance, or UX decision.
5. Separate observed facts from interpretation when analyzing results.
6. End with the recommended action, not just the numbers.

## Philosophy: Privacy-First Analytics
Ship with NO external analytics SDKs. All data is local-first:
1. **Apple App Analytics** — free, no SDK, covers installs/sessions/retention
2. **Local play statistics** — rich gameplay data stored on device for the player's benefit
3. **Optional future telemetry** — only if/when needed, opt-in, privacy policy updated first

This means zero privacy complications, no dependencies, and no review friction.

## Local Statistics Approach

### What to Track Per Attempt
For every level attempt, store: level identifier, outcome (won/lost/abandoned), time, action counts, score, and any relevant game-specific metrics. Check CLAUDE.md for the specific data model if one exists.

### Aggregate Statistics
Compute from stored attempts:
- Per level: total attempts, win rate, best score, best time, average time
- Per biome/section: completion rate, most-abandoned level (difficulty spike indicator)
- Global: total play time, levels completed, longest streak

### Why Track Locally?
- **For the player:** Puzzle game players love their own stats. A stats screen is a feature.
- **For balancing:** Win rates and abandon rates tell you if a level is too hard or too easy.
- **For future decisions:** If you later add opt-in telemetry, the data model already exists.

## Apple App Analytics (Free, No SDK)
Available in App Store Connect → App Analytics:
- Impressions, product page views, downloads
- Sessions, active devices (DAU/MAU)
- Retention (Day 1/7/28)
- Crashes

Does NOT tell you: which level players are on, where they quit, session length, or any in-game behavior.

## Using Data for Balancing

### Key Questions
| Question | Data to Check | Action |
|----------|--------------|--------|
| Is a level too hard? | Win rate < 30% after many attempts | Reduce difficulty parameters |
| Is a level too easy? | Win rate > 95%, fast times | Increase difficulty parameters |
| Is a mechanic confusing? | High abandon rate on first level of a section | Improve tutorial/onboarding for that mechanic |
| Is the game retaining? | Apple D7 retention < 20% | Pacing or difficulty curve issue |
| Is scoring balanced? | Scores cluster too tightly or spread too wide | Adjust formula constants |

### Playtest Template
```
# Playtest Session — [Date]
Tester: [Name / "Self"]
Build: [Version]

## Levels Played
| Level | Outcome | Time | Notes |
|-------|---------|------|-------|
|       |         |      |       |

## Observations
- What confused the tester:
- What delighted the tester:
- Where they hesitated:
- Bugs noticed:
```

## Future Telemetry (Plan Now, Build Only If Needed)
If server-side analytics become necessary:
1. Define event types now (level started, completed, abandoned, setting changed)
2. Default implementation writes to local log
3. Future implementation sends to a privacy-respecting service
4. Always opt-in only, with consent dialog
5. Update privacy policy and App Store nutrition labels if adding

### What Never to Track
- No personal identifiers (name, email, Apple ID)
- No device identifiers without ATT consent
- No location, file system, or screen data

## Player Stats Screen (Feature Recommendation)
Consider exposing local stats to the player:
- Total play time, levels completed, win rate
- Best scores per section
- Streaks and milestones

This turns analytics into a feature players appreciate.

## Guardrails
- Do not track a metric unless it informs a real decision.
- Do not overreact to tiny samples or noisy playtest data.
- Do not treat correlation as proof of causation.
- Do not weaken the privacy-first approach casually; justify any telemetry expansion explicitly.

## Output Rules
- Reference CLAUDE.md for current data model and tracking state
- Structure responses as:
  - Question being answered
  - Data or metrics used
  - Findings
  - Decision implications
  - Next steps
- When proposing metrics, explain what decision each metric informs
- When analyzing playtest data, focus on actionable insights not just numbers
