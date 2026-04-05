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
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var specimenStore: SpecimenStore
    @EnvironmentObject private var leaderboardStore: LeaderboardStore

    /// Called when the player advances to the next level within the biome.
    /// Nil when the current level is the last one in the biome.
    var onNextLevel: (() -> Void)?

    /// Called when the player returns to the biome map.
    /// Provided instead of onNextLevel when this is the last level in the biome.
    var onReturnToMap: (() -> Void)?

    /// Called when the player wants to return to the level select screen for the
    /// current biome (i.e. go back one level in the nav stack to LevelSelectView).
    /// Always provided when playing through the campaign. Shown as a secondary
    /// "Back to Map" button on the loss card so the player can choose a different
    /// level rather than being forced to retry.
    var onReturnToLevelSelect: (() -> Void)?

    /// Optional title override for the win card.
    /// When non-nil, replaces "Level Clear!" in the expanded card and collapsed pill.
    var customTitle: String? = nil

    /// The specimen outcome of this run. Determines which of three states the
    /// specimen area shows: teaser (< 3★), already collected (replay), or burst reveal (new).
    /// Defaults to .none so loss cards and BiomeCompleteView are unaffected.
    var specimenUnlockResult: SpecimenUnlockResult = .none
    var leaderboardResult: LeaderboardRecordResult? = nil

    // MARK: Convenience

    private var isWin: Bool { viewModel.gameState == .won }
    private var biomeId: Int { viewModel.levelSpec.biomeId }
    private var theme: BiomeTheme { BiomeTheme.theme(for: biomeId) }
    private var winTitle: String { customTitle ?? "Level Clear!" }
    private var currentLevelSpecimen: Specimen? {
        SpecimenCatalog.specimen(for: viewModel.levelSpec.id)
    }
    private var shouldShowSpecimenTeaser: Bool {
        guard case .none = specimenUnlockResult,
              let specimen = currentLevelSpecimen else { return false }
        return !specimenStore.isUnlocked(specimen.id)
    }

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

    // MARK: Specimen Animation State

    /// Opacity of the "?" silhouette in the new-discovery state.
    /// Starts at 1.0 and fades to 0 when the burst fires.
    @State private var specimenSilhouetteOpacity: Double = 1.0

    /// Scale and opacity of the specimen image as it springs in during the burst.
    @State private var specimenRevealScale: CGFloat = 0
    @State private var specimenRevealOpacity: Double = 0
    @State private var specimenFlashScale: CGFloat = 0.65
    @State private var specimenFlashOpacity: Double = 0
    @State private var specimenRewardOffset: CGFloat = 28
    @State private var specimenRewardTilt: Double = -10

    /// Opacity of the "New specimen discovered!" label and specimen name.
    @State private var discoveryBadgeOpacity: Double = 0
    @State private var showingLeaderboard = false

    /// Opacity of the rare biome specimen section (scales from 0→1 via spring).
    @State private var rareRevealOpacity: Double = 0
    @State private var rareFlashScale: CGFloat = 0.65
    @State private var rareFlashOpacity: Double = 0
    @State private var rareRewardOffset: CGFloat = 30

    /// Opacity of the "RARE specimen discovered!" label and rare name.
    @State private var rareBadgeOpacity: Double = 0

    // MARK: Watercolor Splash Animation State (floating specimen, new-discovery only)

    /// Scale of the watercolor splash that expands from the specimen position on burst.
    /// Animates 0 → 1 when the burst fires, then stays at 1 for the residual stain.
    @State private var splashScale: CGFloat = 0
    /// Opacity of the animated splash layer (rises then falls, leaving the stain behind).
    @State private var splashOpacity: Double = 0
    /// Opacity of the residual stain halo that remains after the splash fades.
    @State private var splashStainOpacity: Double = 0

    /// Matching set for the rare biome specimen splash (larger, more intense).
    @State private var rareSplashScale: CGFloat = 0
    @State private var rareSplashOpacity: Double = 0
    @State private var rareSplashStainOpacity: Double = 0

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
                        winPresentation
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
        .onAppear {
            resetSpecimenAnimationState()
            scheduleAnimations()
        }
        .sheet(isPresented: $showingLeaderboard) {
            LevelLeaderboardView(level: viewModel.levelSpec, showsCloseButton: true)
                .environmentObject(leaderboardStore)
                .frame(width: 600, height: 700)
        }
        .onChange(of: specimenUnlockResult) { _, newValue in
            guard isWin else { return }
            guard case .newDiscovery(_, let rare) = newValue else { return }
            guard specimenRevealOpacity == 0, discoveryBadgeOpacity == 0 else { return }

            resetSpecimenAnimationState()
            scheduleSpecimenRevealAnimations(startDelay: statsOpacity > 0.01 ? 0.12 : 3.80, rare: rare)
        }
    }

    private var winPresentation: some View {
        winCard
            .overlay(alignment: .topTrailing) {
                floatingSpecimen
                    .offset(x: 258, y: 54)
                    .allowsHitTesting(false)
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Collapsed Pill

    private var collapsedPill: some View {
        HStack(spacing: 10) {
            Text(isWin ? winTitle : "Hazard Hit")
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
                Text(winTitle)
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

            // ── Specimen reveal / teaser ──────────────────────────────────
            specimenTeaserSection
                .opacity(statsOpacity)
                .padding(.bottom, 16)

            // ── Time (static) ──────────────────────────────────────────────
            Text(formattedTime)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .opacity(statsOpacity)
                .padding(.bottom, 14)

            // ── Stats row ──────────────────────────────────────────────────
            winStatsRow
                .opacity(statsOpacity)
                .padding(.bottom, 14)

            if let leaderboardResult {
                leaderboardSummary(result: leaderboardResult)
                    .opacity(statsOpacity)
                    .padding(.bottom, 14)
            }

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

            specimenTeaserSection
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

    private func leaderboardSummary(result: LeaderboardRecordResult) -> some View {
        Button {
            audioManager.playMenuClick()
            showingLeaderboard = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(leaderboardHeadline(for: result))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(leaderboardHeadlineColor(for: result))

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Best")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(LeaderboardFormatting.formattedScore(result.bestEntry.score)) · \(LeaderboardFormatting.formattedRunTime(result.bestEntry.timeSeconds))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if let rank = result.insertedRank {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("This Run")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                            Text("#\(rank) Top 10")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func leaderboardHeadline(for result: LeaderboardRecordResult) -> String {
        if result.isFirstRecordedWin {
            return "First Recorded Win"
        }
        if result.isNewNumberOne {
            return "New High Score"
        }
        if result.isNewBestTime {
            return "New Best Time"
        }
        if result.insertedRank != nil {
            return "Entered Top 10"
        }
        return "Leaderboard Updated"
    }

    private func leaderboardHeadlineColor(for result: LeaderboardRecordResult) -> Color {
        if result.isFirstRecordedWin || result.isNewNumberOne {
            return Color(red: 1.0, green: 0.843, blue: 0.0)
        }
        return Color.white.opacity(0.9)
    }

    // MARK: - Button Row

    private var buttonRow: some View {
        VStack(spacing: 8) {
            if isWin {
                // Primary — Next Level or Return to Map
                if let action = onNextLevel {
                    Button(action: {
                        audioManager.playMenuClick()
                        action()
                    }) {
                        Text("Next Level")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.flagAccentColor)
                } else if let action = onReturnToMap {
                    Button(action: {
                        audioManager.playMenuClick()
                        action()
                    }) {
                        Text("Return to Map")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.flagAccentColor)
                }

                // Secondary — Retry
                Button(action: {
                    audioManager.playMenuClick()
                    viewModel.retry()
                }) {
                    Text("Retry")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                // Tertiary — Back to Map (level select for this biome).
                // Lets the player return to the map after a win without being
                // forced to continue to the next level.
                if let action = onReturnToLevelSelect {
                    Button(action: {
                        audioManager.playMenuClick()
                        action()
                    }) {
                        Text("Back to Map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            } else {
                // Loss primary — Retry
                Button(action: {
                    audioManager.playMenuClick()
                    viewModel.retry()
                }) {
                    Text("Retry")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.75, green: 0.45, blue: 0.22))

                // Loss secondary — Back to Map (level select for this biome).
                // Always shown so the player can pick a different level rather
                // than being forced to retry or quit via the window controls.
                if let action = onReturnToLevelSelect {
                    Button(action: {
                        audioManager.playMenuClick()
                        action()
                    }) {
                        Text("Back to Map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }

                // Loss tertiary — Return to Biome Select (biome-final levels only,
                // triggers the biome-unlock cinematic on re-appear).
                if let action = onReturnToMap {
                    Button(action: {
                        audioManager.playMenuClick()
                        action()
                    }) {
                        Text("Return to Biomes")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
    }

    // MARK: - Specimen Section

    /// Warm brown used for muted specimen text and the "?" silhouette tint.
    /// Computed property avoids memberwise-init inclusion issues in the View struct.
    private var specimenBrown: Color { Color(red: 0.55, green: 0.35, blue: 0.18) }
    /// Gold used for discovery badges and shimmer.
    private var specimenGold: Color  { Color(red: 1.0,  green: 0.843, blue: 0.0) }

    /// On-card teaser shown when the level's specimen was NOT revealed this run.
    /// Real specimen art only appears in the off-card reveal area.
    @ViewBuilder
    private var specimenTeaserSection: some View {
        if shouldShowSpecimenTeaser, let specimen = currentLevelSpecimen {
            VStack(spacing: 10) {
                ZStack {
                    Ellipse()
                        .fill(Color.black.opacity(0.26))
                        .frame(width: 120, height: 22)
                        .blur(radius: 7)
                        .offset(y: 28)

                    WatercolorSplashView(
                        color: specimenBrown,
                        size: 108,
                        scale: 1.0,
                        opacity: 0.14
                    )
                    .blur(radius: 2)

                    Image(specimen.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .saturation(0)
                        .brightness(-0.72)
                        .contrast(1.28)
                        .opacity(0.44)
                        .blur(radius: 1.1)
                        .shadow(color: specimenBrown.opacity(0.42), radius: 14, x: 0, y: 8)
                }
                .frame(width: 146, height: 126)

                Text(isWin ? "Earn 3 stars to reveal this specimen" : "This level holds a specimen")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(specimenBrown.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)

                Text("???")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(specimenBrown.opacity(0.92))
                    .tracking(1.8)
            }
        }
    }

    // MARK: - Floating Specimen (external to card)

    /// Top-level floating specimen element rendered in the body ZStack, to the right
    /// of the victory card.  Dispatches to one of three state-specific sub-views using
    /// the same `if case` pattern as `specimenSection` to avoid Optional.none inference.
    @ViewBuilder
    private var floatingSpecimen: some View {
        if case .newDiscovery(let specimen, let rare) = specimenUnlockResult {
            floatingNewDiscoveryContent(specimen: specimen, rare: rare)
        } else if case .alreadyCollected(let specimen) = specimenUnlockResult {
            floatingAlreadyCollectedContent(specimen: specimen)
        }
    }

    /// State 2: new discovery — "?" fades into watercolor splash → specimen springs in.
    @ViewBuilder
    private func floatingNewDiscoveryContent(specimen: Specimen, rare: Specimen?) -> some View {
        VStack(spacing: 8) {

            // ── Regular specimen burst ───────────────────────────────────────
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.42))
                    .frame(width: 244, height: 322)
                    .blur(radius: 28)
                    .offset(y: 40)
                    .opacity(0.90)
                ForEach(0..<8, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    specimenGold.opacity(0.0),
                                    specimenGold.opacity(0.75),
                                    specimenGold.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 10, height: 132)
                        .blur(radius: 0.8)
                        .rotationEffect(.degrees(Double(index) * 45))
                        .scaleEffect(specimenFlashScale)
                        .opacity(specimenFlashOpacity * 0.78)
                }
                // Animated watercolor splash (expands on burst)
                WatercolorSplashView(
                    color: theme.signalColor,
                    size: 184,
                    scale: splashScale,
                    opacity: splashOpacity
                )
                // Residual stain halo — appears as the splash fades, stays permanently
                WatercolorSplashView(
                    color: theme.signalColor,
                    size: 156,
                    scale: 1.0,
                    opacity: splashStainOpacity
                )
                Circle()
                    .strokeBorder(specimenGold.opacity(0.50), lineWidth: 6)
                    .frame(width: 170, height: 170)
                    .scaleEffect(specimenFlashScale)
                    .opacity(specimenFlashOpacity)
                    .blur(radius: 0.5)
                Circle()
                    .fill(specimenGold.opacity(0.50))
                    .frame(width: 160, height: 160)
                    .blur(radius: 32)
                    .opacity(specimenRevealOpacity * 0.84)
                Image(specimen.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118, height: 118)
                    .saturation(0)
                    .brightness(-0.68)
                    .contrast(1.24)
                    .opacity(specimenSilhouetteOpacity * 0.56)
                    .blur(radius: 1.0)
                    .shadow(color: specimenBrown.opacity(0.36), radius: 18, x: 0, y: 10)
                // Specimen image springs in from center
                Image(specimen.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 138, height: 138)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.40), radius: 22, x: 0, y: 14)
                    .scaleEffect(specimenRevealScale)
                    .opacity(specimenRevealOpacity)
            }
            .frame(width: 212, height: 212)

            // "New specimen discovered!" fades in after burst
            Text("New specimen discovered!")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(specimenGold)
                .shadow(color: specimenGold.opacity(0.56), radius: 8, x: 0, y: 0)
                .opacity(discoveryBadgeOpacity)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color.black.opacity(0.52))
                        .blur(radius: 10)
                }

            // Specimen name
            Text(specimen.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)
                .opacity(discoveryBadgeOpacity)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color.black.opacity(0.48))
                        .blur(radius: 12)
                }

            // ── Rare biome specimen (if applicable) ──────────────────────────
            if let rare = rare {
                Spacer().frame(height: 12)

                VStack(spacing: 8) {
                    ZStack {
                        Ellipse()
                            .fill(Color.black.opacity(0.44))
                            .frame(width: 272, height: 352)
                            .blur(radius: 30)
                            .offset(y: 48)
                            .opacity(0.92)
                        ForEach(0..<10, id: \.self) { index in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            specimenGold.opacity(0.0),
                                            specimenGold.opacity(0.82),
                                            specimenGold.opacity(0.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 12, height: 154)
                                .blur(radius: 1.0)
                                .rotationEffect(.degrees(Double(index) * 36))
                                .scaleEffect(rareFlashScale)
                                .opacity(rareFlashOpacity * 0.82)
                        }
                        // Larger, more intense splash for rare reveal
                        WatercolorSplashView(
                            color: theme.signalColor,
                            size: 212,
                            scale: rareSplashScale,
                            opacity: rareSplashOpacity
                        )
                        // Rare residual stain
                        WatercolorSplashView(
                            color: theme.signalColor,
                            size: 182,
                            scale: 1.0,
                            opacity: rareSplashStainOpacity
                        )
                        Circle()
                            .strokeBorder(specimenGold.opacity(0.62), lineWidth: 7)
                            .frame(width: 200, height: 200)
                            .scaleEffect(rareFlashScale)
                            .opacity(rareFlashOpacity)
                            .blur(radius: 0.5)
                        Circle()
                            .fill(specimenGold.opacity(0.60))
                            .frame(width: 186, height: 186)
                            .blur(radius: 36)
                            .opacity(rareRevealOpacity * 0.90)
                        Image(rare.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 148, height: 148)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.44), radius: 24, x: 0, y: 14)
                            .scaleEffect(rareRevealOpacity > 0.01 ? 1.0 : 0.2)
                            .opacity(rareRevealOpacity)
                            .animation(.spring(response: 0.50, dampingFraction: 0.52), value: rareRevealOpacity)
                    }
                    .frame(width: 232, height: 232)

                    Text("RARE specimen discovered!")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(specimenGold)
                        .shadow(color: specimenGold.opacity(0.62), radius: 10, x: 0, y: 0)
                        .opacity(rareBadgeOpacity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(Color.black.opacity(0.54))
                                .blur(radius: 12)
                        }

                    Text(rare.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)
                        .opacity(rareBadgeOpacity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background {
                            Capsule()
                                .fill(Color.black.opacity(0.50))
                                .blur(radius: 12)
                        }
                }
                .offset(y: rareRewardOffset)
            }
        }
        .frame(width: 248)
        .multilineTextAlignment(.center)
        .offset(y: specimenRewardOffset)
        .rotationEffect(.degrees(specimenRewardTilt))
    }

    /// State 3: already collected — specimen shown immediately with a soft static halo.
    @ViewBuilder
    private func floatingAlreadyCollectedContent(specimen: Specimen) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.40))
                    .frame(width: 214, height: 278)
                    .blur(radius: 24)
                    .offset(y: 34)
                    .opacity(0.88)
                // Static soft watercolor halo (no animation — player already has this)
                WatercolorSplashView(
                    color: theme.signalColor,
                    size: 148,
                    scale: 1.0,
                    opacity: 0.30
                )
                Image(specimen.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.34), radius: 18, x: 0, y: 12)
            }
            .frame(width: 176, height: 176)

            Text(specimen.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.90))
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color.black.opacity(0.48))
                        .blur(radius: 12)
                }
        }
        .frame(width: 210)
        .multilineTextAlignment(.center)
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

    /// Color for every visible star on the win card.
    /// All stars share the same tier color based on the TOTAL stars earned —
    /// 1★ = all bronze, 2★ = all silver, 3★ = all gold.
    /// The `index` parameter is accepted but unused so the call sites are unchanged.
    private func starColor(for index: Int) -> Color {
        switch viewModel.stars {
        case 3:  return Color(red: 1.000, green: 0.843, blue: 0.000) // gold   #FFD700
        case 2:  return Color(red: 0.753, green: 0.753, blue: 0.753) // silver #C0C0C0
        default: return Color(red: 0.804, green: 0.498, blue: 0.196) // bronze #CD7F32
        }
    }

    private func resetSpecimenAnimationState() {
        specimenSilhouetteOpacity = 1.0
        specimenRevealScale = 0
        specimenRevealOpacity = 0
        specimenFlashScale = 0.65
        specimenFlashOpacity = 0
        specimenRewardOffset = 28
        specimenRewardTilt = -10
        discoveryBadgeOpacity = 0

        rareRevealOpacity = 0
        rareFlashScale = 0.65
        rareFlashOpacity = 0
        rareRewardOffset = 30
        rareBadgeOpacity = 0

        splashScale = 0
        splashOpacity = 0
        splashStainOpacity = 0
        rareSplashScale = 0
        rareSplashOpacity = 0
        rareSplashStainOpacity = 0
    }

    private func scheduleSpecimenRevealAnimations(startDelay: Double, rare: Specimen?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            // Splash expands outward from center dot
            withAnimation(.easeOut(duration: 0.78)) {
                splashScale = 1.0
                splashOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.32)) {
                specimenFlashScale = 1.24
                specimenFlashOpacity = 0.95
            }
            withAnimation(.easeOut(duration: 0.62).delay(0.14)) {
                specimenFlashScale = 1.76
                specimenFlashOpacity = 0.0
            }
            // Splash fades after expansion — leaves a residual stain behind
            withAnimation(.easeIn(duration: 0.62).delay(0.52)) {
                splashOpacity = 0.0
            }
            // Residual stain materialises as the splash fades out
            withAnimation(.easeIn(duration: 0.42).delay(0.76)) {
                splashStainOpacity = 1.0
            }
            // "?" silhouette dissolves as the burst fires
            withAnimation(.easeOut(duration: 0.40)) {
                specimenSilhouetteOpacity = 0.0
            }
            withAnimation(.spring(response: 0.68, dampingFraction: 0.72)) {
                specimenRewardOffset = 0
                specimenRewardTilt = 0
            }
            // Specimen springs in from center with organic bounce
            withAnimation(.spring(response: 0.56, dampingFraction: 0.58)) {
                specimenRevealScale = 1.34
            }
            withAnimation(.easeOut(duration: 0.34)) {
                specimenRevealOpacity = 1.0
            }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.76).delay(0.32)) {
                specimenRevealScale = 1.0
            }
        }

        // "New specimen discovered!" + name fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 0.95) {
            withAnimation(.easeInOut(duration: 0.42)) {
                discoveryBadgeOpacity = 1.0
            }
        }

        guard rare != nil else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 1.90) {
            // Larger splash for rare — more intense color, slower expansion
            withAnimation(.easeOut(duration: 0.84)) {
                rareSplashScale = 1.0
                rareSplashOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.28)) {
                rareFlashScale = 1.20
                rareFlashOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.64).delay(0.14)) {
                rareFlashScale = 1.68
                rareFlashOpacity = 0.0
            }
            withAnimation(.easeIn(duration: 0.66).delay(0.58)) {
                rareSplashOpacity = 0.0
            }
            withAnimation(.easeIn(duration: 0.46).delay(0.86)) {
                rareSplashStainOpacity = 1.0
            }
            withAnimation(.spring(response: 0.72, dampingFraction: 0.74)) {
                rareRewardOffset = 0
            }
            // Rare specimen appears
            withAnimation(.easeOut(duration: 0.52)) {
                rareRevealOpacity = 1.0
            }
        }

        // "RARE specimen discovered!" + name fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 3.05) {
            withAnimation(.easeInOut(duration: 0.42)) {
                rareBadgeOpacity = 1.0
            }
        }
    }

    // MARK: - Animation Scheduling

    private func scheduleAnimations() {
        guard isWin else {
            // ── Loss path ────────────────────────────────────────────────
            // The explosion animation provides all the dramatic pause
            // (~4 s from hazard hit to .lost state). The loss card fades in
            // immediately when it appears — no extra delay needed.
            withAnimation(.easeInOut(duration: 0.30)) {
                cardOpacity = 1.0
            }
            statsOpacity   = 1.0
            buttonsOpacity = 1.0
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

        // ── Specimen reveal (new discovery only) ────────────────────────────
        // Burst starts 0.5 s after score lands (3.3 + 0.5 = 3.8 s).
        guard case .newDiscovery(_, let rare) = specimenUnlockResult else { return }
        scheduleSpecimenRevealAnimations(startDelay: 3.80, rare: rare)
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

// MARK: - WatercolorSplashView

/// Organic-feeling watercolor paint splash used behind the floating specimen element
/// during the new-discovery reveal animation.
///
/// Rendered as a slightly asymmetric ellipse filled with a feathered radial gradient
/// whose center is offset from geometric center (for a natural, non-circular look).
/// The caller drives `scale` and `opacity` via SwiftUI animations; calling code uses
/// two instances — one animated (the splash) and one at scale 1 (the residual stain).
private struct WatercolorSplashView: View {

    /// Tint color for the splash — typically `BiomeTheme.signalColor`.
    let color: Color
    /// Nominal diameter of the splash in points (the ellipse is ~15 % wider than this).
    let size: CGFloat
    /// Current scale (0 = collapsed dot, 1 = fully expanded). Driven by animation.
    let scale: CGFloat
    /// Overall opacity of the splash layer. Driven by animation.
    let opacity: Double

    var body: some View {
        // Slightly asymmetric ellipse (wider than tall) — more natural than a circle.
        Ellipse()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: color.opacity(0.45), location: 0.00),
                        .init(color: color.opacity(0.28), location: 0.40),
                        .init(color: color.opacity(0.10), location: 0.72),
                        .init(color: color.opacity(0.00), location: 1.00)
                    ]),
                    // Offset center gives the gradient an irregular, paint-drop feel.
                    center: UnitPoint(x: 0.44, y: 0.46),
                    startRadius: 0,
                    endRadius: size * 0.55
                )
            )
            // Wider than tall → paint tends to spread horizontally on wet paper.
            .frame(width: size * 1.15, height: size * 0.88)
            // Soft blur feathers the edges so they fade rather than cut off sharply.
            .blur(radius: 5)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}
