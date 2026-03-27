// Signalfield/Views/BiomeMechanicView.swift
//
// Parchment-style mechanic introduction sheet. Shown once per biome when
// the player enters that biome's first level for the first time.
//
// Visual language is identical to HowToPlayView:
//   - ParchmentCard texture background, 520×660 pt sheet
//   - Warm brown (#4A3A28) text throughout
//   - ◆ page dots, same size/colour formula
//   - pageShell wrapper (title, illustration hero, body text, nav row)
//   - BMTMiniTile / BMTMiniGrid helpers mirror HTMiniTile / HTMiniGrid
//     but use the BIOME'S OWN theme colours/textures
//
// Self-contained: depends only on BiomeTheme and TileBackgroundShape.
// No game engine, board state, or GameViewModel references.

import SwiftUI

// MARK: - BiomeMechanicView

struct BiomeMechanicView: View {

    /// The biome whose mechanic pages to display (1–8; Training Range = 0 is never shown).
    let biomeId: Int

    /// Callback from ContentView so it can persist the "don't show again" decision.
    var onDontShowAgain: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage       = 0
    @State private var navigatingForward = true
    @State private var dontShowAgain     = false

    // Palette (matches HowToPlayView exactly)
    private let parchmentBrown = Color(red: 0x4A / 255, green: 0x3A / 255, blue: 0x28 / 255)
    private let dotFilled      = Color(red: 0x6B / 255, green: 0x5B / 255, blue: 0x3E / 255)
    private let dotEmpty       = Color(red: 0x6B / 255, green: 0x5B / 255, blue: 0x3E / 255).opacity(0.30)
    private let meadowGreen    = Color(red: 0x7A / 255, green: 0xAA / 255, blue: 0x58 / 255)

    // The biome's own visual palette for illustrations
    private var theme: BiomeTheme { BiomeTheme.theme(for: biomeId) }

    private var pages: [AnyView] { buildPages() }
    private var totalPages: Int  { pages.count }

