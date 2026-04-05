// Revelia/Views/EndOfLevelView.swift
//
// Post-game overlay shown after winning or losing a level.
//
// Both states use a collapsible semi-transparent frosted glass card.
// The board remains fully visible and un-dimmed in both states so the
// player can study it, especially after a loss reveal.
//
// ── Win state ─────────────────────────────────────────────────────────────
//   • Biome-themed particles drift across the background
//   • "Level Clear!" title slides in, stars bloom one at a time
//   • Score counts up from 0 to final value, then pulses gold
//   • Stats and buttons fade in last
//   • Card collapses to a bottom pill so the board can be studied
//
// ── Loss state ────────────────────────────────────────────────────────────
//   • No animations — quiet, understated
//   • Card fades in gently 1.5s after loss (board reveal plays first)
//   • Same collapse mechanic — tap ▼ to minimize, ▲ to restore
//   • Neutral (slightly darker) frosted glass, no color tinting

import SwiftUI

// MARK: - EndOfLevelView

/// Post-game summary shown after winning or losing a level.
/// Rendered as a collapsible overlay on top of the (still-visible) board.
struct EndOfLevelView: View {

    @ObservedObject var viewModel: GameViewModel

    /// Called when the player advances to the next level within the biome.
    /// Nil when the current level is the last one in the biome.
    var onNextLevel: (() -> Void)?

    /// Called when the player returns to the biome map.
    /// Provided instead of onNextLevel when this is the last level in the biome.
    var onReturnToMap: (() -> Void)?

    // MARK: Convenience

    private var isWin: Bool { viewModel.gameState == .won }
    private var biomeId: Int { viewModel.levelSpec.biomeId }
    private var theme: BiomeTheme { BiomeTheme.theme(for: biomeId) }

    // MARK: Collapse State

    /// Whether the card is collapsed to the bottom pill.
    @State private var isCollapsed: Bool = false

    // MARK: Win Animation State

    @State private var cardOpacity:      Double   = 0
    @State private var titleOpacity:     Double   = 0
    @State private var titleOffset:      CGFloat  = -10
    @State private var starScales:       [CGFloat] = [0, 0, 0]
    @State private var starBloomOpacity: [Double]  = [0, 0, 0]
    @State private var scoreVisible:     Bool     = false
    @State private var scoreProgress:    Double   = 0     // 0 → 1 drives countup
    @State private var scoreGlowOpacity: Double   = 0
    @State private var statsOpacity:     Double   = 0
    @State private var buttonsOpacity:   Double   = 0
    @State private var particlesActive:  Bool     = false

    /// Interpolated score value, updated each frame while scoreProgress animates.
    private var displayedScore: Int {
        Int(scoreProgress * Double(max(viewModel.score, 0)))
    }

    // MARK: Loss Stats Helpers

    /// Number of hazards the player correctly tagged before the loss.
    private var hazardsTagged: Int {
        viewModel.board.allCoordinates
            .filter { viewModel.board[$0].isHazard && viewModel.board[$0].hasConfirmedTag }
            .count
    }

