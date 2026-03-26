---
name: sound-audio
description: "Use this skill for anything related to audio — sound effects, ambient tracks, soundscapes, audio file formats, AVFoundation implementation, audio sourcing and licensing, or audio manager architecture. Also use when the user mentions 'sound,' 'music,' 'SFX,' 'audio,' or asks what something should sound like."
---

# Sound & Audio Skill — Signalfield

## When This Skill Applies
Use when the user asks about: sound effects, music, ambient audio, soundscapes, UI sounds, audio implementation in Swift, AVFoundation, sound file formats, royalty-free audio sourcing, audio mixing, or anything the player hears.

## First Steps — Every Time
1. **Read CLAUDE.md** for the current state of audio implementation, what sounds exist, and what's planned.
2. Check what audio files already exist in the project before creating or sourcing new ones.

## Audio Design Principles for Puzzle Games
- Ambient is usually better than melodic music — melodies distract during concentration
- Ambient tracks should evolve slowly and loop seamlessly
- Sound effects should be satisfying but not startling — the player is thinking
- Each distinct game environment should have its own audio identity
- Loss sounds should be dramatic but not punishing — encourage retry, not frustration
- Victory sounds should feel earned and celebratory

## Technical Implementation

### Framework
- Use **AVFoundation** (built into macOS, no external dependencies)
- `AVAudioPlayer` for ambient tracks and longer sounds
- `AVAudioEngine` for real-time mixing or effects (more complex, only if needed)
- `NSSound` is lightest for simple SFX on macOS but offers less control
- Start simple, upgrade only when needed

### Audio Manager Pattern
- Singleton that manages all audio playback
- Methods for: playing SFX (fire-and-forget), playing ambient loops, stopping ambient with fade, volume control
- Respects a global mute setting from user preferences
- Mutes when app is in background

### File Formats
- **SFX:** `.wav` or `.aiff` (uncompressed, low latency, small files)
- **Ambient/Music:** `.m4a` (AAC compressed, good quality at small file size)
- **Avoid:** `.mp3` (decoding latency, not ideal for game audio on Apple platforms)
- Organize audio files by type (sfx/, ambient/, stings/)

### Integration with Settings
- Wire a sound on/off toggle to the audio manager's mute state
- Consider splitting into SFX volume and ambient volume if both exist
- Respect macOS system volume
- Mute all audio when app loses focus

## Sourcing Audio

### Royalty-Free Libraries
- **Freesound.org** — community-contributed, various licenses (check each file)
- **Kenney.nl/assets** — game audio packs, CC0 (no attribution required)
- **OpenGameArt.org** — game-focused, various licenses
- **Zapsplat.com** — large library, free tier with attribution

### License Requirements for App Store
- **CC0 (public domain):** Safest — no restrictions
- **CC-BY (attribution):** Include credit in app or documentation
- **Royalty-free commercial:** Read terms carefully
- **NEVER use CC-NC (non-commercial)** for a paid or ad-supported app

### AI-Generated Audio
- Various AI tools can create SFX and ambient tracks
- Verify the tool's license permits commercial use
- Always review and edit generated audio — don't ship raw output

### Commissioning
- Freelance sound designers on Fiverr, UpWork, or game audio communities
- Budget: $200–$500 for a full indie game sound set
- GarageBand (free on Mac) can produce simple SFX and ambients

## Rapid Cascade / Rapid Input Considerations
- When many sounds trigger in quick succession (e.g., a chain reaction), they can stack badly
- Use a sound pool or limit concurrent instances of the same SFX
- Consider pitch variation on repeated sounds to avoid monotony

## Output Rules
- Reference CLAUDE.md for what specific sounds are needed and what already exists
- When proposing sounds, describe the character/feeling, not just the trigger
- Track all sourced audio licenses in a dedicated file