    var body: some View {
        ZStack {
            // Parchment background — same overscale+clip as HowToPlayView
            Image("ParchmentCard")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.15)
                .frame(width: 520, height: 660)
                .clipped()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // One-at-a-time page display
                ZStack {
                    pages[currentPage]
                        .id(currentPage)
                        .transition(.asymmetric(
                            insertion: .move(edge: navigatingForward ? .trailing : .leading),
                            removal:   .move(edge: navigatingForward ? .leading  : .trailing)
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(.easeInOut(duration: 0.28), value: currentPage)

                // Page dots
                if totalPages > 1 {
                    HStack(spacing: 10) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Text("◆")
                                .font(.system(size: index == currentPage ? 11 : 7))
                                .foregroundColor(index == currentPage ? dotFilled : dotEmpty)
                                .animation(.easeInOut(duration: 0.20), value: currentPage)
                        }
                    }
                    .padding(.bottom, 6)
                }

                // "Don't show again" toggle
                HStack(spacing: 8) {
                    Button {
                        dontShowAgain.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(parchmentBrown.opacity(0.45), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                                if dontShowAgain {
                                    Text("◆")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(parchmentBrown.opacity(0.75))
                                }
                            }
                            Text("Don't show again")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(parchmentBrown.opacity(0.55))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 520, height: 660)
    }

    // MARK: - Navigation

    private func advance() {
        guard currentPage < totalPages - 1 else { return }
        navigatingForward = true
        withAnimation(.easeInOut(duration: 0.28)) { currentPage += 1 }
    }

    private func retreat() {
        guard currentPage > 0 else { return }
        navigatingForward = false
        withAnimation(.easeInOut(duration: 0.28)) { currentPage -= 1 }
    }

    private func gotIt() {
        if dontShowAgain { onDontShowAgain?() }
        dismiss()
    }

    // MARK: - Page shell (mirrors HowToPlayView.pageShell exactly)

    @ViewBuilder
    private func pageShell<I: View, B: View>(
        title:   String,
        isFirst: Bool = false,
        isLast:  Bool = false,
        @ViewBuilder illustration: () -> I,
        @ViewBuilder bodyText:     () -> B
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {

                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(parchmentBrown)
                    .multilineTextAlignment(.center)
                    .padding(.top, 38)
                    .padding(.horizontal, 32)

                Spacer(minLength: 10)

                illustration()
                    .frame(maxWidth: .infinity)
                    .frame(height: 272)

                Spacer(minLength: 8)

                bodyText()
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(parchmentBrown.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)

                Spacer(minLength: 8)

                HStack(alignment: .center) {
                    if !isFirst {
                        Button { retreat() } label: {
                            Text("← Back")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(parchmentBrown.opacity(0.55))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    } else {
                        Color.clear.frame(width: 80, height: 36)
                    }

                    Spacer()

                    if isLast {
                        Button { gotIt() } label: {
                            Text("Got it")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 140, height: 40)
                                .background(theme.playButtonColor)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                    } else {
                        Button { advance() } label: {
                            Text("Next →")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(parchmentBrown)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                                .background(parchmentBrown.opacity(0.12))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }

            // ✕ close button — every page
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(parchmentBrown.opacity(0.70))
                    .padding(9)
                    .background(Circle().fill(parchmentBrown.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 14)
        }
    }

    // MARK: - Page builder

    private func buildPages() -> [AnyView] {
        switch biomeId % 9 {
        case 1: return fogMarshPages()
        case 2: return bioluminescencePages()
        case 3: return frozenMirrorsPages()
        case 4: return ruinsPages()
        case 5: return theUndersidePages()
        case 6: return coralBasinPages()
        case 7: return quicksandPages()
        case 8: return theDeltaPages()
        default: return []
        }
    }
}

// MARK: - Biome 1: Fog Marsh (2 pages)

private extension BiomeMechanicView {

    func fogMarshPages() -> [AnyView] {
        [AnyView(fogMarshPage1), AnyView(fogMarshPage2)]
    }

    var fogMarshPage1: some View {
        pageShell(title: "Fogged Signals", isFirst: true) {
            // Illustration: a fogged tile showing "2–3" next to a crisp revealed tile "2"
            HStack(alignment: .center, spacing: 28) {
                VStack(spacing: 8) {
                    BMTMiniTile(state: .fogged(rangeLow: 2, rangeHigh: 3), theme: theme, tileSize: 72)
                    Text("Fogged")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }
                Text("vs")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(parchmentBrown.opacity(0.35))
                VStack(spacing: 8) {
                    BMTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 72)
                    Text("Clear")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }
            }
        } bodyText: {
            Text("Some tiles are fogged — they show a range instead of an exact signal.")
        }
    }

    var fogMarshPage2: some View {
        pageShell(title: "Beacon Charges", isLast: true) {
            // Illustration: beacon charge button → arrow → tiles with exact numbers revealed
            VStack(spacing: 20) {
                // Beacon charge pill (mimics HUD indicator)
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.signalColor)
                    Text("2")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.signalColor)
                    Text("charges")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(parchmentBrown.opacity(0.10))
                .cornerRadius(10)

                Image(systemName: "arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.35))

                // Before/after: fogged tile → clear tile
                HStack(spacing: 24) {
                    BMTMiniTile(state: .fogged(rangeLow: 2, rangeHigh: 3), theme: theme, tileSize: 64)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(parchmentBrown.opacity(0.35))
                    BMTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 64)
                }
            }
        } bodyText: {
            Text("Use beacon charges to clear the fog and reveal the true signal.")
        }
    }
}

// MARK: - Biome 2: Bioluminescence (1 page)

private extension BiomeMechanicView {

    func bioluminescencePages() -> [AnyView] {
        [AnyView(bioluminescencePage1)]
    }

    var bioluminescencePage1: some View {
        pageShell(title: "Conductor Pulse", isFirst: true, isLast: true) {
            VStack(spacing: 20) {
                // Pulse charge indicator
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.signalColor)
                    Text("1 pulse charge")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.signalColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.signalColor.opacity(0.12))
                .cornerRadius(10)

                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.35))

                // 3×3 grid: center tile glowing, all 9 briefly revealed
                BMTMiniGrid(rows: 3, cols: 3, tileSize: 52, spacing: 4) { row, col in
                    let isCenter = (row == 1 && col == 1)
                    BMTMiniTile(
                        state: .revealed(signal: isCenter ? nil : (row == 0 && col == 2 ? 2 : nil)),
                        theme: theme,
                        tileSize: 52,
                        pulseGlow: true
                    )
                }
            }
        } bodyText: {
            Text("You have one pulse charge per level. Activate it, then click a tile to briefly reveal a 3×3 area. Choose wisely.")
        }
    }
}