    /// Total hazard count on the board (computed from board state after reveal).
    private var totalHazards: Int {
        viewModel.board.allCoordinates
            .filter { viewModel.board[$0].isHazard }
            .count
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // 1. Biome particles (win only) — full bleed, no hit testing.
            if isWin && particlesActive {
                BiomeParticleView(biomeId: biomeId)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            // 2. Expanded card — centered in the ZStack when not collapsed.
            if !isCollapsed {
                Group {
                    if isWin {
                        winCard
                    } else {
                        lossCard
                    }
                }
                .opacity(cardOpacity)
                .transition(.opacity)
            }

            // 3. Collapsed pill — anchored to the bottom via Spacer.
            VStack {
                Spacer()
                if isCollapsed {
                    collapsedPill
                        .padding(.bottom, 28)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .opacity
                        ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isCollapsed)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { scheduleAnimations() }
    }

    // MARK: - Collapsed Pill

    private var collapsedPill: some View {
        HStack(spacing: 10) {
            Text(isWin ? "Level Clear!" : "Hazard Hit")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Image(systemName: "chevron.up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCollapsed = false
            }
        }
    }

    // MARK: - Collapse Button (shared by both cards)

    private var collapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCollapsed = true
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Win Card

    private var winCard: some View {
        VStack(spacing: 0) {

            // ── Title + collapse chevron ───────────────────────────────────
            ZStack(alignment: .trailing) {
                Text("Level Clear!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.50), radius: 4, x: 0, y: 2)
                    .frame(maxWidth: .infinity, alignment: .center)

                collapseButton
            }
            .opacity(titleOpacity)
            .offset(y: titleOffset)
            .padding(.bottom, 18)

            // ── Stars ──────────────────────────────────────────────────────
            starRow
                .padding(.bottom, 18)

            // ── Score countup ──────────────────────────────────────────────
            scoreSection
                .opacity(scoreVisible ? 1.0 : 0.0)
                .padding(.bottom, 8)

            // ── Time (static) ──────────────────────────────────────────────
            Text(formattedTime)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .opacity(statsOpacity)
                .padding(.bottom, 14)

            // ── Stats row ──────────────────────────────────────────────────
            winStatsRow
                .opacity(statsOpacity)
                .padding(.bottom, 18)

            // ── Buttons ────────────────────────────────────────────────────
            buttonRow
                .opacity(buttonsOpacity)
        }
        .padding(28)
        .frame(width: 340)
        .background {
            // Frosted glass with subtle biome-tinted warmth.
            // .opacity(0.45) is applied to the background layer only — foreground
            // content (text, stars, buttons) remains fully opaque.
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .opacity(0.45)
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.signalColor.opacity(0.05))
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.30), radius: 24, x: 0, y: 8)
    }

    // MARK: - Loss Card

    private var lossCard: some View {
        VStack(spacing: 0) {

            // ── Title + collapse chevron ───────────────────────────────────
            ZStack(alignment: .trailing) {
                Text("Hazard Hit")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                collapseButton
            }
            .padding(.bottom, 14)

            // ── Stats ──────────────────────────────────────────────────────
            VStack(spacing: 8) {
                lossStatRow("Time",         value: formattedTime)
                lossStatRow("Actions",      value: "\(viewModel.stats.totalActions)")
                lossStatRow("Tags correct", value: "\(hazardsTagged) / \(totalHazards)")
            }
            .padding(.bottom, 18)

            // ── Buttons ────────────────────────────────────────────────────
            buttonRow
                .opacity(buttonsOpacity)
        }
        .padding(24)
        .frame(width: 320)
        .background {
            // Neutral frosted glass — same transparency level as the win card.
            // Downgraded from .regularMaterial to .ultraThinMaterial and reduced
            // to 0.45 opacity so the board is clearly legible behind it.
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .opacity(0.45)
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.30), radius: 24, x: 0, y: 8)
    }

    // MARK: - Star Row

