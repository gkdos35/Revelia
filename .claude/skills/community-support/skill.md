---
name: community-support
description: "Use this skill for anything related to player community and support — response templates for reviews, bug report guidance, patch notes writing, Discord setup, support email, or managing player expectations. Also use when the user mentions 'reviews,' 'Discord,' 'patch notes,' 'community,' or asks how to handle player feedback."
---

# Community & Support Skill — Signalfield

## When This Skill Applies
Use when the user asks about: community building, player feedback, App Store reviews, support emails, bug reports from players, Discord setup, patch notes, or post-launch player relationships.

## First Steps — Every Time
1. **Read CLAUDE.md** for the current game name, features, and any existing community/support setup.

## Community Channel Strategy

### At Launch (minimum viable presence)
1. **Support email** — goes in App Store listing, privacy policy, and in-app settings. Respond within 48 hours.
2. **Reddit presence** — post to relevant subreddits. Be a community member, not just a promoter.
3. **Social media account** — share updates, respond to mentions.

### When Community Grows (50+ engaged players)
4. **Discord server** — channels for announcements, general chat, bug reports, feature requests, strategies
5. Clear rules and pinned "how to report a bug" guidance

## Responding to Feedback

### Response Principles
- **Always respond.** Even a short acknowledgment is better than silence.
- **Be honest about timelines.** "I'm looking into it" beats "it'll be fixed next week" if you're not sure.
- **Never argue with a player.** Acknowledge their experience even if they're wrong.
- **Credit players.** When you fix a reported bug, thank the reporter in patch notes (with permission).

### Response Templates

**Positive review:**
> Thank you! Glad you're enjoying [specific thing they mentioned]. [Optional: mention upcoming update]. If you have ideas, I'd love to hear them — [contact].

**Negative review — legitimate complaint:**
> Thanks for the honest feedback. [Issue] is something I'm working to improve. [Workaround if exists]. I appreciate you letting me know.

**Negative review — misunderstanding the game:**
> I appreciate the feedback! [Brief, friendly clarification about the game's design]. I'd love to know what you think if you try [specific feature that addresses their concern].

**Bug report from a player:**
> Thanks for reporting this. To help me track it down: (1) Which level? (2) What happened vs what you expected? (3) Does it happen every time? Screenshots help too.

**Feature request:**
> Great idea — I've added it to my list. I can't promise a timeline, but I track every suggestion. Thanks for writing.

## Bug Reports from Players

### Making Reports Easy
Include guidance in-app (Settings or Help):
> Having an issue? Email [support address] with: your OS version, what level you were on, what happened vs what you expected, and a screenshot if possible.

### Triaging Player Reports
- **Crash / data loss:** Critical — fix immediately
- **Incorrect game logic:** Major — verify and fix in next update
- **Visual glitch:** Minor — log, batch into next update
- **"Too hard":** Not a bug — respond kindly, consider balancing data
- **"I don't understand X":** UX issue — note for onboarding improvement

## Patch Notes

### Structure
```
# [Game Name] v[X.Y.Z] — [Catchy Title]

## New
- [Most exciting addition first]

## Improved
- [Quality of life changes]

## Fixed
- [Bug fixes — player-facing language, not code jargon]

## Notes
- [Known issues, what's coming next]
```

### Tone
Conversational, brief, player-focused. No internal jargon. Describe what changed from the player's perspective.

## Managing Expectations
- Communicate: "This is v1.0 — actively improving based on feedback"
- Don't promise specific dates for unstarted features
- Don't announce features for other platforms unless committed
- Update cadence: hotfixes immediately, minor updates every 4–6 weeks

## Output Rules
- Reference CLAUDE.md for current game name, features, and support setup
- When writing response templates, keep them adaptable — avoid hardcoding specific feature names
- When writing patch notes, verify all mentioned changes against what was actually built