// MARK: - Biome 3: Frozen Mirrors (2 pages)

private extension BiomeMechanicView {

    func frozenMirrorsPages() -> [AnyView] {
        [AnyView(frozenMirrorsPage1), AnyView(frozenMirrorsPage2)]
    }

    var frozenMirrorsPage1: some View {
        pageShell(title: "Linked Tiles", isFirst: true) {
            HStack(alignment: .center, spacing: 20) {
                VStack(spacing: 6) {
                    BMTMiniTile(state: .linkedDisplaying(signal: 2), theme: theme, tileSize: 68)
                    Text("Tile A")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.50))
                    Text("shows B's count")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.40))
                }

                VStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.signalColor.opacity(0.70))
                    Text("linked")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.40))
                }

                VStack(spacing: 6) {
                    BMTMiniTile(state: .linkedDisplaying(signal: 2), theme: theme, tileSize: 68)
                    Text("Tile B")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.50))
                    Text("shows A's count")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.40))
                }
            }
        } bodyText: {
            Text("Linked tiles are paired — each shows the OTHER tile's signal, not its own.")
        }
    }

    var frozenMirrorsPage2: some View {
        pageShell(title: "Reading the Pair", isLast: true) {
            VStack(spacing: 16) {
                // Tile B and its actual neighborhood
                HStack(alignment: .center, spacing: 16) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 52, spacing: 4) { row, col in
                        if row == 1 && col == 1 {
                            // Tile B — the partner
                            BMTMiniTile(state: .linkedDisplaying(signal: 2), theme: theme, tileSize: 52)
                        } else if (row == 0 && col == 0) || (row == 2 && col == 2) {
                            // Two actual hazard neighbors
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 52, hazardHint: true)
                        } else {
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 52)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tile B's neighbors")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.70))
                        Text("2 hazards nearby\n→ signal = 2 ✓")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.55))
                            .lineSpacing(2)
                    }
                }
            }
        } bodyText: {
            Text("Look for the dot in the corner. Read the number as if you were standing at the partner tile.")
        }
    }
}

// MARK: - Biome 4: Ruins (1 page)

private extension BiomeMechanicView {

    func ruinsPages() -> [AnyView] {
        [AnyView(ruinsPage1)]
    }

    var ruinsPage1: some View {
        pageShell(title: "Locked Tiles", isFirst: true, isLast: true) {
            HStack(alignment: .center, spacing: 28) {
                // Locked: dimmed center with lock icon surrounded by hidden tiles
                VStack(spacing: 8) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 48, spacing: 4) { row, col in
                        if row == 1 && col == 1 {
                            BMTMiniTile(state: .locked, theme: theme, tileSize: 48)
                        } else {
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 48)
                        }
                    }
                    Text("Locked")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.35))

                // Unlocked: revealed surrounding tiles unlock center
                VStack(spacing: 8) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 48, spacing: 4) { row, col in
                        if row == 1 && col == 1 {
                            BMTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 48)
                        } else if row == 0 || (row == 1 && col == 0) {
                            BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 48)
                        } else {
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 48)
                        }
                    }
                    Text("Unlocked")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }
            }
        } bodyText: {
            Text("Locked tiles won't open until enough of their neighbors are revealed. Plan your path to unlock them.")
        }
    }
}

// MARK: - Biome 5: The Underside (1 page)

private extension BiomeMechanicView {

    func theUndersidePages() -> [AnyView] {
        [AnyView(theUndersidePage1)]
    }

    var theUndersidePage1: some View {
        pageShell(title: "Inverted Signals", isFirst: true, isLast: true) {
            HStack(alignment: .center, spacing: 28) {
                // Normal: center "1" — 1 hazard neighbor highlighted
                VStack(spacing: 8) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 48, spacing: 4) { row, col in
                        if row == 1 && col == 1 {
                            BMTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 48)
                        } else if row == 0 && col == 2 {
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 48, hazardHint: true)
                        } else {
                            BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 48)
                        }
                    }
                    Text("Normal: 1 hazard")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.50))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.35))

                // Inverted: center "5" — 5 safe neighbors highlighted in green
                VStack(spacing: 8) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 48, spacing: 4) { row, col in
                        if row == 1 && col == 1 {
                            // Shows "5" — counts safe neighbors
                            BMTMiniTile(state: .revealed(signal: 5), theme: theme, tileSize: 48)
                        } else if row == 0 && col == 2 {
                            // The one hazard (not highlighted)
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 48)
                        } else {
                            // Safe neighbors — highlight in signal colour
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 48, safeHighlight: true)
                        }
                    }
                    Text("Inverted: 5 safe")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.50))
                }
            }
        } bodyText: {
            Text("Signals are inverted here. Numbers count **safe** neighbors, not hazards. High numbers mean safety.")
        }
    }
}

