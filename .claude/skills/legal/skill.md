---
name: legal
description: "Use this skill for anything related to legal and IP protection — trademark search and filing, copyright registration, privacy policy, EULA, third-party license tracking, or App Store legal requirements. Also use when the user mentions 'trademark,' 'copyright,' 'privacy policy,' 'license,' or asks about protecting their game."
---

# Legal / IP Protection Skill — Signalfield

## When This Skill Applies
Use when the user asks about: trademark, copyright, intellectual property, EULA, privacy policy, open source licenses, App Store legal requirements, or protecting the game's name/brand.

## Important Disclaimer
Claude is not a lawyer. This skill provides general guidance based on common indie game publishing practices. For binding legal questions, consult a licensed attorney.

## First Steps — Every Time
1. **Read CLAUDE.md** for the current game name, dependencies, data collection practices, and any existing legal documents.

## Trademark & Name Protection

### Process
1. Search USPTO database (tess2.uspto.gov) for the game name and similar names
2. Search the App Store and major game platforms for conflicts
3. Check domain availability (.com, .app, .game)
4. Check social media handle availability
5. Have backup names ready — the App Store app name must be globally unique
6. Consider filing a US trademark (~$250–$350, Class 9 for software/games)
7. You can use ™ immediately; ® only after registration is granted
8. Protection dates back to filing date; process takes 8–12 months

## Copyright

### What You Automatically Own
Copyright exists at creation. You own: original code, artwork, game design, level designs, marketing copy.

### What You Don't Own
Game mechanics in the abstract cannot be copyrighted. Third-party assets are licensed, not owned.

### Registration
US Copyright Office registration ($65 online) strengthens legal position against clones. Register the software as a whole before or shortly after launch.

## Privacy Policy

### Requirements
Apple requires a privacy policy URL for every app, even with zero data collection. Draft a privacy policy that accurately describes what data the app does and does not collect. Check CLAUDE.md for the app's actual data practices.

### Hosting
GitHub Pages (free) is sufficient. The URL goes in App Store Connect and in-app settings.

## EULA
Apple provides a standard EULA that covers most cases for paid apps with no subscriptions or user accounts. A custom EULA is only needed if adding multiplayer, user-generated content, or subscription pricing.

## Third-Party License Tracking
Even with zero code dependencies, track licenses for all external assets:
- Fonts (if not system fonts)
- Sound effects and music
- Artwork from external sources
- Any reference materials used

Maintain a `THIRD-PARTY-LICENSES.md` file listing every external asset, its source, license type, and attribution requirements.

### License Types for App Store
- **MIT, BSD, Apache 2.0:** Safe for commercial use, require attribution
- **GPL/LGPL:** Risky — may require source code disclosure. Avoid for commercial apps.
- **CC0 / Public Domain:** No restrictions
- **CC-BY:** Attribution required — include in credits
- **CC-NC:** NOT safe for paid or ad-supported apps

## Protecting Against Clones
1. Trademark the name
2. Copyright register the app
3. Document development process (dated commits, devlogs prove originality)
4. Publish first — earliest public record matters
5. Apple has a dispute resolution process for App Store clones

## App Store Legal Requirements
- Privacy policy URL (required)
- Accurate age rating
- No misleading metadata
- Export compliance declaration (select "No" for encryption if no networking)
- Confirm you have rights to all content in the app

## Output Rules
- Reference CLAUDE.md for current game name, data practices, and dependency status
- When drafting legal documents, always note they should be reviewed by an attorney
- When tracking licenses, include: asset name, source, license type, attribution requirements
