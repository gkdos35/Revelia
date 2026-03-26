# Signalfield — Cowork Project Setup

## What's In This Folder

This is your complete Cowork workspace for building Signalfield from
concept to App Store. Every file is tailored to this specific project.

```
signalfield-cowork/
├── CLAUDE.md                              ← Master briefing (auto-loaded every session)
├── README.md                              ← You're reading this
├── reference/
│   ├── spec/
│   │   └── signalfield-spec.md            ← The original game spec (source of truth)
│   ├── brand/                             ← Put logo, palette, fonts here as you create them
│   ├── competitors/                       ← Screenshots, notes on Hexcells/Tametsi/etc.
│   └── apple-guidelines/                  ← Relevant HIG excerpts, review guidelines
├── inbox/                                 ← Drop files here for Claude to process
├── outputs/                               ← Claude puts all finished work here
├── archive/                               ← Completed or old work
└── .claude/
    └── skills/
        ├── game-design/SKILL.md           ← Mechanics, GDD, balancing, puzzle theory
        ├── development/SKILL.md           ← Swift, SwiftUI, MVVM, Xcode, algorithms
        ├── qa-testing/SKILL.md            ← Bugs, test plans, playtesting, edge cases
        ├── art-assets/SKILL.md            ← Visuals, palette, glyphs, icons, screenshots
        ├── app-store/SKILL.md             ← Submission, metadata, TestFlight, pricing
        ├── project-mgmt/SKILL.md          ← Sprints, milestones, scheduling, status
        ├── marketing/SKILL.md             ← Press kit, social media, devlogs, launch
        ├── sound-audio/SKILL.md           ← SFX, ambience, biome soundscapes, sourcing
        ├── legal/SKILL.md                 ← Trademark, copyright, privacy policy, licenses
        ├── ux-accessibility/SKILL.md      ← VoiceOver, keyboard nav, colorblind, onboarding
        ├── analytics/SKILL.md             ← Player stats, metrics, balancing from data
        ├── localization/SKILL.md          ← i18n, string catalogs, translation workflow
        └── community-support/SKILL.md     ← Discord, reviews, bug reports, patch notes
```

## Setup Steps

1. **Copy this folder** to your preferred location. Rename it if you like.

2. **Customize CLAUDE.md** — It's ready to go but review it. Update the
   "What I'm Working On Right Now" section as your priorities change.

3. **The .claude folder may be hidden.** On Mac: Cmd+Shift+. in Finder
   to toggle hidden files. On Windows: enable "Show hidden files" in
   File Explorer.

4. **Put your full original spec** in `reference/spec/` if you want the
   complete version available (a condensed version is already there).

5. **Open Claude Desktop → Cowork tab → point it at this folder.**

6. **First task suggestion:** Tell Claude:
   "Read my CLAUDE.md and the spec in reference/spec/, then help me
   create Sprint 1 for the Foundation phase."

## How the Skills Work

You don't need to manually invoke skills. When you ask Claude about
a topic, it sees the pointers in CLAUDE.md and loads the relevant skill
automatically. For example:

- "Help me design the Fog Marsh beacon mechanic" → loads game-design skill
- "Write the BoardGenerator in Swift" → loads development skill
- "What do I need for App Store submission?" → loads app-store skill
- "Plan my next two weeks" → loads project-mgmt skill
- "Write a devlog about the cascade system" → loads marketing skill
- "Create a test plan for Biome 2" → loads qa-testing skill
- "What should the color palette look like?" → loads art-assets skill
- "What sounds do I need for the Frozen Mirrors biome?" → loads sound-audio skill
- "Can I trademark the name Signalfield?" → loads legal skill
- "How should VoiceOver describe a tagged tile?" → loads ux-accessibility skill
- "What metrics should I track per level?" → loads analytics skill
- "How do I set up string catalogs in Xcode?" → loads localization skill
- "How should I respond to a negative App Store review?" → loads community-support skill

## How to Evolve These Files

These files are starting points. As you work with Claude:

- **When Claude makes a wrong assumption**, tell it to add a correction
  to CLAUDE.md. Example: "Add to CLAUDE.md that we decided to use a
  3x3 safe zone around first scan, not just the single tile."

- **When a skill needs updating**, ask Claude to update it. Example:
  "Update the development skill to note that we're using LazyVGrid
  for the tile grid instead of a plain Grid."

- **When you start a new phase**, update the "What I'm Working On"
  section in CLAUDE.md so Claude always knows your current focus.

## Recommended Workflow

1. Start each Cowork session by telling Claude your goal for the session
2. Let Claude read the files and propose a plan
3. Review the plan before Claude executes
4. Work in focused sessions (one biome, one feature, one milestone)
5. At the end of each session, update CLAUDE.md if priorities changed
6. Keep the reference/spec/ folder as your unchanging source of truth

## Adding More Skills Later

Need a skill for sound design? Localization? Analytics? Create:
`.claude/skills/[topic]/SKILL.md`

Then add a pointer in CLAUDE.md:
"When I ask about [topic], read .claude/skills/[topic]/SKILL.md first."