// MARK: - Biome 6: Coral Basin (1 page)

private extension BiomeMechanicView {

    func coralBasinPages() -> [AnyView] {
        [AnyView(coralBasinPage1)]
    }

    var coralBasinPage1: some View {
        pageShell(title: "Sonar Tiles", isFirst: true, isLast: true) {
            VStack(spacing: 12) {
                // Sonar tile in center with 4 directional labels
                ZStack {
                    // Central sonar tile
                    BMTMiniTile(state: .sonar(n: 1, s: 0, e: 2, w: 0), theme: theme, tileSize: 72)

                    // Direction arrows + counts
                    // North
                    VStack {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9, weight: .bold))
                            Text("N:1")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(theme.signalColor)
                        .padding(4)
                        .background(parchmentBrown.opacity(0.15))
                        .cornerRadius(4)
                        .offset(y: -58)
                        Spacer()
                    }

                    // South
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .bold))
                            Text("S:0")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(parchmentBrown.opacity(0.45))
                        .padding(4)
                        .background(parchmentBrown.opacity(0.10))
                        .cornerRadius(4)
                        .offset(y: 58)
                    }

                    // West
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 9, weight: .bold))
                            Text("W:0")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(parchmentBrown.opacity(0.45))
                        .padding(4)
                        .background(parchmentBrown.opacity(0.10))
                        .cornerRadius(4)
                        .offset(x: -68)
                        Spacer()
                    }

                    // East
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("E:2")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(theme.signalColor)
                        .padding(4)
                        .background(parchmentBrown.opacity(0.15))
                        .cornerRadius(4)
                        .offset(x: 68)
                    }
                }
                .frame(width: 220, height: 160)
            }
        } bodyText: {
            Text("Sonar tiles count hazards in four directions — north, south, east, west. Use them to narrow down positions.")
        }
    }
}

// MARK: - Biome 7: Quicksand (1 page)

private extension BiomeMechanicView {

    func quicksandPages() -> [AnyView] {
        [AnyView(quicksandPage1)]
    }

    var quicksandPage1: some View {
        pageShell(title: "Fading Signals", isFirst: true, isLast: true) {
            HStack(alignment: .center, spacing: 28) {
                VStack(spacing: 8) {
                    BMTMiniTile(state: .revealed(signal: 3), theme: theme, tileSize: 68, fadingSignal: true)
                    Text("Fading…")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.35))

                VStack(spacing: 8) {
                    BMTMiniTile(state: .hidden, theme: theme, tileSize: 68, isPulsing: true)
                    Text("Scan any tile")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.35))

                VStack(spacing: 8) {
                    BMTMiniTile(state: .revealed(signal: 3), theme: theme, tileSize: 68)
                    Text("Refreshed")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                }
            }
        } bodyText: {
            Text("Signals fade over time. Scan any hidden tile to bring all faded numbers back.")
        }
    }
}

// MARK: - Biome 8: The Delta (1 page)

private extension BiomeMechanicView {

    func theDeltaPages() -> [AnyView] {
        [AnyView(theDeltaPage1)]
    }

