// Revelia/Views/GameView.swift

import SwiftUI

/// The main gameplay screen: board grid + HUD + keyboard shortcuts.
///
/// GameView owns its GameViewModel via @StateObject. Pass a LevelSpec and
/// optionally an explicit seed (for debugging/seed-sharing). Each new view identity
/// (controlled by .id() in the parent) creates a fresh ViewModel with a
/// truly random seed — ensuring unique boards every time.
struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    /// Callback to advance to the next level within the biome. Nil when on the biome's last level.
    var onNextLevel: (() -> Void)?
    /// Callback to return to BiomeSelectView. Provided instead of onNextLevel on the biome's last level.
    var onReturnToMap: (() -> Void)?

    /// Callback to return to LevelSelectView within the current biome.
    /// Always provided so the loss card can offer "Back to Map" on every level.
    var onReturnToLevelSelect: (() -> Void)?
    var suspendedRun: SuspendedRun? = nil
    var onSaveAndExit: ((SuspendedRun) -> Void)?
    var onClearSuspendedRun: (() -> Void)? = nil

    // MARK: - Biome Complete Metadata

    /// True when this level is the final level in its biome. Drives the biome-complete summary.
    var isLastLevelOfBiome: Bool = false
    /// Biome display name (e.g. "Fog Marsh"). Used on the biome-complete summary.
    var biomeName: String = ""
    /// SF Symbol for the biome icon. Used on the biome-complete summary.
    var biomeIcon: String = ""
    /// All level IDs in this biome — used to compute total stars from ProgressStore.
    var biomeLevelIds: [String] = []

    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var leaderboardStore: LeaderboardStore
    @EnvironmentObject private var specimenStore: SpecimenStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var audioManager: AudioManager

    /// The specimen outcome of the most recent winning run.
    /// Computed in the .won onChange before EndOfLevelView appears, so the card
    /// knows which animation state to show from the first frame it renders.
    @State private var specimenUnlockResult: SpecimenUnlockResult = .none
    @State private var leaderboardResult: LeaderboardRecordResult? = nil

    // MARK: - Linked Tile Hover (Biome 2)

    /// The board coordinate currently under the cursor (nil when cursor is off-board).
    @State private var hoveredCoord: Coordinate? = nil

    /// Measured outer container size. Updated whenever the window resizes.
    /// Drives `tileSize` so the board always fits within the available space.
    /// Initial value matches a typical compact window; the GeometryReader
    /// fires on first layout and corrects it before the user sees the board.
    @State private var containerSize: CGSize = CGSize(width: 600, height: 700)

    // MARK: - Explosion Animation State

    /// True when the SpriteKit explosion overlay is actively playing.
    /// The board is hidden (opacity 0) and the pre-mounted SKView shows the
    /// shatter animation. Set to true immediately on `.exploding`, cleared when
    /// the scene finishes or the player retries.
    @State private var showExplosionOverlay: Bool = false
    @State private var showingSettings = false
    @State private var shouldResumeAfterSettings = false
    @State private var pendingVictoryMusicTask: Task<Void, Never>?
    @State private var shouldMountExplosionView = false
    private let winMusicFadeOutDuration: UInt64 = 250_000_000
    private let victoryMusicDelayAfterWinStinger: UInt64 = 1_200_000_000

    /// The SpriteKit explosion scene. nil = no explosion in progress.
    /// Created immediately when `.exploding` fires and assigned here.
    /// Once the SpriteKit view has been mounted, updateNSView detects a non-nil
    /// scene and calls presentScene — didMove(to:) fires on the next frame
    /// (~16 ms), starting the animation with near-zero delay. The mount itself
    /// is deferred until after the first board frame so Play navigation feels snappy.
    /// Set back to nil on retry/reset to allow a fresh scene next time.
    @State private var explosionScene: BoardExplosionScene?

    /// True only for the opening level of each biome that shows a biome intro tooltip.
    /// L75 (Training Range: Hex Mode) is excluded — Training Range needs no intro.
    /// The Delta (L63 / L137) IS included — now uses the same parchment tooltip as all biomes.
    private var isFirstBiomeLevel: Bool {
        // Square biome openers
        viewModel.levelSpec.id == "L7"   ||   // Fog Marsh
        viewModel.levelSpec.id == "L15"  ||   // Bioluminescence
        viewModel.levelSpec.id == "L23"  ||   // Frozen Mirrors
        viewModel.levelSpec.id == "L31"  ||   // Ruins
        viewModel.levelSpec.id == "L39"  ||   // The Underside
        viewModel.levelSpec.id == "L47"  ||   // Coral Basin
        viewModel.levelSpec.id == "L55"  ||   // Quicksand
        viewModel.levelSpec.id == "L63"  ||   // The Delta
        // Hex biome openers (mirror the above; Training Range hex L75 intentionally omitted)
        viewModel.levelSpec.id == "L81"  ||   // Fog Marsh: Hex Mode
        viewModel.levelSpec.id == "L89"  ||   // Bioluminescence: Hex Mode
        viewModel.levelSpec.id == "L97"  ||   // Frozen Mirrors: Hex Mode
        viewModel.levelSpec.id == "L105" ||   // Ruins: Hex Mode
        viewModel.levelSpec.id == "L113" ||   // The Underside: Hex Mode
        viewModel.levelSpec.id == "L121" ||   // Coral Basin: Hex Mode
        viewModel.levelSpec.id == "L129" ||   // Quicksand: Hex Mode
        viewModel.levelSpec.id == "L137"      // The Delta: Hex Mode
    }

    /// True for the opening level of EVERY biome across both campaigns,
    /// including Training Range (L1 / L75) and The Delta (L63 / L137).
    ///
    /// Used exclusively for shield-award logic. This is intentionally broader
    /// than `isFirstBiomeLevel`, which excludes Training Range and Delta
    /// because they have no BiomeIntroOverlay.
    private var isFirstLevelOfAnyBiome: Bool {
        // Square campaign openers
        viewModel.levelSpec.id == "L1"   ||   // Training Range
        viewModel.levelSpec.id == "L7"   ||   // Fog Marsh
        viewModel.levelSpec.id == "L15"  ||   // Bioluminescence
        viewModel.levelSpec.id == "L23"  ||   // Frozen Mirrors
        viewModel.levelSpec.id == "L31"  ||   // Ruins
        viewModel.levelSpec.id == "L39"  ||   // The Underside
        viewModel.levelSpec.id == "L47"  ||   // Coral Basin
        viewModel.levelSpec.id == "L55"  ||   // Quicksand
        viewModel.levelSpec.id == "L63"  ||   // The Delta
        // Hex campaign openers
        viewModel.levelSpec.id == "L75"  ||   // Training Range: Hex Mode
        viewModel.levelSpec.id == "L81"  ||   // Fog Marsh: Hex Mode
        viewModel.levelSpec.id == "L89"  ||   // Bioluminescence: Hex Mode
        viewModel.levelSpec.id == "L97"  ||   // Frozen Mirrors: Hex Mode
        viewModel.levelSpec.id == "L105" ||   // Ruins: Hex Mode
        viewModel.levelSpec.id == "L113" ||   // The Underside: Hex Mode
        viewModel.levelSpec.id == "L121" ||   // Coral Basin: Hex Mode
        viewModel.levelSpec.id == "L129" ||   // Quicksand: Hex Mode
        viewModel.levelSpec.id == "L137"      // The Delta: Hex Mode
    }

    /// True whenever the game is paused, regardless of biome.
    /// Used to blur and cover the board so the player cannot study tile positions
    /// or numbers while the timer is stopped.
    private var isPaused: Bool {
        viewModel.gameState == .paused
    }

    /// Create a GameView that owns its own ViewModel.
    ///
    /// - Parameters:
    ///   - levelSpec: The level to play.
    ///   - seed: Explicit seed for debugging or seed-sharing. Omit for a random game.
    ///   - onNextLevel: Callback to advance to the next level. Nil if last level.
    ///   - onReturnToMap: Callback to return to BiomeSelectView. Nil if not last level.
    ///   - isLastLevelOfBiome: True when this level is the biome's final level.
    ///   - biomeName: Display name of the biome (for the biome-complete summary).
    ///   - biomeIcon: SF Symbol name for the biome icon.
    ///   - biomeLevelIds: All level IDs in this biome (for computing total stars).
    init(levelSpec: LevelSpec, seed: UInt64? = nil,
         suspendedRun: SuspendedRun? = nil,
         onNextLevel: (() -> Void)? = nil, onReturnToMap: (() -> Void)? = nil,
         onReturnToLevelSelect: (() -> Void)? = nil,
         onSaveAndExit: ((SuspendedRun) -> Void)? = nil,
         onClearSuspendedRun: (() -> Void)? = nil,
         isLastLevelOfBiome: Bool = false, biomeName: String = "",
         biomeIcon: String = "", biomeLevelIds: [String] = []) {
        // _viewModel uses the @StateObject autoclosure so SwiftUI creates the
        // object exactly once per view identity. A new .id() in the parent
        // means a new identity → a new ViewModel → a new random seed.
        _viewModel = StateObject(wrappedValue: suspendedRun.map {
            GameViewModel(levelSpec: levelSpec, suspendedRun: $0)
        } ?? GameViewModel(
            levelSpec: levelSpec,
            seed: seed
        ))
        self.suspendedRun            = suspendedRun
        self.onNextLevel             = onNextLevel
        self.onReturnToMap           = onReturnToMap
        self.onReturnToLevelSelect   = onReturnToLevelSelect
        self.onSaveAndExit           = onSaveAndExit
        self.onClearSuspendedRun     = onClearSuspendedRun
        self.isLastLevelOfBiome      = isLastLevelOfBiome
        self.biomeName               = biomeName
        self.biomeIcon               = biomeIcon
        self.biomeLevelIds           = biomeLevelIds
    }

    /// Tile size derived from the measured container size, capped at [20, 64] pt.
    ///
    /// Computed by inverting `boardCanvasSize()` for the current grid shape so
    /// the entire board canvas (plus HUD, controls, and padding chrome) always
    /// fits within the window without overflow — on both square and hex boards.
    private var tileSize: CGFloat {
        // Chrome offsets: 20+20 outer VStack padding + 8+8 board-background padding = 56 pts
        // horizontal. Vertical: title (~28) + spacing (16) + HUD (~33) + spacing (16) +
        // board bg pad top+bot (16) + spacing (16) + controls hint (~12) + bottom pad (20) ≈ 157,
        // rounded up to 170 for safety.
        let availW = max(60, containerSize.width  - 56)
        let availH = max(60, containerSize.height - 170)
        return computedTileSize(availableWidth: availW, availableHeight: availH)
    }

    /// Analytically inverts `boardCanvasSize()` for the current grid shape to
    /// find the largest `tileSize` that keeps the board within `availW × availH`,
    /// then clamps the result to [20, 64] pt.
    private func computedTileSize(availableWidth availW: CGFloat,
                                  availableHeight availH: CGFloat) -> CGFloat {
        let sp   = gridSpacing
        let cols = CGFloat(viewModel.board.width)
        let rows = CGFloat(viewModel.board.height)
        let ts: CGFloat

        if viewModel.board.gridShape == .hexagonal {
            let sqrt3: CGFloat = 1.7320508075688772
            // boardCanvasSize width:
            //   W = cols*(ts*1.5 + sp) + ts*0.5 = ts*(cols*1.5 + 0.5) + cols*sp
            //   → ts = (availW − cols*sp) / (cols*1.5 + 0.5)
            let tsFromW = (availW - cols * sp) / (cols * 1.5 + 0.5)

            // boardCanvasSize height:
            //   H = rows*(ts*√3 + sp) − sp + extra*(ts*√3*0.5 + sp*0.5)
            //     = ts*√3*(rows + extra*0.5) + rows*sp − sp + extra*sp*0.5
            //   where extra = 1 if boardWidth > 1, else 0
            //   → ts = (availH − rows*sp + sp − extra*sp*0.5) / (√3*(rows + extra*0.5))
            let extra: CGFloat = viewModel.board.width > 1 ? 1.0 : 0.0
            let tsFromH = (availH - rows * sp + sp - extra * sp * 0.5)
                        / (sqrt3 * (rows + extra * 0.5))

            ts = min(tsFromW, tsFromH)
        } else {
            // boardCanvasSize (square):
            //   W = cols*(ts + sp) − sp  →  ts = (availW + sp) / cols − sp
            let tsFromW = (availW + sp) / cols - sp
            let tsFromH = (availH + sp) / rows - sp
            ts = min(tsFromW, tsFromH)
        }

        return max(20, min(64, ts))
    }

    private var gridSpacing: CGFloat { 2 }

    /// True when gameplay has ended (win, loss, or mid-explosion).
    /// Gates input removal, controls-hint hiding, and board blur.
    private var isGameInactive: Bool {
        viewModel.gameState == .won || viewModel.gameState == .lost || viewModel.gameState == .exploding
    }

    /// True when the end-of-level card (win or loss) should be visible.
    /// Excludes `.exploding` — the loss card appears only after the explosion completes.
    private var showEndOfLevel: Bool {
        viewModel.gameState == .won || viewModel.gameState == .lost
    }

    var body: some View {
        // GeometryReader at the TOP of body — outside the ZStack — so it
        // measures the space ContentView allocates to GameView. This is the
        // only correct way to break the circular dependency: if the reader
        // were placed inside the ZStack (e.g. as .background()), it would
        // measure the ZStack's own expanded size, which grows with tileSize,
        // causing a self-reinforcing feedback loop that locks tileSize at max
        // and pushes the HUD above the top of the window.
        GeometryReader { proxy in
        ZStack {
          // Full-bleed biome background image — sits behind everything.
          Image(viewModel.levelSpec.gameplayImageName)
              .resizable()
              .scaledToFill()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .clipped()
              .ignoresSafeArea()
              .allowsHitTesting(false)

          VStack(spacing: 16) {
            // Level header
            Text(viewModel.levelSpec.displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)

            // HUD
            HUDView(viewModel: viewModel, onOpenSettings: openSettings)
                .padding(.horizontal)

            // Vertical centering spacer — splits remaining window height equally
            // above and below the board+controlsHint group so small boards sit
            // in the middle of the window rather than floating near the top.
            // The matching Spacer(minLength: 0) at the bottom of the VStack is
            // what makes this work: two equal spacers = centered content.
            // tileSize is unaffected because it derives from containerSize (the
            // full window height), not from the VStack's available content height.
            Spacer(minLength: 0)

            // Game board with input overlay.
            // EndOfLevelView / BiomeCompleteView have been moved to the OUTER ZStack
            // so they are genuine full-window overlays and never affect this ZStack's
            // size. When they lived here, EndOfLevelView's .frame(maxWidth:.infinity,
            // maxHeight:.infinity) expanded this ZStack beyond boardWithInput's natural
            // size, causing boardWithInput to shift downward via ZStack center-alignment.
            ZStack {
                boardWithInput
                    // Hide the SwiftUI board when the SpriteKit explosion takes over.
                    .opacity(showExplosionOverlay ? 0 : 1.0)
                    // Blur the board immediately when paused so the player cannot
                    // study tile positions while the timer is stopped.
                    // No animation() here so the blur is instant on Space-press.
                    .blur(radius: isPaused ? 10 : 0)

                // SpriteKit explosion overlay — mounted one run-loop turn after the
                // first board frame so entering gameplay does not block on SKView
                // creation. Once mounted, the SKView stays ready and transparent
                // until an explosion scene is assigned.
                if shouldMountExplosionView || explosionScene != nil {
                    BoardExplosionView(scene: explosionScene)
                        .frame(width: boardCanvasSize.width, height: boardCanvasSize.height)
                        .opacity(explosionScene != nil ? 1 : 0)
                        .allowsHitTesting(false)
                }

                // Paused overlay — shown on top of the blurred board for all biomes.
                if isPaused {
                    pausedOverlay
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPaused)

            // Controls hint — always in the layout to prevent the board from
            // shifting position when isGameOver changes. Use opacity to hide
            // it rather than conditional removal, which causes VStack reflow.
            controlsHint
                .opacity(isGameInactive ? 0 : 1)

            Spacer(minLength: 0)
          }
          .padding(20)
          .frame(minWidth: 400, minHeight: 500)

          // End-of-level overlays — live in the OUTER ZStack so they are true
          // full-window overlays and cannot affect the VStack / board ZStack layout.
          // EndOfLevelView uses .frame(maxWidth:.infinity, maxHeight:.infinity) for
          // its collapsed-pill positioning; placing it here means that frame expands
          // against the window, not against the board ZStack.
          // Gated on showEndOfLevel (not isGameInactive) so the card stays hidden
          // during the .exploding phase while the SpriteKit animation plays.
          if showEndOfLevel {
              if viewModel.gameState == .won && isLastLevelOfBiome,
                 let onReturnToMap = onReturnToMap {
                  // Biome-final win: biome-complete summary instead of normal card.
                  let isCampaignComplete = viewModel.levelSpec.id == "L74"
                      || viewModel.levelSpec.id == "L148"
                  BiomeCompleteView(
                      biomeName: biomeName,
                      biomeIcon: biomeIcon,
                      starsEarned: biomeLevelIds.reduce(0) { $0 + progressStore.bestStars(for: $1) },
                      totalStarsPossible: biomeLevelIds.count * 3,
                      isCampaignComplete: isCampaignComplete,
                      onReturnToMap: onReturnToMap
                  )
                  .transition(.opacity)
              } else {
                  EndOfLevelView(viewModel: viewModel,
                                 onNextLevel:           onNextLevel,
                                 onReturnToMap:         onReturnToMap,
                                 onReturnToLevelSelect: onReturnToLevelSelect,
                                 specimenUnlockResult:  specimenUnlockResult,
                                 leaderboardResult:     leaderboardResult)
                      .transition(.opacity)
              }
          }

        }
        .coordinateSpace(.named("gameRoot"))
        // Seed containerSize on first appear.
        .onAppear {
            // Seed containerSize from the top-level GeometryReader on first appear.
            // proxy.size here is the space ContentView allocated to GameView — free of
            // the circular dependency that arose when measuring the ZStack's own background.
            if proxy.size.width > 0 && proxy.size.height > 0 {
                containerSize = proxy.size
            }
            syncMusicForCurrentState()
            if suspendedRun != nil { onClearSuspendedRun?() }
            Task { @MainActor in
                await Task.yield()
                shouldMountExplosionView = true
            }
        }
        // Keep containerSize current on window resize.
        .onChange(of: proxy.size) { _, size in
            if size.width > 0 && size.height > 0 { containerSize = size }
        }
        } // end GeometryReader closure — proxy is in scope for all modifiers above
        .animation(.easeInOut(duration: 0.30), value: showEndOfLevel)
        .focusable()
        .onKeyPress(.space) {
            togglePause()
            return .handled
        }
        .onKeyPress("r") {
            // Clear explosion overlay state in case player retries mid-explosion.
            showExplosionOverlay = false
            explosionScene = nil
            viewModel.retry()
            return .handled
        }
        .onKeyPress("c") {
            if viewModel.isConductorTargeting {
                viewModel.cancelConductorTargeting()
            } else {
                viewModel.activateConductor()
            }
            return .handled
        }
        .onKeyPress("b") {
            if viewModel.isBeaconTargeting {
                viewModel.cancelBeaconTargeting()
            } else {
                viewModel.activateBeacon()
            }
            return .handled
        }
        // MARK: - Game State Change Handler
        // Handles both explosion trigger and progress save in a single onChange.
        .onChange(of: viewModel.gameState) {
            switch viewModel.gameState {

            // ── Explosion trigger ────────────────────────────────────────
            // No asyncAfter — the scene is created immediately and presented
            // on the mounted SKView. didMove(to:) fires on the next frame
            // (~16 ms), starting the flash + ring-by-ring shatter animation.
            // The board hides instantly (opacity 0) and the SpriteKit tile
            // sprites appear within one frame, so there is no blank gap.
            case .exploding:
                onClearSuspendedRun?()
                shouldMountExplosionView = true
                audioManager.transition(to: .loss(biomeId: viewModel.levelSpec.biomeId))
                let tileData = buildExplosionTileData()
                explosionScene = BoardExplosionScene(
                    size:          boardCanvasSize,
                    tileData:      tileData,
                    biomeId:       viewModel.levelSpec.biomeId,
                    gridShape:     viewModel.board.gridShape,
                    onSoundEffect: { soundEvent in
                        switch soundEvent {
                        case .impact:
                            audioManager.play(.destructionImpact)
                        case .crackWave:
                            audioManager.play(.destructionCrackWave)
                        }
                    },
                    onComplete: { [self] in
                        showExplosionOverlay = false
                        explosionScene = nil
                        viewModel.completeExplosion()
                    }
                )
                showExplosionOverlay = true

            // ── Progress save (win only) ─────────────────────────────────
            case .won:
                onClearSuspendedRun?()
                pendingVictoryMusicTask?.cancel()
                let winningBiomeId = viewModel.levelSpec.biomeId
                audioManager.fadeOutMusic(duration: 0.25)
                pendingVictoryMusicTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: winMusicFadeOutDuration)
                    guard !Task.isCancelled, viewModel.gameState == .won else { return }
                    audioManager.play(.win)
                    try? await Task.sleep(nanoseconds: victoryMusicDelayAfterWinStinger)
                    guard !Task.isCancelled, viewModel.gameState == .won else { return }
                    audioManager.transition(to: .victory(biomeId: winningBiomeId))
                }
                progressStore.recordResult(
                    levelId:     viewModel.levelSpec.id,
                    score:       viewModel.score,
                    timeSeconds: viewModel.elapsedTime,
                    stars:       viewModel.stars
                )
                leaderboardResult = leaderboardStore.recordWinningRun(
                    levelId: viewModel.levelSpec.id,
                    score: viewModel.score,
                    timeSeconds: viewModel.elapsedTime,
                    stars: viewModel.stars
                )
                if isFirstLevelOfAnyBiome && viewModel.stars == 3 {
                    progressStore.markShieldEarned(biomeId: viewModel.levelSpec.biomeId)
                }
                if viewModel.stats.shieldUsed {
                    progressStore.markShieldUsed(biomeId: viewModel.levelSpec.biomeId)
                }

                // ── Specimen unlock ──────────────────────────────────────
                // Must run AFTER recordResult so shield/star state is final.
                // Already-collected specimens should still appear on any winning
                // clear, even when the current run earned fewer than 3 stars.
                specimenUnlockResult = .none
                if let specimen = SpecimenCatalog.specimen(for: viewModel.levelSpec.id) {
                    let wasAlreadyCollected = specimenStore.isUnlocked(specimen.id)

                    if wasAlreadyCollected {
                        specimenUnlockResult = .alreadyCollected(specimen: specimen)
                    } else if viewModel.stars == 3 {
                        specimenStore.unlock(specimen.id)

                        // Check if completing this level also earns the biome rare specimen.
                        var rareSpecimen: Specimen? = nil
                        let biomeId = specimen.biomeId
                        let isHex   = specimen.isHex
                        if specimenStore.allLevelSpecimensUnlocked(for: biomeId, isHex: isHex),
                           let rare = SpecimenCatalog.rareSpecimen(for: biomeId, isHex: isHex),
                           !specimenStore.isUnlocked(rare.id) {
                            specimenStore.unlock(rare.id)
                            rareSpecimen = rare
                        }

                        specimenUnlockResult = .newDiscovery(specimen: specimen, rare: rareSpecimen)
                    }
                }

            // ── Retry / reset ────────────────────────────────────────────
            case .waitingForFirstScan:
                onClearSuspendedRun?()
                pendingVictoryMusicTask?.cancel()
                pendingVictoryMusicTask = nil
                audioManager.transition(to: .gameplay(biomeId: viewModel.levelSpec.biomeId))
                // Clear the specimen result so if the player retries and the card
                // momentarily flashes, it shows the clean .none state.
                specimenUnlockResult = .none
                leaderboardResult = nil

            default:
                if viewModel.gameState == .lost {
                    onClearSuspendedRun?()
                }
                if viewModel.gameState != .won {
                    pendingVictoryMusicTask?.cancel()
                    pendingVictoryMusicTask = nil
                }
                syncMusicForCurrentState()
                break
            }
        }
        .sheet(isPresented: $showingSettings, onDismiss: handleSettingsDismissed) {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(progressStore)
                .environmentObject(leaderboardStore)
                .frame(width: 600, height: 500)
        }
    }

    // MARK: - Board Canvas Size

    /// The pixel dimensions of the rendered tile grid.
    ///
    /// Delegates to `board.geometry.boardCanvasSize()` so both square and hex boards
    /// produce the correct canvas size without hardcoding square grid math here.
    private var boardCanvasSize: CGSize {
        viewModel.board.geometry.boardCanvasSize(
            boardWidth: viewModel.board.width,
            boardHeight: viewModel.board.height,
            tileSize: tileSize,
            spacing: gridSpacing
        )
    }

    // MARK: - Board + Input Overlay

    /// The tile grid with an invisible NSView overlay that captures all mouse events.
    /// This gives us reliable right-click, ctrl-click, and shift-click handling.
    ///
    /// Grid layout is shape-aware:
    /// - Square grids use a `VStack`/`HStack` layout (no offset, tiles align on a grid).
    /// - Hex grids use absolute `.position()` placement inside a fixed-size `ZStack`,
    ///   with each tile's center computed from `board.geometry.tileOrigin()`.
    private var boardWithInput: some View {
        let canvasSize = boardCanvasSize

        return ZStack {
            // Visual tile grid — purely for rendering, no gestures attached.
            // tileGrid dispatches to square (VStack/HStack) or hex (ZStack+position) layout.
            tileGrid

            // Sonar glow + sight-line pulse overlay (Biome 6: Coral Basin / Biome 8: The Delta).
            // Default: subtle breathing glow on sonar tile cells only.
            // Hover: sight-line tint + travelling wave pulse activates along all
            //   primary directions (4 for square, 6 for hex), 50–60 % opacity at peak.
            // Click-to-lock: first click pins sight lines; second click unpins.
            // allowsHitTesting(false) is set internally — zero click interference.
            if viewModel.levelSpec.hasSonar {
                SonarPulseOverlay(
                    board: viewModel.board,
                    tileSize: tileSize,
                    gridSpacing: gridSpacing,
                    gameWon: viewModel.gameState == .won,
                    hoveredCoord: hoveredCoord,
                    lockedSonarCoords: viewModel.lockedSonarCoords
                )
                .frame(width: canvasSize.width, height: canvasSize.height)
            }

            // Invisible input layer on top — handles all mouse events via AppKit.
            // gridShape is forwarded so BoardInputView uses the correct coordinate
            // conversion: simple division for square, proximity hit-test for hex.
            if !isGameInactive {
                BoardInputView(
                    boardWidth: viewModel.board.width,
                    boardHeight: viewModel.board.height,
                    tileSize: tileSize,
                    gridSpacing: gridSpacing,
                    gridShape: viewModel.board.gridShape,
                    onAction: handleBoardInput,
                    onHover: { coord in
                        hoveredCoord = coord
                        // Highlight a linked partner on hover ONLY when BOTH tiles
                        // are already revealed. If the partner is still hidden,
                        // showing the highlight would expose its location and
                        // eliminate the deduction the mechanic is built around.
                        if let coord = coord,
                           viewModel.board[coord].isRevealed,
                           let partnerCoord = viewModel.board[coord].linkedData?.partnerCoord,
                           viewModel.board[partnerCoord].isRevealed {
                            viewModel.linkedHighlightedCoord = partnerCoord
                        } else if hoveredCoord == nil {
                            // Only clear if there's no active reveal pulse pending —
                            // allow the ViewModel to naturally expire the reveal highlight.
                            viewModel.linkedHighlightedCoord = nil
                        }
                    }
                )
                .frame(width: canvasSize.width, height: canvasSize.height)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .separatorColor).opacity(0.2))
        )
        // Soft darkened zone behind the board so tiles read clearly
        // over any biome background image. padding(-28) extends the fill
        // rectangle beyond the board edges; blur(22) feathers the boundary
        // into the background image for a natural vignette effect.
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.50))
                .padding(-28)
                .blur(radius: 22)
        )
    }

    // MARK: - Tile Grid Layout

    /// Renders all tiles in the correct layout for the board's grid shape.
    ///
    /// **Square grids:** `VStack`/`HStack` with uniform spacing — tiles are on a
    /// regular grid and each row is a plain horizontal stack.
    ///
    /// **Hex grids:** Fixed-size `ZStack` with each tile absolutely positioned via
    /// `.position()` at its center point, computed from `board.geometry.tileOrigin()`.
    /// The frame is set to `boardCanvasSize` so the ZStack has the exact pixel
    /// dimensions needed to contain all offset columns.
    @ViewBuilder
    private var tileGrid: some View {
        if viewModel.board.gridShape == .hexagonal {
            let geo = viewModel.board.geometry
            let canvasSize = boardCanvasSize
            ZStack {
                ForEach(viewModel.board.allCoordinates, id: \.self) { coord in
                    let origin = geo.tileOrigin(at: coord, tileSize: tileSize, spacing: gridSpacing)
                    let w      = geo.tileWidth(tileSize)
                    let h      = geo.tileHeight(tileSize)
                    TileView(
                        tile: viewModel.board[coord],
                        gameOver: isGameInactive,
                        tileSize: tileSize,
                        gridShape: .hexagonal,
                        biomeId: viewModel.levelSpec.biomeId,
                        isHighlighted: isLinkedHighlighted(coord),
                        isIlluminated: viewModel.illuminatedCoords.contains(coord),
                        quicksandFadeProgress: viewModel.levelSpec.hasQuicksand
                            ? viewModel.quicksandFadeProgress : 0.0
                    )
                    // .position() places the view's CENTER at the given point.
                    // tileOrigin() gives the top-left, so we offset by half tile size.
                    .position(x: origin.x + w / 2, y: origin.y + h / 2)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        } else {
            // Square grid: standard VStack/HStack layout with uniform spacing.
            VStack(spacing: gridSpacing) {
                ForEach(0..<viewModel.board.height, id: \.self) { row in
                    HStack(spacing: gridSpacing) {
                        ForEach(0..<viewModel.board.width, id: \.self) { col in
                            let coord = Coordinate(row: row, col: col)
                            TileView(
                                tile: viewModel.board[coord],
                                gameOver: isGameInactive,
                                tileSize: tileSize,
                                gridShape: .square,
                                biomeId: viewModel.levelSpec.biomeId,
                                isHighlighted: isLinkedHighlighted(coord),
                                isIlluminated: viewModel.illuminatedCoords.contains(coord),
                                quicksandFadeProgress: viewModel.levelSpec.hasQuicksand
                                    ? viewModel.quicksandFadeProgress : 0.0
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Input Handling

    private func handleBoardInput(_ action: BoardInputAction) {
        let revealedBefore = viewModel.board.revealedSafeCount
        let previousGameState = viewModel.gameState

        switch action {
        case .scan(let coord):
            // Conductor targeting mode: flash illuminates a 3×3 area around click
            if viewModel.isConductorTargeting {
                if viewModel.useConductorCharge(at: coord) {
                    audioManager.play(.conductorPulse)
                }
            // Beacon targeting mode: scan-click uses a charge on fogged tiles
            } else if viewModel.isBeaconTargeting {
                if !viewModel.useBeaconCharge(at: coord) {
                    // Clicked a non-fogged tile — cancel targeting, do normal scan
                    viewModel.cancelBeaconTargeting()
                    viewModel.scanTile(at: coord)
                } else {
                    audioManager.play(.beaconClear)
                }
            // Sonar lock toggle: clicking a revealed sonar tile pins/unpins its sight lines.
            // Takes priority over a normal scan so the click isn't consumed by scanTile
            // (revealed tiles are a no-op there anyway, but this makes intent explicit).
            } else if viewModel.levelSpec.hasSonar,
                      viewModel.board.isValid(coord),
                      viewModel.board[coord].isSonar,
                      viewModel.board[coord].isRevealed {
                viewModel.toggleSonarLock(at: coord)
                audioManager.play(.sonarToggle)
            } else {
                viewModel.scanTile(at: coord)
            }
        case .tag(let coord):
            // Right-click cancels any active targeting mode
            if viewModel.isConductorTargeting {
                viewModel.cancelConductorTargeting()
            } else if viewModel.isBeaconTargeting {
                viewModel.cancelBeaconTargeting()
            } else {
                let previousTagState = viewModel.board.isValid(coord) ? viewModel.board[coord].tagState : nil
                viewModel.tagTile(at: coord)
                if viewModel.board.isValid(coord), viewModel.board[coord].tagState != previousTagState {
                    audioManager.play(.tag)
                }
            }
        case .chord(let coord):
            viewModel.chordTile(at: coord)
        }

        if previousGameState != .exploding, viewModel.gameState == .exploding {
            audioManager.play(.hazardClick)
            return
        }

        let revealedDelta = viewModel.board.revealedSafeCount - revealedBefore
        if revealedDelta > 1 {
            audioManager.play(.cascade)
        } else if revealedDelta == 1 {
            audioManager.play(.safeScan)
        }
    }

    // MARK: - Controls Hint

    private var controlsHint: some View {
        HStack(spacing: 20) {
            hintItem("Click", clickHintLabel)
            hintItem("Right-click", "Tag")
            hintItem("Shift-click", "Chord")
            if viewModel.conductorChargesRemaining > 0 || viewModel.isConductorTargeting {
                hintItem("C", "Pulse")
            }
            if viewModel.beaconChargesRemaining > 0 || viewModel.isBeaconTargeting {
                hintItem("B", "Beacon")
            }
            hintItem("R", "Retry")
            hintItem("Space", "Pause")
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.80))
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }

    /// Dynamic label for the click hint based on active targeting mode.
    private var clickHintLabel: String {
        if viewModel.isConductorTargeting { return "Pulse Here" }
        if viewModel.isBeaconTargeting    { return "Clear Fog" }
        return "Scan"
    }

    private func hintItem(_ key: String, _ action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .fontWeight(.medium)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                )
            Text(action)
        }
    }

    // MARK: - Linked Tile Highlight

    /// True if the given coordinate should be highlighted as a linked partner.
    /// This fires both during the post-reveal pulse (from GameViewModel) and
    /// while the cursor hovers over the partner tile.
    private func isLinkedHighlighted(_ coord: Coordinate) -> Bool {
        coord == viewModel.linkedHighlightedCoord
    }

    // MARK: - Pause Overlay

    /// Card shown over the blurred board whenever the game is paused.
    /// Covers tile information so the player cannot use pause as a free study window.
    private var pausedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Paused")
                .font(.title2.weight(.semibold))
            Text("Press Space to resume")
                .font(.caption)
                .foregroundColor(.secondary)

            if onSaveAndExit != nil {
                Button {
                    guard let suspendedRun = viewModel.makeSuspendedRun() else { return }
                    audioManager.playMenuClick()
                    DispatchQueue.main.async {
                        onSaveAndExit?(suspendedRun)
                    }
                } label: {
                    Text("Save and Quit")
                        .fontWeight(.semibold)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 12)
    }

    // MARK: - Helpers

    private func togglePause() {
        if viewModel.gameState == .playing {
            audioManager.play(.pauseOpen)
            DispatchQueue.main.async {
                viewModel.pause()
            }
        } else if viewModel.gameState == .paused {
            audioManager.play(.pauseClose)
            DispatchQueue.main.async {
                viewModel.resume()
            }
        }
    }

    private func openSettings() {
        shouldResumeAfterSettings = viewModel.gameState == .playing
        if shouldResumeAfterSettings {
            DispatchQueue.main.async {
                viewModel.pause()
            }
        }
        showingSettings = true
    }

    private func handleSettingsDismissed() {
        defer { shouldResumeAfterSettings = false }
        guard shouldResumeAfterSettings, viewModel.gameState == .paused else { return }
        DispatchQueue.main.async {
            viewModel.resume()
        }
    }

    private func syncMusicForCurrentState() {
        switch viewModel.gameState {
        case .won:
            audioManager.transition(to: .victory(biomeId: viewModel.levelSpec.biomeId))
        case .lost, .exploding:
            audioManager.transition(to: .loss(biomeId: viewModel.levelSpec.biomeId))
        default:
            audioManager.transition(to: .gameplay(biomeId: viewModel.levelSpec.biomeId))
        }
    }

    // MARK: - Explosion Tile Data Builder

    /// Snapshots every tile's visual state and position into `TileExplosionData`
    /// for the SpriteKit explosion scene. Called once when the 2-second study
    /// period ends and the shatter animation is about to begin.
    private func buildExplosionTileData() -> [TileExplosionData] {
        let board = viewModel.board
        let geo   = board.geometry
        let theme = BiomeTheme.theme(for: viewModel.levelSpec.biomeId)

        // BFS ring distances from explosion origin.
        var ringDistances: [Coordinate: Int] = [:]
        if let origin = viewModel.explosionOrigin {
            ringDistances[origin] = 0
            var queue: [Coordinate] = [origin]
            var head = 0
            while head < queue.count {
                let current = queue[head]; head += 1
                let dist = ringDistances[current]!
                for neighbor in board.neighbors(of: current) {
                    if ringDistances[neighbor] == nil {
                        ringDistances[neighbor] = dist + 1
                        queue.append(neighbor)
                    }
                }
            }
        }

        let hazardColor = NSColor(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255, alpha: 1.0)
        let revealedNS  = NSColor(theme.revealedOverlayColor)

        return board.allCoordinates.map { coord in
            let tile = board[coord]
            let origin = geo.tileOrigin(at: coord, tileSize: tileSize, spacing: gridSpacing)
            let w = geo.tileWidth(tileSize)
            let h = geo.tileHeight(tileSize)
            let center = CGPoint(x: origin.x + w / 2, y: origin.y + h / 2)

            // Determine dominant fill colour for this tile.
            let fill: NSColor
            if tile.isHazard {
                fill = hazardColor
            } else {
                // Approximate the revealed overlay at ~0.75 opacity over a dark base.
                // The exact compositing depends on the background, but a solid colour
                // close to the overlay is good enough for shatter fragments.
                fill = revealedNS.withAlphaComponent(0.85)
            }

            let isOrigin = (coord == viewModel.explosionOrigin)
            let ring = ringDistances[coord] ?? 0

            return TileExplosionData(
                coord: coord,
                center: center,
                size: CGSize(width: w, height: h),
                fillColor: fill,
                isExplosionOrigin: isOrigin,
                ringDistance: ring
            )
        }
    }
}
