---
name: app-store
description: "Use this skill for anything related to App Store submission — review guidelines, metadata, pricing, TestFlight, certificates, provisioning profiles, screenshots, app description, age ratings, privacy declarations, rejection avoidance, or pre-submission checklists. Also use when the user mentions 'submitting,' 'publishing,' 'TestFlight,' or asks about Apple's requirements."
---

# App Store Skill — Signalfield

## When This Skill Applies
Use when the user asks about: Mac App Store submission, Apple review guidelines, app metadata, pricing strategy, TestFlight, certificates, app categories, age ratings, or anything related to publishing the app.

## First Steps — Every Time
1. **Read CLAUDE.md** for the current game name, feature set, platform target, and any existing App Store preparation.
2. Check for any pre-launch checklist documents in the project.

## Pre-Submission Checklist

### Apple Developer Account
- [ ] Active Apple Developer Program membership ($99/year)
- [ ] Certificates: Mac App Distribution + Mac Installer Distribution
- [ ] App ID registered
- [ ] Provisioning profiles created
- [ ] Signing configured in Xcode

### Xcode Project
- [ ] Bundle identifier set (check CLAUDE.md for current value)
- [ ] Deployment target set (check CLAUDE.md for minimum macOS version)
- [ ] App Sandbox enabled (required for Mac App Store)
- [ ] Hardened Runtime enabled
- [ ] App category set (check CLAUDE.md)
- [ ] Version and build numbers set
- [ ] App icon included (all required sizes, no transparency)

### App Sandbox Entitlements
Only request what the app actually needs. Check CLAUDE.md for the app's actual requirements (file access, networking, hardware access). Most offline games only need App Container file access.

### App Store Connect
- [ ] App record created
- [ ] Primary language set
- [ ] Category and subcategory set
- [ ] Content rights confirmed
- [ ] Age rating questionnaire completed

## Metadata Structure

### Required Fields
- **App name:** Must be globally unique in the App Store. Check CLAUDE.md for current name and backups.
- **Subtitle:** 30 characters max. Brief descriptor of the game.
- **Keywords:** 100 characters max, comma-separated. Don't repeat words from the app name.
- **Description:** 4000 characters max. Structure: hook (first 2–3 visible lines) → gameplay → features → differentiators.
- **Promotional text:** 170 characters max. Updatable without a new build.
- **What's New:** For updates. Keep brief, player-facing.
- **Privacy policy URL:** Required even for zero-data apps.

### Age Rating
Complete the questionnaire honestly. Most puzzle games with no violence, mature content, or gambling rate 4+.

### Export Compliance
If no networking or encryption: select "No" for encryption usage.

## Pricing Strategy Options
- **Paid upfront ($2.99–$4.99):** Simpler review process, no IAP/StoreKit needed, player trust
- **Free with IAP:** More downloads, lower conversion, requires StoreKit implementation
- **Subscription:** Not recommended for single-player puzzle games

## TestFlight
- Upload builds for beta testing before submission
- TestFlight builds last 90 days
- Test on: minimum and latest supported OS versions, Intel and Apple Silicon
- Validate: app launches, core features work, save/load works across updates

## Common Rejection Reasons
1. **Crashes** — test on all supported hardware
2. **Broken links** — verify privacy policy URL works
3. **Misleading metadata** — screenshots must show actual gameplay
4. **Placeholder content** — no "TODO" or "lorem ipsum" anywhere
5. **Performance issues** — app must be responsive
6. **Sandbox violations** — don't access files outside your container
7. **Minimum functionality** — Apple may reject if the app feels too bare

## Screenshots
- Minimum 3, recommended 5–8
- Required sizes depend on supported Mac displays (check Apple's current requirements)
- Each screenshot should highlight a different feature
- Brief overlaid captions are allowed
- Must show actual gameplay, not mockups

## Post-Launch
- Plan updates every 4–6 weeks initially
- Never break save compatibility without migration code
- Monitor ratings in App Store Connect
- Respond to reviews constructively
- Apple's built-in App Analytics (no SDK) provides installs, sessions, retention, crashes

## Output Rules
- Reference CLAUDE.md for current game name, feature set, and metadata values
- When preparing metadata, verify all claims against the actual game state
- When writing descriptions, lead with what makes the game unique
