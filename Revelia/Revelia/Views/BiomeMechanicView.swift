// Revelia/Views/BiomeMechanicView.swift
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
    @State private var didPersistDontShowAgain = false

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
                .frame(maxWidth: .infinity)
                .frame(height: 590)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .zIndex(1)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 520, height: 660)
        .onDisappear {
            persistDontShowAgainIfNeeded()
        }
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
        persistDontShowAgainIfNeeded()
        dismiss()
    }

    private func persistDontShowAgainIfNeeded() {
        guard dontShowAgain, !didPersistDontShowAgain else { return }
        didPersistDontShowAgain = true
        DispatchQueue.main.async {
            onDontShowAgain?()
        }
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
            Button { gotIt() } label: {
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
            VStack(spacing: 18) {
                // Two tiles connected by a line — Tile A shows "2", Tile B shows "1"
                HStack(alignment: .center, spacing: 0) {
                    VStack(spacing: 6) {
                        BMTMiniTile(state: .linkedDisplaying(signal: 2), theme: theme, tileSize: 68)
                        Text("Tile A")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.60))
                        Text("displays \"2\"")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.42))
                    }
                    // Visual link line
                    Rectangle()
                        .fill(theme.signalColor.opacity(0.45))
                        .frame(width: 36, height: 2)
                    VStack(spacing: 6) {
                        BMTMiniTile(state: .linkedDisplaying(signal: 1), theme: theme, tileSize: 68)
                        Text("Tile B")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.60))
                        Text("displays \"1\"")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.42))
                    }
                }

                // Actual neighbor counts — dotted-border boxes
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Tile A's neighbors")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.60))
                        Text("1 hazard")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(parchmentBrown.opacity(0.28),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    )

                    VStack(spacing: 4) {
                        Text("Tile B's neighbors")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.60))
                        Text("2 hazards")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(parchmentBrown.opacity(0.28),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    )
                }
            }
        } bodyText: {
            Text("Linked tiles swap signals. Each tile shows its PARTNER's count, not its own.")
        }
    }

    var frozenMirrorsPage2: some View {
        pageShell(title: "How to Read Them", isLast: true) {
            VStack(spacing: 16) {
                // Both tiles side by side with arrows showing the cross-reference
                HStack(alignment: .center, spacing: 12) {
                    VStack(spacing: 6) {
                        BMTMiniTile(state: .linkedDisplaying(signal: 2), theme: theme, tileSize: 64)
                        Text("Tile A")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.55))
                        Text("shows \"2\"")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.42))
                    }

                    // Cross-reference arrows
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("B's count")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(parchmentBrown.opacity(0.48))
                            Image(systemName: "arrow.left")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.signalColor.opacity(0.85))
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.signalColor.opacity(0.85))
                            Text("A's count")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(parchmentBrown.opacity(0.48))
                        }
                    }

                    VStack(spacing: 6) {
                        BMTMiniTile(state: .linkedDisplaying(signal: 1), theme: theme, tileSize: 64)
                        Text("Tile B")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.55))
                        Text("shows \"1\"")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.42))
                    }
                }

                // Swap summary table
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("A displays 2")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.60))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(theme.signalColor)
                        Text("B has 2 hazards nearby")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.80))
                    }
                    HStack(spacing: 6) {
                        Text("B displays 1")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.60))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(theme.signalColor)
                        Text("A has 1 hazard nearby")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.80))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(parchmentBrown.opacity(0.08))
                .cornerRadius(8)
            }
        } bodyText: {
            Text("When you see a number on a linked tile, think: this count belongs to the OTHER tile's neighborhood. Look for the dot in the corner to spot linked pairs.")
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
            // Three-state progression: locked → partially revealed → unlocked
            HStack(alignment: .top, spacing: 10) {

                // State 1: All neighbors hidden, needs 3
                VStack(spacing: 6) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 40, spacing: 3) { row, col in
                        if row == 1 && col == 1 {
                            BMTMiniTile(state: .lockedWithCount(3), theme: theme, tileSize: 40)
                        } else {
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 40)
                        }
                    }
                    Text("3 neighbors\nneeded")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.30))
                    .padding(.top, 56)

                // State 2: 2 neighbors revealed, 1 more needed
                VStack(spacing: 6) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 40, spacing: 3) { row, col in
                        if row == 1 && col == 1 {
                            BMTMiniTile(state: .lockedWithCount(1), theme: theme, tileSize: 40)
                        } else if (row == 0 && col == 0) || (row == 0 && col == 1) {
                            BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 40)
                        } else {
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 40)
                        }
                    }
                    Text("2 of 3\nrevealed")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.30))
                    .padding(.top, 56)

                // State 3: Unlocked — tile now scannable
                VStack(spacing: 6) {
                    BMTMiniGrid(rows: 3, cols: 3, tileSize: 40, spacing: 3) { row, col in
                        if row == 1 && col == 1 {
                            BMTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 40)
                        } else if row == 0 || (row == 1 && col == 0) || (row == 1 && col == 2) {
                            BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 40)
                        } else {
                            BMTMiniTile(state: .hidden, theme: theme, tileSize: 40)
                        }
                    }
                    Text("Unlocked!")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.signalColor)
                }
            }
        } bodyText: {
            Text("Locked tiles show a number — that's how many neighbors you need to reveal to unlock them. Plan your path carefully.")
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
            VStack(spacing: 14) {
                // 3×3 grid: center tile shows "5", 5 revealed safe neighbors, 3 hazard neighbors
                // Hazards at corners (0,0), (0,2), (2,1) — rest are safe revealed tiles
                BMTMiniGrid(rows: 3, cols: 3, tileSize: 52, spacing: 4) { row, col in
                    if row == 1 && col == 1 {
                        // Center — inverted tile counting 5 safe neighbors
                        BMTMiniTile(state: .revealed(signal: 5), theme: theme, tileSize: 52)
                    } else if (row == 0 && col == 0) || (row == 0 && col == 2) || (row == 2 && col == 1) {
                        // 3 hazard neighbors — amber tint
                        BMTMiniTile(state: .hidden, theme: theme, tileSize: 52, hazardHint: true)
                    } else {
                        // 5 safe neighbors — shown as revealed tiles
                        BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 52)
                    }
                }

                // Comparison line
                VStack(spacing: 5) {
                    HStack(spacing: 6) {
                        Text("Normal signal:")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.45))
                        Text("counts hazards → would show 3")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.45))
                            .strikethrough(true, color: parchmentBrown.opacity(0.35))
                    }
                    HStack(spacing: 6) {
                        Text("The Underside:")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(parchmentBrown.opacity(0.80))
                        HStack(spacing: 4) {
                            Text("counts SAFE tiles → shows")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(parchmentBrown.opacity(0.80))
                            Text("5")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(theme.signalColor)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(parchmentBrown.opacity(0.08))
                .cornerRadius(8)
            }
        } bodyText: {
            Text("Here, signals count safe neighbors instead of hazards. A high number means SAFETY — the opposite of what you're used to.")
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
            // Cross-shaped board: sonar tile in center with tiles along each arm.
            // N arm: safe → hazard   E arm: hazard   S arm: hazard   W arm: safe
            // Total hazards in all directions = 3  →  sonar tile shows "3"
            let ts: CGFloat = 36
            let sp: CGFloat = 3
            let pulseColor = theme.signalColor.opacity(0.55)

            return VStack(spacing: 0) {
                // N label
                Text("N")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(parchmentBrown.opacity(0.45))
                    .padding(.bottom, 3)

                // N arm — 2 tiles
                VStack(spacing: sp) {
                    BMTMiniTile(state: .hidden, theme: theme, tileSize: ts, hazardHint: true) // hazard
                    BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: ts)    // safe
                }

                // Horizontal pulse line north
                Rectangle().fill(pulseColor).frame(width: 2, height: 3)

                // Center row: W label · W arm · pulse · sonar · pulse · E arm · E label
                HStack(spacing: 0) {
                    Text("W")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.45))
                        .frame(width: 18)
                    // W arm — 1 safe tile
                    BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: ts)
                    Rectangle().fill(pulseColor).frame(width: 3, height: 2)
                    // Sonar center — single combined total "3"
                    BMTMiniTile(state: .sonarTotal(3), theme: theme, tileSize: ts + 6)
                    Rectangle().fill(pulseColor).frame(width: 3, height: 2)
                    // E arm — 1 hazard tile
                    BMTMiniTile(state: .hidden, theme: theme, tileSize: ts, hazardHint: true)
                    Text("E")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.45))
                        .frame(width: 18)
                }

                // Vertical pulse line south
                Rectangle().fill(pulseColor).frame(width: 2, height: 3)

                // S arm — 2 tiles
                VStack(spacing: sp) {
                    BMTMiniTile(state: .hidden, theme: theme, tileSize: ts, hazardHint: true) // hazard
                    BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: ts)    // safe
                }

                // S label
                Text("S")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(parchmentBrown.opacity(0.45))
                    .padding(.top, 3)
            }
        } bodyText: {
            Text("Sonar tiles scan in four directions — north, south, east, west. The number is the total hazard count across all four lines. Watch the pulse to see which directions are being scanned.")
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
            // Mini-board: all mechanics co-existing in one grid.
            // Row 0: fogged tile · hidden · linked A · linked B (connected pair)
            // Row 1: revealed · locked(needs 2) · revealed · hazard
            // Row 2: sonar(total 2) · revealed · revealed · hidden
            VStack(spacing: 6) {
                BMTMiniGrid(rows: 3, cols: 4, tileSize: 48, spacing: 4) { row, col in
                    switch (row, col) {
                    // Row 0
                    case (0, 0): BMTMiniTile(state: .fogged(rangeLow: 2, rangeHigh: 3), theme: theme, tileSize: 48)
                    case (0, 1): BMTMiniTile(state: .hidden, theme: theme, tileSize: 48)
                    case (0, 2): BMTMiniTile(state: .linkedDisplaying(signal: 2), theme: theme, tileSize: 48)
                    case (0, 3): BMTMiniTile(state: .linkedDisplaying(signal: 1), theme: theme, tileSize: 48)
                    // Row 1
                    case (1, 0): BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 48)
                    case (1, 1): BMTMiniTile(state: .lockedWithCount(2), theme: theme, tileSize: 48)
                    case (1, 2): BMTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 48)
                    case (1, 3): BMTMiniTile(state: .hidden, theme: theme, tileSize: 48, hazardHint: true)
                    // Row 2
                    case (2, 0): BMTMiniTile(state: .sonarTotal(2), theme: theme, tileSize: 48)
                    case (2, 1): BMTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 48)
                    case (2, 2): BMTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 48)
                    default:     BMTMiniTile(state: .hidden, theme: theme, tileSize: 48)
                    }
                }
                // Compact legend
                HStack(spacing: 14) {
                    legendItem(symbol: "~", label: "Fog")
                    legendItem(symbol: "◈", label: "Linked")
                    legendItem(symbol: "🔒", label: "Locked")
                    legendItem(symbol: "⊕", label: "Sonar")
                }
                .padding(.top, 8)
            }
        } bodyText: {
            Text("The final chapter. Each level layers two or more mechanics you've already learned. Trust your instincts and take it slow.")
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
    case lockedWithCount(Int)                       // locked tile showing neighbors-needed count
    case fogged(rangeLow: Int, rangeHigh: Int)
    case linkedDisplaying(signal: Int)
    case sonar(n: Int, s: Int, e: Int, w: Int)
    case sonarTotal(Int)                            // sonar tile showing single combined total
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
            case .lockedWithCount(let n):
                lockedWithCountView(n: n)
            case .fogged(let lo, let hi):
                foggedView(low: lo, high: hi)
            case .linkedDisplaying(let sig):
                linkedView(signal: sig)
            case .sonar(let n, let s, let e, let w):
                sonarView(n: n, s: s, e: e, w: w)
            case .sonarTotal(let total):
                sonarTotalView(total: total)
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

    // MARK: Locked With Count

    @ViewBuilder
    private func lockedWithCountView(n: Int) -> some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.35)
        shape.fill(Color.black.opacity(0.30))
        shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        VStack(spacing: 0) {
            Image(systemName: "lock.fill")
                .font(.system(size: tileSize * 0.20, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Text("\(n)")
                .font(.system(size: tileSize * 0.32, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: Sonar Total (single combined count)

    @ViewBuilder
    private func sonarTotalView(total: Int) -> some View {
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.28)
        shape.fill(theme.revealedOverlayColor.opacity(0.75))
        shape.strokeBorder(theme.signalColor.opacity(0.70), lineWidth: 1.5)
        Text("\(total)")
            .font(.system(size: tileSize * 0.38, weight: .bold, design: .rounded))
            .foregroundColor(theme.signalColor)
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