    private var starRow: some View {
        HStack(spacing: 14) {
            ForEach(0..<viewModel.stars, id: \.self) { i in
                ZStack {
                    // Watercolor-style color wash bloom behind each star
                    Circle()
                        .fill(starColor(for: i))
                        .frame(width: 80, height: 80)
                        .blur(radius: 16)
                        .opacity(starBloomOpacity[i])

                    // Star icon
                    Image(systemName: "star.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(starColor(for: i))
                        .shadow(color: .black.opacity(0.28), radius: 3, x: 0, y: 1)
                        .scaleEffect(starScales[i])
                }
                .frame(width: 56, height: 56)
            }
        }
        .frame(minHeight: 64)
    }

    // MARK: - Score Section

    private var scoreSection: some View {
        VStack(spacing: 3) {
            ZStack {
                // Golden radial glow — expands briefly when score lands
                Text("\(displayedScore)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.843, blue: 0.0))
                    .blur(radius: 10)
                    .opacity(scoreGlowOpacity * 0.65)

                // Primary score text
                Text("\(displayedScore)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.28), radius: 2)
            }

            Text("SCORE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .tracking(2.0)
        }
    }

    // MARK: - Win Stats Row

    private var winStatsRow: some View {
        HStack(spacing: 0) {
            miniStat(label: "Actions", value: "\(viewModel.stats.totalActions)")
            Divider()
                .frame(height: 28)
                .overlay(Color.white.opacity(0.20))
            miniStat(label: "Scans", value: "\(viewModel.stats.scansCount)")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Button Row

    private var buttonRow: some View {
        VStack(spacing: 8) {
            if isWin {
                // Primary — Next Level or Return to Map
                if let action = onNextLevel {
                    Button(action: action) {
                        Text("Next Level")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.flagAccentColor)
                } else if let action = onReturnToMap {
                    Button(action: action) {
                        Text("Return to Map")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.flagAccentColor)
                }

                // Secondary — Retry
                Button(action: { viewModel.retry() }) {
                    Text("Retry")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            } else {
                // Loss primary — Retry
                Button(action: { viewModel.retry() }) {
                    Text("Retry")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.75, green: 0.45, blue: 0.22))

                // Loss secondary — Return to Map (if available)
                if let action = onReturnToMap {
                    Button(action: action) {
                        Text("Return to Map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.50))
                .tracking(0.8)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private func lossStatRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .font(.subheadline.monospacedDigit())
    }

    private var formattedTime: String {
        let total = Int(viewModel.elapsedTime)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Color for the i-th earned star: index 0 = bronze, 1 = silver, 2 = gold.
    private func starColor(for index: Int) -> Color {
        switch index {
        case 0:  return Color(red: 0.804, green: 0.498, blue: 0.196) // bronze #CD7F32
        case 1:  return Color(red: 0.753, green: 0.753, blue: 0.753) // silver #C0C0C0
        default: return Color(red: 1.000, green: 0.843, blue: 0.000) // gold   #FFD700
        }
    }

    // MARK: - Animation Scheduling

    private func scheduleAnimations() {
        guard isWin else {
            // ── Loss path ────────────────────────────────────────────────
            // Delay 1.5s so the hazard-hit pulse and board reveal play first.
            // At 0.5s the board reveal begins (controlled by GameViewModel /
            // TileView via the gameOver flag — not managed here).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) {
                withAnimation(.easeInOut(duration: 0.30)) {
                    cardOpacity = 1.0
                }
                // Loss card shows all content simultaneously as it fades in.
                statsOpacity   = 1.0
                buttonsOpacity = 1.0
            }
            return
        }

        // ── Win path ─────────────────────────────────────────────────────

        // Card fades in immediately
        withAnimation(.easeInOut(duration: 0.30)) {
            cardOpacity = 1.0
        }

        // Particles begin right away
        particlesActive = true

        // Title slides up at 0.3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeOut(duration: 0.28)) {
                titleOpacity = 1.0
                titleOffset  = 0
            }
        }

        // Stars bloom: staggered at 0.7 / 1.1 / 1.5s
        for i in 0..<viewModel.stars {
            let delay = 0.70 + Double(i) * 0.40
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Spring bloom on star icon
                withAnimation(.spring(response: 0.42, dampingFraction: 0.56)) {
                    starScales[i] = 1.0
                }
                // Color wash: bloom in, then fade out
                withAnimation(.easeOut(duration: 0.28)) {
                    starBloomOpacity[i] = 0.55
                }
                withAnimation(.easeIn(duration: 0.50).delay(0.30)) {
                    starBloomOpacity[i] = 0.0
                }
            }
        }

        // Score countup starts at 1.8s; lasts 1.5s → lands at 3.3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.80) {
            scoreVisible = true
            withAnimation(.easeInOut(duration: 1.50)) {
                scoreProgress = 1.0
            }
        }

        // Stats appear + golden score pulse when score lands (3.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.30) {
            withAnimation(.easeInOut(duration: 0.30)) {
                statsOpacity = 1.0
            }
            // Brief golden glow on the score number
            withAnimation(.easeOut(duration: 0.14)) {
                scoreGlowOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.28).delay(0.14)) {
                scoreGlowOpacity = 0.0
            }
        }

        // Buttons fade in at 3.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.50) {
            withAnimation(.easeInOut(duration: 0.30)) {
                buttonsOpacity = 1.0
            }
        }
    }
}

// MARK: - BiomeParticleView

/// Lightweight ambient particle system that drifts themed specks across the
/// victory background.  All positions are stable (seeded from biomeId) so the
/// layout doesn't jump on re-render.
private struct BiomeParticleView: View {

    let biomeId: Int

    private let particles: [ParticleData]
    @State private var animating: Bool = false

    init(biomeId: Int) {
        self.biomeId = biomeId
        let theme = BiomeTheme.theme(for: biomeId)
        let colors = BiomeParticleView.particleColors(biomeId: biomeId, theme: theme)
        var rng = SeededRandom(seed: UInt64(biomeId &* 0x9E3779B9 &+ 97))
        var list: [ParticleData] = []
        for i in 0..<22 {
            list.append(ParticleData(
                id:       i,
                color:    colors[i % colors.count],
                size:     CGFloat.random(in: 3.0...7.0, using: &rng),
                startX:   CGFloat.random(in: 0.04...0.96, using: &rng),
                startY:   CGFloat.random(in: 0.04...0.96, using: &rng),
                driftX:   CGFloat.random(in: -28...28,   using: &rng),
                driftY:   CGFloat.random(in: -65...(-8), using: &rng),
                opacity:  Double.random(in: 0.35...0.72,  using: &rng),
                duration: Double.random(in: 3.5...6.5,    using: &rng),
                delay:    Double.random(in: 0.0...2.5,    using: &rng)
            ))
        }
        self.particles = list
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .blur(radius: p.size > 5.5 ? 0.6 : 0)
                        .opacity(animating ? p.opacity : 0)
                        .offset(
                            x: p.startX * geo.size.width  + (animating ? p.driftX : 0),
                            y: p.startY * geo.size.height + (animating ? p.driftY : 0)
                        )
                        .animation(
                            .easeInOut(duration: p.duration)
                                .repeatForever(autoreverses: true)
                                .delay(p.delay),
                            value: animating
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { animating = true }
    }

    // MARK: Particle color palettes per biome

    private static func particleColors(biomeId: Int, theme: BiomeTheme) -> [Color] {
        switch biomeId % 9 {
        case 0: // Training Range — green leaf / petal tones
            return [theme.signalColor,
                    Color(red: 0.55, green: 0.80, blue: 0.28),
                    Color(red: 0.80, green: 0.92, blue: 0.55)]
        case 1: // Fog Marsh — seafoam wisps + watery blue
            return [theme.signalColor,
                    Color.white.opacity(0.70),
                    Color(red: 0.38, green: 0.68, blue: 0.64)]
        case 2: // Bioluminescence — electric cyan specks + sparks
            return [theme.signalColor,
                    Color.white.opacity(0.80),
                    Color(red: 0.28, green: 0.92, blue: 0.96)]
        case 3: // Frozen Mirrors — white snow + pale ice blue
            return [Color.white.opacity(0.90),
                    Color.white.opacity(0.60),
                    Color(red: 0.72, green: 0.88, blue: 0.98)]
        case 4: // Ruins — warm gold dust + sandy stone
            return [theme.signalColor,
                    Color(red: 0.88, green: 0.72, blue: 0.40),
                    Color(red: 0.78, green: 0.62, blue: 0.32)]
        case 5: // The Underside — purple mineral sparks + crystal glimmers
            return [theme.signalColor,
                    Color(red: 0.58, green: 0.38, blue: 0.88),
                    Color.white.opacity(0.55)]
        case 6: // Coral Basin — bubble pinks + tropical teal
            return [theme.signalColor,
                    Color.white.opacity(0.65),
                    Color(red: 0.28, green: 0.74, blue: 0.72)]
        case 7: // Quicksand — amber sand grains + dust wisps
            return [theme.signalColor,
                    Color(red: 0.84, green: 0.64, blue: 0.22),
                    Color(red: 0.72, green: 0.54, blue: 0.28)]
        default: // The Delta — mix from multiple biomes
            return [theme.signalColor,
                    Color(red: 0.55, green: 0.80, blue: 0.28),   // leaf green
                    Color(red: 0.28, green: 0.74, blue: 0.72),   // bubble teal
                    Color(red: 0.88, green: 0.72, blue: 0.40)]   // gold dust
        }
    }
}

// MARK: - ParticleData

private struct ParticleData: Identifiable {
    let id:       Int
    let color:    Color
    let size:     CGFloat
    let startX:   CGFloat   // normalized 0–1 relative to GeometryReader size
    let startY:   CGFloat
    let driftX:   CGFloat   // pixel offset applied when animating == true
    let driftY:   CGFloat
    let opacity:  Double
    let duration: Double    // animation cycle duration in seconds
    let delay:    Double    // initial animation delay for stagger
}

// MARK: - SeededRandom

/// Deterministic XOR-shift random number generator.
/// Used to produce stable particle layouts that don't change across re-renders.
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