    var theDeltaPage1: some View {
        pageShell(title: "The Confluence", isFirst: true, isLast: true) {
            // Mini-board showing several different special tile types together
            VStack(spacing: 4) {
                BMTMiniGrid(rows: 3, cols: 4, tileSize: 52, spacing: 5) { row, col in
                    switch (row, col) {
                    case (0, 0): BMTMiniTile(state: .fogged(rangeLow: 1, rangeHigh: 3), theme: theme, tileSize: 52)
                    case (0, 1): BMTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 52)
                    case (0, 2): BMTMiniTile(state: .linkedDisplaying(signal: 1), theme: theme, tileSize: 52)
                    case (0, 3): BMTMiniTile(state: .hidden, theme: theme, tileSize: 52)
                    case (1, 0): BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 52)
                    case (1, 1): BMTMiniTile(state: .locked, theme: theme, tileSize: 52)
                    case (1, 2): BMTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 52)
                    case (1, 3): BMTMiniTile(state: .hidden, theme: theme, tileSize: 52, hazardHint: true)
                    case (2, 0): BMTMiniTile(state: .sonar(n: 0, s: 1, e: 1, w: 0), theme: theme, tileSize: 52)
                    case (2, 1): BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 52)
                    case (2, 2): BMTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 52)
                    default:     BMTMiniTile(state: .hidden, theme: theme, tileSize: 52)
                    }
                }
                // Legend row
                HStack(spacing: 12) {
                    legendItem(symbol: "~", label: "Fog")
                    legendItem(symbol: "◈", label: "Linked")
                    legendItem(symbol: "🔒", label: "Locked")
                    legendItem(symbol: "⊕", label: "Sonar")
                }
                .padding(.top, 10)
            }
        } bodyText: {
            Text("The final chapter. Multiple mechanics combine in each level. Use everything you've learned.")
        }
    }

    func legendItem(symbol: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 12))
                .foregroundColor(theme.signalColor)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(parchmentBrown.opacity(0.55))
        }
    }
}

// MARK: - BMTTileState

/// Tile display states used only in BiomeMechanicView illustrations.
private enum BMTTileState {
    case hidden
    case revealed(signal: Int?)
    case tagged
    case locked
    case fogged(rangeLow: Int, rangeHigh: Int)
    case linkedDisplaying(signal: Int)
    case sonar(n: Int, s: Int, e: Int, w: Int)
}

// MARK: - BMTMiniTile

/// Lightweight illustration tile for BiomeMechanicView.
/// Uses the BIOME'S OWN theme colours and textures (unlike HowToPlayView which
/// always uses Training Range palette).
///
/// Rendering mirrors TileView: overscale-and-clip watercolour texture technique.
private struct BMTMiniTile: View {

    let state:    BMTTileState
    let theme:    BiomeTheme
    var tileSize: CGFloat = 48

    // Optional visual modifiers
    var isPulsing:     Bool = false   // hidden tile pulse glow
    var hazardHint:    Bool = false   // amber tint = likely hazard
    var safeHighlight: Bool = false   // green ring = safe neighbor (Underside page)
    var pulseGlow:     Bool = false   // biome-color glow (Bioluminescence page)
    var fadingSignal:  Bool = false   // low opacity on signal number (Quicksand page)

    @State private var pulseScale: CGFloat = 1.0

    private var shape: TileBackgroundShape {
        TileBackgroundShape(isHex: false, cornerRadius: 5)
    }

    var body: some View {
        ZStack {
            switch state {
            case .hidden:
                hiddenView
            case .revealed(let signal):
                revealedView(signal: signal)
            case .tagged:
                taggedView
            case .locked:
                lockedView
            case .fogged(let lo, let hi):
                foggedView(low: lo, high: hi)
            case .linkedDisplaying(let sig):
                linkedView(signal: sig)
            case .sonar(let n, let s, let e, let w):
                sonarView(n: n, s: s, e: e, w: w)
            }
        }
        .frame(width: tileSize, height: tileSize)
        .scaleEffect(pulseScale)
        .onAppear {
            guard isPulsing else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }

    // MARK: Hidden

    @ViewBuilder
    private var hiddenView: some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)

