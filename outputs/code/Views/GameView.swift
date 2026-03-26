// Signalfield/Views/GameView.swift

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

    // MARK: - Linked Tile Hover (Biome 2)

    /// The board coordinate currently under the cursor (nil when cursor is off-board).
    @State private var hoveredCoord: Coordinate? = nil

    // MARK: - Biome Intro Overlays

    /// Controls visibility of the biome intro card. Starts true so the overlay
    /// appears immediately when the view is created. Because GameView is given a
    /// new SwiftUI identity (.id()) each time a level is selected, this @State
    /// resets to true on every level load — meaning the overlay re-appears every
    /// time the player enters a first-biome level, without any persistence needed.
    @State private var showBiomeIntro = true

    /// Controls visibility of The Delta intro overlay (L63 entry).
    /// Resets to true on every level load (like showBiomeIntro) but is also
    /// gated by @AppStorage so the player can permanently suppress it.
    @State private var showDeltaIntro = true

    /// Persistent "don't show again" flag for The Delta intro.
    /// Mirrors the @AppStorage key written by DeltaIntroOverlay itself.
    @AppStorage("deltaIntroNeverShow") private var deltaIntroNeverShow = false

    /// Measured outer container size. Updated whenever the window resizes.
    /// Drives `tileSize` so the board always fits within the available space.
    /// Initial value matches a typical compact window; the GeometryReader
    /// fires on first layout and corrects it before the user sees the board.
    @State private var containerSize: CGSize = CGSize(width: 600, height: 700)

    /// True only for the opening level of each biome that has a BiomeIntroOverlay card.
    /// L63 / L137 (The Delta square + hex) are intentionally excluded — they have DeltaIntroOverlay.
    /// L75 (Training Range: Hex Mode) is also excluded — Training Range needs no intro.
    private var isFirstBiomeLevel: Bool {
        // Square biome openers
        viewModel.levelSpec.id == "L7"   ||   // Fog Marsh
        viewModel.levelSpec.id == "L15"  ||   // Bioluminescence
        viewModel.levelSpec.id == "L23"  ||   // Frozen Mirrors
        viewModel.levelSpec.id == "L31"  ||   // Ruins
        viewModel.levelSpec.id == "L39"  ||   // The Underside
        viewModel.levelSpec.id == "L47"  ||   // Coral Basin
        viewModel.levelSpec.id == "L55"  ||   // Quicksand
        // Hex biome openers (mirror the above; Training Range hex L75 intentionally omitted)
        viewModel.levelSpec.id == "L81"  ||   // Fog Marsh: Hex Mode
        viewModel.levelSpec.id == "L89"  ||   // Bioluminescence: Hex Mode
        viewModel.levelSpec.id == "L97"  ||   // Frozen Mirrors: Hex Mode
        viewModel.levelSpec.id == "L105" ||   // Ruins: Hex Mode
        viewModel.levelSpec.id == "L113" ||   // The Underside: Hex Mode
        viewModel.levelSpec.id == "L121" ||   // Coral Basin: Hex Mode
        viewModel.levelSpec.id == "L129"      // Quicksand: Hex Mode
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
         onNextLevel: (() -> Void)? = nil, onReturnToMap: (() -> Void)? = nil,
         isLastLevelOfBiome: Bool = false, biomeName: String = "",
         biomeIcon: String = "", biomeLevelIds: [String] = []) {
        // _viewModel uses the @StateObject autoclosure so SwiftUI creates the
        // object exactly once per view identity. A new .id() in the parent
        // means a new identity → a new ViewModel → a new random seed.
        _viewModel = StateObject(wrappedValue: GameViewModel(levelSpec: levelSpec, seed: seed))
        self.onNextLevel        = onNextLevel
        self.onReturnToMap      = onReturnToMap
        self.isLastLevelOfBiome = isLastLevelOfBiome
        self.biomeName          = biomeName
        self.biomeIcon          = biomeIcon
        self.biomeLevelIds      = biomeLevelIds
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

    private var isGameOver: Bool {
        viewModel.gameState == .won || viewModel.gameState == .lost
    }

    var body: some View {
        ZStack {
          // Full-bleed biome background image — sits behind everything.
          // scaledToFill + ignoresSafeArea ensures it covers the entire window
          // without letterboxing, regardless of aspect ratio.
          Image(viewModel.levelSpec.gameplayImageName)
              .resizable()
              .scaledToFill()
              .ignoresSafeArea()
              .allowsHitTesting(false)

          VStack(spacing: 16) {
            // Level header
            Text(viewModel.levelSpec.displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)

            // HUD
            HUDView(viewModel: viewModel)
                .padding(.horizontal)

            // Game board with input overlay.
            // EndOfLevelView / BiomeCompleteView have been moved to the OUTER ZStack
            // so they are genuine full-window overlays and never affect this ZStack's
            // size. When they lived here, EndOfLevelView's .frame(maxWidth:.infinity,
            // maxHeight:.infinity) expanded this ZStack beyond boardWithInput's natural
            // size, causing boardWithInput to shift downward via ZStack center-alignment.
            ZStack {
                boardWithInput
                    // Board stays at full opacity — the collapsible card provides its
                    // own frosted glass contrast; no full-board dimming needed.
                    .opacity(1.0)
                    // Blur the board immediately when paused so the player cannot
                    // study tile positions while the timer is stopped.
                    // No animation() here so the blur is instant on Space-press.
                    .blur(radius: isPaused ? 10 : 0)

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
                .opacity(isGameOver ? 0 : 1)

            Spacer(minLength: 0)
          }
          .padding(20)
          .frame(minWidth: 400, minHeight: 500)

          // Biome intro overlays — shown every time the player enters the first
          // level of a biome. Dismissed by tapping anywhere, clicking Got it,
          // or pressing any key.
          if showBiomeIntro && isFirstBiomeLevel {
              biomeIntroOverlay
                  .transition(.opacity)
          }

          // Delta intro overlay — shown on L63 (square) or L137 (hex) entry
          // unless permanently dismissed. Uses a distinct dark-indigo aesthetic
          // and shows all 7 biome icons.
          if showDeltaIntro && !deltaIntroNeverShow
              && (viewModel.levelSpec.id == "L63" || viewModel.levelSpec.id == "L137") {
              DeltaIntroOverlay {
                  withAnimation(.easeInOut(duration: 0.35)) {
                      showDeltaIntro = false
                  }
              }
              .transition(.opacity)
          }

          // End-of-level overlays — live in the OUTER ZStack so they are true
          // full-window overlays and cannot affect the VStack / board ZStack layout.
          // EndOfLevelView uses .frame(maxWidth:.infinity, maxHeight:.infinity) for
          // its collapsed-pill positioning; placing it here means that frame expands
          // against the window, not against the board ZStack.
          if isGameOver {
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
                                 onNextLevel:   onNextLevel,
                                 onReturnToMap: onReturnToMap)
                      .transition(.opacity)
              }
          }
        }
        // Measure the available container size so tileSize can fit the board.
        // Using .background(GeometryReader) + onPreferenceChange avoids
        // layout loops — the preference fires after layout, not before it.
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ContainerSizeKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(ContainerSizeKey.self) { size in
            if size.width > 0 && size.height > 0 {
                containerSize = size
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showBiomeIntro)
        .animation(.easeInOut(duration: 0.35), value: showDeltaIntro)
        .animation(.easeInOut(duration: 0.30), value: isGameOver)
        .focusable()
        .onKeyPress(.space) {
            togglePause()
            return .handled
        }
        .onKeyPress("r") {
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
        // MARK: - Progress Save
        // Fires once when the player wins. Saves the result and handles shield logic.
        .onChange(of: viewModel.gameState) {
            guard viewModel.gameState == .won else { return }

            // Persist level result (best-of logic lives inside recordResult).
            progressStore.recordResult(
                levelId:     viewModel.levelSpec.id,
                score:       viewModel.score,
                timeSeconds: viewModel.elapsedTime,
                stars:       viewModel.stars
            )

            // Award a Casual Shield if the player scored 3★ on a biome opener.
            // Training Range biomes (0 and 9) are included — every biome can grant a shield.
            if isFirstLevelOfAnyBiome && viewModel.stars == 3 {
                progressStore.markShieldEarned(biomeId: viewModel.levelSpec.biomeId)
            }

            // Record shield consumption. shieldUsed is set in RunStats the moment
            // the player activates a shield mid-run, so this check is reliable.
            if viewModel.stats.shieldUsed {
                progressStore.markShieldUsed(biomeId: viewModel.levelSpec.biomeId)
            }
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
            if !isGameOver {
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
                        gameOver: isGameOver,
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
                                gameOver: isGameOver,
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
        switch action {
        case .scan(let coord):
            // Conductor targeting mode: flash illuminates a 3×3 area around click
            if viewModel.isConductorTargeting {
                viewModel.useConductorCharge(at: coord)
            // Beacon targeting mode: scan-click uses a charge on fogged tiles
            } else if viewModel.isBeaconTargeting {
                if !viewModel.useBeaconCharge(at: coord) {
                    // Clicked a non-fogged tile — cancel targeting, do normal scan
                    viewModel.cancelBeaconTargeting()
                    viewModel.scanTile(at: coord)
                }
            // Sonar lock toggle: clicking a revealed sonar tile pins/unpins its sight lines.
            // Takes priority over a normal scan so the click isn't consumed by scanTile
            // (revealed tiles are a no-op there anyway, but this makes intent explicit).
            } else if viewModel.levelSpec.hasSonar,
                      viewModel.board.isValid(coord),
                      viewModel.board[coord].isSonar,
                      viewModel.board[coord].isRevealed {
                viewModel.toggleSonarLock(at: coord)
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
                viewModel.tagTile(at: coord)
            }
        case .chord(let coord):
            viewModel.chordTile(at: coord)
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

    // MARK: - Biome Intro Content

    /// Returns the correct BiomeIntroOverlay for the current level's biome.
    /// Only called when `isFirstBiomeLevel` is true.
    ///
    /// Handles both square and hex biomes by mapping the biomeId to its base
    /// square equivalent: hex biomes 10–16 map to square biomes 1–7 by subtracting 9.
    /// The title suffix ": Hex Mode" is appended for hex levels automatically.
    @ViewBuilder
    private var biomeIntroOverlay: some View {
        let bid    = viewModel.levelSpec.biomeId
        let isHex  = viewModel.levelSpec.gridShape == .hexagonal
        // Map hex biomeId (10–16) back to its square equivalent (1–7).
        // Square biomes 1–7 pass through unchanged.
        let base   = bid >= 10 ? bid - 9 : bid
        let suffix = isHex ? ": Hex Mode" : ""

        if base == 1 {
            BiomeIntroOverlay(
                title: "Fog Marsh\(suffix)",
                icon: "cloud.fog",
                message: "Some tiles are fogged — they show a signal range instead of an exact number.\n\nUse your beacon charges (shown in the HUD) to clear fog from a tile of your choice. Save them for when you really need them.",
                onDismiss: { showBiomeIntro = false }
            )
        } else if base == 2 {
            BiomeIntroOverlay(
                title: "Bioluminescence\(suffix)",
                icon: "lightbulb.fill",
                message: "In Bioluminescence, you have one deep pulse to use wisely. Activate it from the HUD (or press C), then click anywhere on the board to send a bioluminescent glow through that area — briefly revealing what lies beneath.\n\nUse it where you need it most — the glow fades in a second.",
                onDismiss: { showBiomeIntro = false }
            )
        } else if base == 3 {
            BiomeIntroOverlay(
                title: "Frozen Mirrors\(suffix)",
                icon: "arrow.left.arrow.right",
                message: "Linked tiles reflect each other's signal — the number you see belongs to the partner, not this tile.\n\nLook for the matching colors to find each pair.",
                onDismiss: { showBiomeIntro = false }
            )
        } else if base == 4 {
            BiomeIntroOverlay(
                title: "Ruins\(suffix)",
                icon: "lock.fill",
                message: "Some tiles in these Ruins are locked — they won't reveal until enough surrounding tiles have been uncovered.\n\nWatch the countdown and plan your path carefully.",
                onDismiss: { showBiomeIntro = false }
            )
        } else if base == 5 {
            BiomeIntroOverlay(
                title: "The Underside\(suffix)",
                icon: "arrow.up.arrow.down",
                message: "In The Underside, everything is reversed — tiles show how many safe neighbors they have, not dangerous ones.\n\nA high number means safety nearby.",
                onDismiss: { showBiomeIntro = false }
            )
        } else if base == 6 {
            BiomeIntroOverlay(
                title: "Coral Basin\(suffix)",
                icon: "scope",
                message: "Sonar tiles scan in all four directions — their number is the total hazards spotted across all four lines of sight.\n\nCross-reference multiple sonars to triangulate exactly where danger lies.",
                onDismiss: { showBiomeIntro = false }
            )
        } else if base == 7 {
            BiomeIntroOverlay(
                title: "Quicksand\(suffix)",
                icon: "hourglass.bottomhalf.filled",
                message: "In Quicksand, revealed numbers slowly sink away. Click any hidden tile to resurface them — but the sand keeps pulling them back down.\n\nA faint tint is all that remains when they are gone.",
                onDismiss: { showBiomeIntro = false }
            )
        }
    }

    // MARK: - Pause Overlay

    /// Card shown over the blurred board whenever the game is paused.
    /// Covers tile information so the player cannot use pause as a free study window.
    private var pausedOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Paused")
                .font(.title2.weight(.semibold))
            Text("Press Space to resume")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 12)
    }

    // MARK: - Helpers

    private func togglePause() {
        if viewModel.gameState == .playing {
            viewModel.pause()
        } else if viewModel.gameState == .paused {
            viewModel.resume()
        }
    }
}

// MARK: - Container Size Preference Key

/// Propagates the outer container's measured size up through the view tree
/// so `GameView.tileSize` can be computed from the actual available space.
private struct ContainerSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
