// Signalfield/Views/HowToPlayView.swift
//
// "How to Play" — 6-page swipeable parchment guide.
// Presented as a .sheet() from WelcomeView (TitleSplashView).
//
// Self-contained: reads BiomeTheme and reuses TileBackgroundShape for tile
// illustrations, but has ZERO dependency on game engine, board state,
// GameViewModel, or any live game data.
//
// Illustration approach mirrors TileView.swift rendering:
//   - Hidden tile:  watercolour texture, scaleEffect(1.35), clipShape
//   - Revealed tile: texture at low opacity + revealedOverlayColor fill + signal number
//   - Tagged tile:   flagAccentColor border + glow + ◆ symbol

import SwiftUI

// MARK: - HowToPlayView

struct HowToPlayView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage       = 0
    /// Tracks swipe direction so the slide transition enters from the correct edge.
    @State private var navigatingForward = true
    private let totalPages = 6

    // Training Range palette — biome 0
    private let theme = BiomeTheme.theme(for: 0)

    // Palette
    private let parchmentBrown = Color(red: 0x4A / 255, green: 0x3A / 255, blue: 0x28 / 255)
    private let meadowGreen    = Color(red: 0x7A / 255, green: 0xAA / 255, blue: 0x58 / 255)
    private let dotFilled      = Color(red: 0x6B / 255, green: 0x5B / 255, blue: 0x3E / 255)
    private let dotEmpty       = Color(red: 0x6B / 255, green: 0x5B / 255, blue: 0x3E / 255).opacity(0.30)

    var body: some View {
        ZStack {
            // ── Parchment background ──────────────────────────────────────────────
            // Overscale + clip crops the painted border of the ParchmentCard asset
            // so only the clean centre texture fills the sheet.
            Image("ParchmentCard")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.15)
                .frame(width: 520, height: 660)
                .clipped()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── One-at-a-time page display with asymmetric slide transition ───
                // Each page is shown via a switch so only one view is in the
                // hierarchy at a time. .id(currentPage) forces SwiftUI to treat
                // the incoming page as a brand-new view, triggering the transitions.
                // navigatingForward controls which edge each page enters/exits from.
                ZStack {
                    Group {
                        switch currentPage {
                        case 0:  page1
                        case 1:  page2
                        case 2:  page3
                        case 3:  page4
                        case 4:  page5
                        default: page6
                        }
                    }
                    .id(currentPage)
                    .transition(.asymmetric(
                        insertion: .move(edge: navigatingForward ? .trailing : .leading),
                        removal:   .move(edge: navigatingForward ? .leading  : .trailing)
                    ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(.easeInOut(duration: 0.28), value: currentPage)

                // ── Custom page dots (warm brown ◆) ──────────────────────────────
                HStack(spacing: 10) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Text("◆")
                            .font(.system(size: index == currentPage ? 11 : 7))
                            .foregroundColor(index == currentPage ? dotFilled : dotEmpty)
                            .animation(.easeInOut(duration: 0.20), value: currentPage)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .frame(width: 520, height: 660)
    }

    // MARK: - Navigation helpers

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

    // MARK: - Page shell
    // Each page uses this wrapper: parchment background is shared, the shell
    // adds the ✕ button, title, illustration hero, body text, and the
    // navigation row (Back + Next, or Start Playing on the last page).

    @ViewBuilder
    private func pageShell<I: View, B: View>(
        title: String,
        isFirst: Bool = false,
        isLast:  Bool = false,
        @ViewBuilder illustration: () -> I,
        @ViewBuilder bodyText: () -> B
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {

                // Title
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(parchmentBrown)
                    .multilineTextAlignment(.center)
                    .padding(.top, 38)
                    .padding(.horizontal, 32)

                Spacer(minLength: 10)

                // Illustration hero — aims for ~55 % of usable height
                illustration()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)

                Spacer(minLength: 8)

                // Body text
                bodyText()
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(parchmentBrown.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)

                Spacer(minLength: 8)

                // ── Navigation row ────────────────────────────────────────────────
                // Back (left) + Next or Start Playing (right).
                // Keyboard shortcuts: ← / → arrow keys navigate; Return confirms
                // the primary action on the last page.
                HStack(alignment: .center) {

                    // Back — hidden on the first page; a fixed spacer keeps the
                    // Next button right-aligned even when Back is absent.
                    if !isFirst {
                        Button {
                            retreat()
                        } label: {
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
                        // Invisible placeholder keeps HStack balanced
                        Color.clear.frame(width: 80, height: 36)
                    }

                    Spacer()

                    // Next (middle pages) or Start Playing (last page)
                    if isLast {
                        Button {
                            dismiss()
                        } label: {
                            Text("Start Playing")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 180, height: 40)
                                .background(meadowGreen)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                    } else {
                        Button {
                            advance()
                        } label: {
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

            // ✕ close button — present on every page
            Button {
                dismiss()
            } label: {
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

    // MARK: - Page 1 — The Field

    private var page1: some View {
        pageShell(title: "The Field", isFirst: true) {
            // 4×4 grid of hidden tiles. One tile pulses with a glow suggesting "tap me."
            HTMiniGrid(rows: 4, cols: 4) { row, col in
                let isPulsing = (row == 1 && col == 2)
                HTMiniTile(state: .hidden, theme: theme, isPulsing: isPulsing)
            }
            .padding(.horizontal, 80)
        } bodyText: {
            Text("Every tile hides something. Most are safe. Some are hazards. Your job: find the safe ones without hitting a hazard.")
        }
    }

    // MARK: - Page 2 — Scanning

    private var page2: some View {
        pageShell(title: "Scanning") {
            HStack(alignment: .center, spacing: 18) {

                // Before: all hidden
                VStack(spacing: 8) {
                    Text("Before")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                    HTMiniGrid(rows: 4, cols: 4) { _, _ in
                        HTMiniTile(state: .hidden, theme: theme)
                    }
                }

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(parchmentBrown.opacity(0.40))

                // After: cascade opened a cluster
                VStack(spacing: 8) {
                    Text("After")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(parchmentBrown.opacity(0.55))
                    HTMiniGrid(rows: 4, cols: 4) { row, col in
                        // Opened cluster in top-left; right column still hidden
                        switch (row, col) {
                        case (0, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme)
                        case (0, 1): HTMiniTile(state: .revealed(signal: nil), theme: theme)
                        case (0, 2): HTMiniTile(state: .revealed(signal: 1),   theme: theme)
                        case (1, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme)
                        case (1, 1): HTMiniTile(state: .revealed(signal: nil), theme: theme)
                        case (1, 2): HTMiniTile(state: .revealed(signal: 2),   theme: theme)
                        case (2, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme)
                        case (2, 1): HTMiniTile(state: .revealed(signal: 1),   theme: theme)
                        default:     HTMiniTile(state: .hidden,                theme: theme)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
        } bodyText: {
            Text("Tap a tile to scan it. Your first scan is always safe — and might open up a whole area at once. Blank tiles mean no hazards nearby.")
        }
    }

    // MARK: - Page 3 — Reading Signals

    private var page3: some View {
        pageShell(title: "Reading Signals") {
            // Zoomed 3×3: center shows "1"; all 8 neighbors highlighted with a warm ring.
            HTMiniGrid(rows: 3, cols: 3, tileSize: 62, spacing: 5) { row, col in
                if row == 1 && col == 1 {
                    HTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 62)
                } else {
                    HTMiniTile(state: .hidden, theme: theme, tileSize: 62,
                               neighborHighlight: true)
                }
            }
            .padding(.horizontal, 100)
        } bodyText: {
            Text("This 1 means exactly one of the eight tiles around it hides a hazard.")
        }
    }

    // MARK: - Page 4 — Deduction

    private var page4: some View {
        pageShell(title: "Deduction") {
            // "1" center, 7 neighbors revealed, 1 hidden (top-right) with hazard glow.
            // Signal layout (row×col → signal):
            //   (0,0)→nil  (0,1)→nil  (0,2)→HIDDEN/HAZARD
            //   (1,0)→nil  (1,1)→ 1   (1,2)→1
            //   (2,0)→nil  (2,1)→nil  (2,2)→nil
            HTMiniGrid(rows: 3, cols: 3, tileSize: 62, spacing: 5) { row, col in
                switch (row, col) {
                case (1, 1):
                    HTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 62)
                case (0, 2):
                    // Single hidden tile — must be the hazard
                    HTMiniTile(state: .hidden, theme: theme, tileSize: 62,
                               hazardHint: true)
                case (0, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (0, 1): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (1, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (1, 2): HTMiniTile(state: .revealed(signal: 1),   theme: theme, tileSize: 62)
                case (2, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (2, 1): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (2, 2): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                default:     HTMiniTile(state: .hidden,                theme: theme, tileSize: 62)
                }
            }
            .padding(.horizontal, 100)
        } bodyText: {
            VStack(spacing: 6) {
                // Markdown bold (**MUST**) avoids the deprecated Text + operator
                // and works on macOS 12+ (well within the macOS 13+ deployment target).
                Text("This 1 has only one hidden neighbor left. That tile **MUST** be the hazard.")
                    .font(.system(size: 14, design: .rounded))

                Text("That's the core of the game — use the signals to figure out which tiles are dangerous.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(parchmentBrown.opacity(0.60))
            }
        }
    }

    // MARK: - Page 5 — Tagging

    private var page5: some View {
        pageShell(title: "Tagging") {
            // Same 3×3 as page 4, but the hazard tile now carries a confirmed tag.
            HTMiniGrid(rows: 3, cols: 3, tileSize: 62, spacing: 5) { row, col in
                switch (row, col) {
                case (1, 1):
                    HTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 62)
                case (0, 2):
                    // Hazard is now confirmed-tagged (◆)
                    HTMiniTile(state: .tagged, theme: theme, tileSize: 62)
                case (0, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (0, 1): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (1, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (1, 2): HTMiniTile(state: .revealed(signal: 1),   theme: theme, tileSize: 62)
                case (2, 0): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (2, 1): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                case (2, 2): HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 62)
                default:     HTMiniTile(state: .hidden,                theme: theme, tileSize: 62)
                }
            }
            .padding(.horizontal, 100)
        } bodyText: {
            Text("Found a hazard? Right-click to tag it. Tagged tiles are locked — you can't accidentally scan them.")
        }
    }

    // MARK: - Page 6 — Winning

    private var page6: some View {
        pageShell(title: "Winning", isLast: true) {
            VStack(spacing: 20) {

                // Three gold stars
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            .shadow(
                                color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.55),
                                radius: 8, x: 0, y: 0
                            )
                    }
                }

                // A completed board: mix of revealed tiles and two confirmed tags
                HTMiniGrid(rows: 3, cols: 4, tileSize: 48, spacing: 5) { row, col in
                    switch (row, col) {
                    // Two tagged hazards
                    case (0, 3): HTMiniTile(state: .tagged,             theme: theme, tileSize: 48)
                    case (2, 1): HTMiniTile(state: .tagged,             theme: theme, tileSize: 48)
                    // Numbered revealed tiles
                    case (0, 2): HTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 48)
                    case (1, 2): HTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 48)
                    case (1, 3): HTMiniTile(state: .revealed(signal: 2), theme: theme, tileSize: 48)
                    case (2, 2): HTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 48)
                    case (0, 1): HTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 48)
                    case (1, 1): HTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 48)
                    case (2, 3): HTMiniTile(state: .revealed(signal: 1), theme: theme, tileSize: 48)
                    // Blank revealed tiles
                    default:     HTMiniTile(state: .revealed(signal: nil), theme: theme, tileSize: 48)
                    }
                }
                .padding(.horizontal, 60)
            }
        } bodyText: {
            Text("Reveal every safe tile or tag every hazard to win. Earn up to 3 stars by playing fast and smart.")
        }
    }
}

// MARK: - HTTileState

/// Tile display state used only within HowToPlayView illustrations.
private enum HTTileState {
    case hidden
    case revealed(signal: Int?)
    case tagged
}

// MARK: - HTMiniTile

/// Lightweight tile illustration for HowToPlayView.
/// Renders hidden, revealed, or confirmed-tagged state using actual
/// Training Range textures from BiomeTheme — matching TileView's rendering
/// technique (overscale → frame → clipShape).
///
/// Has NO dependency on game engine, Tile model, or board state.
private struct HTMiniTile: View {

    let state:   HTTileState
    let theme:   BiomeTheme
    var tileSize: CGFloat = 40

    // Optional visual modifiers
    var isPulsing:        Bool = false   // page 1: "tap me" glow
    var neighborHighlight: Bool = false  // page 3: warm ring on all 8 neighbors
    var hazardHint:       Bool = false   // page 4: faint amber tint/border

    @State private var pulseScale: CGFloat = 1.0

    // Square tile shape, cornerRadius 5 for a slightly rounded look
    // (matches game tiles at illustration scale)
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
        // 1. Watercolour texture — overscale 1.35× then clip (matching TileView)
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)

        // 2. Optional overlays on top of the texture
        if neighborHighlight {
            // Warm golden ring — marks the 8 neighbors in the "Reading Signals" page
            shape.strokeBorder(
                Color(red: 1.0, green: 0.82, blue: 0.40).opacity(0.80),
                lineWidth: 2.0
            )
        } else if hazardHint {
            // Faint amber/rust fill + border — "this must be the hazard" visual cue
            shape.fill(Color(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255).opacity(0.28))
            shape.strokeBorder(
                Color(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255).opacity(0.85),
                lineWidth: 2.0
            )
        } else if isPulsing {
            // Subtle signal-colour glow + border for the "tap me" suggestion
            shape.fill(theme.signalColor.opacity(0.14))
            shape.strokeBorder(theme.signalColor.opacity(0.90), lineWidth: 2.0)
        } else {
            // Normal hidden tile border — barely visible, same as in-game
            shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        }
    }

    // MARK: Revealed

    @ViewBuilder
    private func revealedView(signal: Int?) -> some View {
        // 1. Texture at low opacity so the overlay colour dominates
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)
            .opacity(0.28)

        // 2. Dark biome overlay — same opacity rules as TileView
        let overlayOpacity: Double = (signal == nil) ? 0.60 : 0.75
        shape.fill(theme.revealedOverlayColor.opacity(overlayOpacity))

        // 3. Subtle border
        shape.strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)

        // 4. Signal number
        if let sig = signal {
            Text("\(sig)")
                .font(.system(size: tileSize * 0.42, weight: .bold, design: .rounded))
                .foregroundColor(theme.signalColor)
        }
    }

    // MARK: Tagged (confirmed)

    @ViewBuilder
    private var taggedView: some View {
        // 1. Texture base
        Image(theme.tileTextureName)
            .resizable()
            .scaledToFill()
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(1.35)
            .clipShape(shape)

        // 2. Soft glow behind the border (blurred fill)
        shape.fill(theme.flagAccentColor.opacity(0.40))
            .blur(radius: 7)

        // 3. Solid flag accent border — 2 pt, matches TileView's 1.5 pt scaled up
        shape.strokeBorder(theme.flagAccentColor, lineWidth: 2.0)

        // 4. ◆ diamond symbol in flag accent colour
        Text("◆")
            .font(.system(size: tileSize * 0.40, weight: .bold))
            .foregroundColor(theme.flagAccentColor)
    }
}

// MARK: - HTMiniGrid

/// Lays out a rows×cols grid of HTMiniTile (or any View) with uniform spacing.
/// Used only in HowToPlayView illustrations — no game state involved.
private struct HTMiniGrid<Content: View>: View {

    let rows:     Int
    let cols:     Int
    var tileSize: CGFloat = 40
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

#Preview("How to Play — page 1") {
    HowToPlayView()
}