        if hazardHint {
            shape.fill(Color(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255).opacity(0.28))
            shape.strokeBorder(
                Color(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255).opacity(0.85),
                lineWidth: 2.0
            )
        } else if safeHighlight {
            shape.strokeBorder(
                Color(red: 0x60/255, green: 0xCC/255, blue: 0x80/255).opacity(0.85),
                lineWidth: 2.0
            )
            shape.fill(Color(red: 0x60/255, green: 0xCC/255, blue: 0x80/255).opacity(0.15))
        } else if pulseGlow {
            shape.fill(theme.signalColor.opacity(0.20))
            shape.strokeBorder(theme.signalColor.opacity(0.70), lineWidth: 1.5)
        } else if isPulsing {
            shape.fill(theme.signalColor.opacity(0.14))
            shape.strokeBorder(theme.signalColor.opacity(0.90), lineWidth: 2.0)
        } else {
            shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        }
    }

    // MARK: Revealed

    @ViewBuilder
    private func revealedView(signal: Int?) -> some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.28)

        let overlayOpacity: Double = (signal == nil) ? 0.60 : 0.75
        shape.fill(theme.revealedOverlayColor.opacity(overlayOpacity))
        shape.strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)

        if let sig = signal {
            Text("\(sig)")
                .font(.system(size: tileSize * 0.42, weight: .bold, design: .rounded))
                .foregroundColor(theme.signalColor.opacity(fadingSignal ? 0.28 : 1.0))
        }
    }

    // MARK: Tagged

    @ViewBuilder
    private var taggedView: some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)

        shape.fill(theme.flagAccentColor.opacity(0.40))
            .blur(radius: 7)
        shape.strokeBorder(theme.flagAccentColor, lineWidth: 2.0)

        Text("◆")
            .font(.system(size: tileSize * 0.40, weight: .bold))
            .foregroundColor(theme.flagAccentColor)
    }

    // MARK: Locked

    @ViewBuilder
    private var lockedView: some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.35)

        shape.fill(Color.black.opacity(0.30))
        shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)

        Image(systemName: "lock.fill")
            .font(.system(size: tileSize * 0.35, weight: .medium))
            .foregroundColor(.white.opacity(0.60))
    }

    // MARK: Fogged

    @ViewBuilder
    private func foggedView(low: Int, high: Int) -> some View {
        // Revealed base (the tile is revealed but its exact count is obscured)
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.28)

        shape.fill(theme.revealedOverlayColor.opacity(0.75))

        // Dashed border — the visual tell for a fogged tile
        shape.strokeBorder(
            theme.signalColor.opacity(0.70),
            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
        )

        // Range text
        Text("\(low)–\(high)")
            .font(.system(size: tileSize * 0.30, weight: .bold, design: .rounded))
            .foregroundColor(theme.signalColor.opacity(0.80))
    }

    // MARK: Linked

    @ViewBuilder
    private func linkedView(signal: Int) -> some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.28)

        shape.fill(theme.revealedOverlayColor.opacity(0.75))
        shape.strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)

        // Signal number
        Text("\(signal)")
            .font(.system(size: tileSize * 0.38, weight: .bold, design: .rounded))
            .foregroundColor(theme.signalColor)

        // Small dot in top-left corner — linked pair indicator
        GeometryReader { geo in
            Circle()
                .fill(theme.signalColor)
                .frame(width: tileSize * 0.18, height: tileSize * 0.18)
                .offset(x: tileSize * 0.10, y: tileSize * 0.10)
        }
    }

    // MARK: Sonar

    @ViewBuilder
    private func sonarView(n: Int, s: Int, e: Int, w: Int) -> some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.28)

        shape.fill(theme.revealedOverlayColor.opacity(0.75))
        shape.strokeBorder(theme.signalColor.opacity(0.60), lineWidth: 1.0)

        // Four counts arranged N/S/E/W in a 2×2 grid layout
        VStack(spacing: 0) {
            Text("\(n)")
                .font(.system(size: tileSize * 0.22, weight: .bold, design: .rounded))
            HStack(spacing: tileSize * 0.08) {
                Text("\(w)")
                    .font(.system(size: tileSize * 0.22, weight: .bold, design: .rounded))
                Spacer()
                Text("\(e)")
                    .font(.system(size: tileSize * 0.22, weight: .bold, design: .rounded))
            }
            .frame(width: tileSize * 0.60)
            Text("\(s)")
                .font(.system(size: tileSize * 0.22, weight: .bold, design: .rounded))
        }
        .foregroundColor(theme.signalColor)
    }
}

// MARK: - BMTMiniGrid

/// Uniform grid for BMTMiniTile illustrations.
private struct BMTMiniGrid<Content: View>: View {

    let rows:     Int
    let cols:     Int
    var tileSize: CGFloat = 48
    var spacing:  CGFloat = 4
    @ViewBuilder let content: (Int, Int) -> Content

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        content(row, col)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Fog Marsh") {
    BiomeMechanicView(biomeId: 1)
}

#Preview("Frozen Mirrors") {
    BiomeMechanicView(biomeId: 3)
}

#Preview("The Delta") {
    BiomeMechanicView(biomeId: 8)
}
