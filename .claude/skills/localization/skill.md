---
name: localization
description: "Use this skill for anything related to translation and internationalization — String Catalogs, key naming conventions, locale-aware formatters, text expansion, RTL layout support, translation workflow, or multi-language support. Also use when the user mentions 'translation,' 'localization,' 'i18n,' 'languages,' or asks about supporting non-English players."
---

# Localization Skill — Signalfield

## When This Skill Applies
Use when the user asks about: translation, localization, internationalization, supporting multiple languages, locale-specific formatting, Xcode string catalogs, right-to-left layout, or reaching non-English markets.

## First Steps — Every Time
1. **Read CLAUDE.md** for the current state of localization — what's been set up, what strings exist.
2. Check whether String Catalogs are already enabled in the project.

## Core Principle: Internationalize Now, Translate Later
Setting up the infrastructure now saves enormous pain later. Retrofitting localization into an app not designed for it is one of the most tedious refactoring tasks.

**Internationalize** = make code ready for multiple languages (do now)
**Localize** = actually translate to specific languages (do later)

## Internationalization Rules

### String Catalogs (Xcode 15+)
- **Never hardcode user-facing strings in Swift code**
- SwiftUI `Text()` automatically does localization lookup — structure strings consistently
- Use hierarchical dot notation for string keys: `category.subcategory.item`
- Check CLAUDE.md for current UI labels and feature names when defining keys

### Locale-Aware Formatting
Never manually format numbers, dates, or times:
```swift
score.formatted()                    // Respects locale separators
Duration.seconds(elapsed).formatted(
    .time(pattern: .minuteSecond)
)                                    // Locale-appropriate time
date.formatted(date: .abbreviated, time: .omitted)  // Locale date format
```

### Layout Considerations
- **Text expansion:** German runs ~30% longer than English. French ~15–20%.
- Never use fixed-width labels — use SwiftUI's natural sizing
- Test with Xcode pseudolocalizations
- **Right-to-left (RTL):** SwiftUI handles RTL automatically with standard layout APIs
- Game grids should NOT flip (spatial, not textual) — menus and HUD should flip
- Test with `.environment(\.layoutDirection, .rightToLeft)` in previews

### What Needs Translation vs What Doesn't
- **Needs translation:** All UI text, menu labels, settings labels, tutorial text, biome/level names, App Store metadata
- **Does NOT need translation:** Visual-only elements (icons, gameplay graphics), sounds, game logic

## Translation Workflow (When Ready)
1. Export String Catalog from Xcode (File → Export Localizations)
2. Send exported `.xliff` files to translator
3. Receive translated `.xliff` files
4. Import back into Xcode (File → Import Localizations)
5. Test every screen in every language (use Xcode scheme to override language)

## Priority Languages for Mac App Store Games
1. English (launch language)
2. Simplified Chinese — largest non-English Mac gaming market
3. Japanese — strong puzzle game culture
4. German — large European Mac userbase
5. French, Spanish, Korean, Portuguese (Brazil)

## Translation Cost Estimates
For a game with ~200–300 strings, professional translation runs ~$50–$100 per language. AI translation with human review is cheaper and faster but lower quality for creative/thematic content.

## Output Rules
- Reference CLAUDE.md for current string inventory and UI labels
- When adding new user-facing strings, always use the String Catalog system
- When proposing translations, note any strings that require creative adaptation (thematic names, puns, etc.)
