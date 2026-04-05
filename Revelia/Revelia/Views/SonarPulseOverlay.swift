// Revelia/Views/SonarPulseOverlay.swift

import SwiftUI

/// Sonar tile glow, sight-line pulse, and click-to-lock overlay for Coral Basin (Biome 6)
/// and The Delta (Biome 8) levels that include sonar tiles.
///
/// ## Three-state visual design
///
/// **Default state (no interaction)**
/// Every revealed sonar tile shows a gentle slow rhythmic glow — a breathing opacity
/// pulse on its own cell using its assigned colour. No sight-line tinting is drawn.
/// This draws the player's attention and signals the tile is interactive, without
/// cluttering the board when there are multiple sonars.
///
/// **Hover state**
/// When the cursor moves over a revealed sonar tile, its four cardinal sight lines
/// light up: a static background tint appears along the full beam, and a smooth
/// travelling wave moves outward from the sonar to the board edges, 50–60 % opacity
/// at peak. The mechanic becomes immediately legible — the player can see exactly
/// which tiles contribute to the sonar's count.
///
/// **Locked state (click-to-lock)**
/// Left-clicking a revealed sonar tile pins its sight lines on permanently.
/// A second click unpins them. `GameViewModel.lockedSonarCoords` tracks the set;
/// `GameView.handleBoardInput` intercepts the click and calls `toggleSonarLock`.
/// Locked sight lines behave identically to hovered sight lines and persist even
/// after the cursor moves away, letting the player cross-reference multiple beams.
///
/// ## Per-sonar colour assignment
/// Each revealed sonar is assigned a colour from the 6-colour palette in board-scan
/// order (row-major, top-left → bottom-right). When beams from two active sonars
/// overlap, the shared tile is split into equal-width vertical strips, one per colour,
/// clipped to the tile's rounded-corner shape so both colours remain distinguishable.
///
/// ## Phase staggering
/// When multiple sonars are active (hover + locked, or several locked), their wave
/// phases are offset by `colorIdx × 0.25 × cycleDuration` so the beams don't all
/// pulse in perfect lockstep. The tile glow phases are similarly staggered by 0.6 s
/// per sonar. Both offsets are deterministic (index-based), so the visual is stable
/// across board updates.
///
/// ## Performance
/// `TimelineView(.animation(paused:))` is paused only when no sonar tiles have been
/// revealed yet. Once any sonar is revealed, the animation clock runs continuously
/// to drive the tile glow pulse. A single `Canvas` call renders all layers per tick.
///
/// ## Stop condition
/// All animation fades out smoothly over 1.4 s when `gameWon` transitions to true.
struct SonarPulseOverlay: View {

    let board: Board
    let tileSize: CGFloat
    let gridSpacing: CGFloat
    /// Pass `viewModel.gameState == .won` — triggers the win fade-out.
    let gameWon: Bool
    /// Pass `hoveredCoord` from GameView.
    let hoveredCoord: Coordinate?
    /// Pass `viewModel.lockedSonarCoords` from GameView.
    let lockedSonarCoords: Set<Coordinate>

    // MARK: - Palette

    /// Six distinct colours, one per sonar tile (in board-scan order).
    private static let palette: [Color] = [
        Color(red: 0.00, green: 0.71, blue: 0.85),  // 1. Teal / Cyan
        Color(red: 0.97, green: 0.58, blue: 0.10),  // 2. Amber / Orange
        Color(red: 0.60, green: 0.20, blue: 0.92),  // 3. Violet / Purple
        Color(red: 0.96, green: 0.27, blue: 0.52),  // 4. Rose / Pink
        Color(red: 0.28, green: 0.84, blue: 0.15),  // 5. Lime / Green
        Color(red: 0.95, green: 0.28, blue: 0.22),  // 6. Coral / Red
    ]

    // MARK: - Tile glow constants (default state)

    /// Period of the slow breathing glow on the sonar tile itself.
    private static let glowPeriod: Double = 2.8
    /// Minimum opacity for the tile glow (bottom of the breath).
    private static let glowMin:    Double = 0.06
    /// Maximum opacity for the tile glow (top of the breath).
    private static let glowMax:    Double = 0.24
    /// Phase stagger between sonar glow cycles (seconds), keyed by colorIdx.
    /// Prevents all sonar tiles from breathing in perfect unison.
    private static let glowStagger: Double = 0.6

    // MARK: - Sight-line pulse constants (hover / locked state)

    /// Background tint opacity on sight-line tiles while a beam is active.
    private static let sightLineTint: Double = 0.18
    /// Full cycle duration: outward leg (T/2) then return leg (T/2).
    private static let cycleDuration:  Double = 3.6
    /// Blob half-width as a fraction of beam length.
    /// 0.40 keeps the wave clearly visible without stretching across the entire beam.
    private static let blobHalfWidth:  Double = 0.40
    /// Additional opacity the wave blob contributes at its centre.
    /// Background(0.18) + blobPeak(0.40) ≈ 0.58 — in the 50–60 % spec range.
    private static let blobPeak:       Double = 0.40
    /// Phase stagger between active sonar wave cycles, as a fraction of cycleDuration.
    /// Offset = colorIdx × stagger × cycleDuration.
    private static let waveStagger: Double = 0.25

    // MARK: - Fade-out state

    @State private var overlayOpacity: Double = 1.0

    // MARK: - Derived properties

    /// All currently revealed sonar tiles, in board-scan order, with palette index.
    /// Iteration order over `allCoordinates` is deterministic (row-major), so the
    /// colour assignment is stable and never flickers on board updates.
    private var revealedSonars: [(coord: Coordinate, colorIdx: Int)] {
        var result: [(coord: Coordinate, colorIdx: Int)] = []
        for coord in board.allCoordinates {
            guard board[coord].isSonar && board[coord].isRevealed else { continue }
            result.append((coord: coord, colorIdx: result.count % Self.palette.count))
        }
        return result
    }

    /// Subset of revealed sonars whose sight lines are currently active:
    /// either hovered or pinned via click-to-lock.
    private func activeSonars(
        from all: [(coord: Coordinate, colorIdx: Int)]
    ) -> [(coord: Coordinate, colorIdx: Int)] {
        all.filter { entry in
            entry.coord == hoveredCoord || lockedSonarCoords.contains(entry.coord)
        }
    }

    // MARK: - Body

    var body: some View {
        // The tile glow needs a continuous animation clock once any sonar is revealed.
        // Pause only when no sonar tiles exist yet (pre-first-scan or non-sonar levels).
        TimelineView(.animation(minimumInterval: nil, paused: revealedSonars.isEmpty)) { context in
            Canvas { ctx, _ in
                let sonars = revealedSonars
                guard !sonars.isEmpty else { return }

                // Absolute epoch time — immune to view re-initialisation flickering.
                // SwiftUI re-creates the struct on every board update; a stored
                // `Date()` property would reset the clock each time and cause
                // visible animation jumps. The epoch reference is always stable.
                let elapsed = context.date.timeIntervalSinceReferenceDate

                // Layer 1: sight-line background tint for active (hover/locked) sonars.
                // Drawn first so the wave pulse composites cleanly on top.
                let active = activeSonars(from: sonars)
                if !active.isEmpty {
                    drawSightLineTints(ctx: ctx, activeSonars: active)

                    // Layer 2: travelling wave on top of the static tint.
                    drawSightLineWaves(ctx: ctx, activeSonars: active, elapsed: elapsed)
                }

                // Layer 3: tile glow on every revealed sonar cell.
                // Always present — this is the "resting" interactive indicator.
                drawTileGlow(ctx: ctx, sonars: sonars, elapsed: elapsed)
            }
        }
        .opacity(overlayOpacity)
        .allowsHitTesting(false)
        .onChange(of: gameWon) {
            withAnimation(gameWon ? .easeOut(duration: 1.4) : .easeIn(duration: 0.3)) {
                overlayOpacity = gameWon ? 0.0 : 1.0
            }
        }
    }

    // MARK: - Layer 1: sight-line background tint

    /// Paints a static background tint over all sonar sight-line beams of each
    /// active sonar. Overlapping beams use vertical strip splitting so both colours
    /// remain visible rather than blending into an indeterminate hue.
    ///
    /// Uses `board.sonarBeams(from:)` so the beam count is geometry-aware
    /// (4 for square, 6 for hex) — no hardcoded cardinal directions.
    private func drawSightLineTints(
        ctx: GraphicsContext,
        activeSonars: [(coord: Coordinate, colorIdx: Int)]
    ) {
        // Build coverage map: coordinate → sorted list of colour indices whose
        // active beams cover it. Sorted so strip order is always left-to-right
        // by palette index — consistent regardless of board iteration order.
        var coverage: [Coordinate: [Int]] = [:]
        for sonar in activeSonars {
            for beam in board.sonarBeams(from: sonar.coord) {
                for coord in beam {
                    coverage[coord, default: []].append(sonar.colorIdx)
                }
            }
        }

        for (coord, colorIndices) in coverage {
            let rect  = tileRect(for: coord)
            let sorted = colorIndices.sorted()

            if sorted.count == 1 {
                // Single beam: full tile-shape fill.
                ctx.fill(
                    tilePath(for: rect),
                    with: .color(Self.palette[sorted[0]].opacity(Self.sightLineTint))
                )
            } else {
                // Multiple beams: split into equal vertical strips, clipped to
                // the tile's outline shape so the splits look clean on both
                // square (rounded-rect) and hex (polygon) boards.
                ctx.drawLayer { innerCtx in
                    innerCtx.clip(to: tilePath(for: rect))
                    let stripWidth = rect.width / CGFloat(sorted.count)
                    for (i, colorIdx) in sorted.enumerated() {
                        let strip = CGRect(
                            x: rect.minX + CGFloat(i) * stripWidth,
                            y: rect.minY,
                            width: stripWidth,
                            height: rect.height
                        )
                        innerCtx.fill(
                            Path(strip),
                            with: .color(Self.palette[colorIdx].opacity(Self.sightLineTint))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Layer 2: travelling wave

    /// Draws a smooth travelling wave along the sight lines of each active sonar.
    ///
    /// Wave position uses a cosine curve `0.5 − 0.5 × cos(2π × t/T)` which produces
    /// natural ease-in/ease-out at both ends (slows near the sonar and near the edge)
    /// with no abrupt directional reversal at the turnaround point.
    ///
    /// The blob profile uses a raised-cosine (Hann) window so the wave has smooth
    /// zero-derivative edges — no hard opacity boundary as it enters or leaves a tile.
    ///
    /// Each sonar's phase is offset by `colorIdx × waveStagger × cycleDuration` so
    /// multiple active beams don't all pulse in lockstep.
    private func drawSightLineWaves(
        ctx: GraphicsContext,
        activeSonars: [(coord: Coordinate, colorIdx: Int)],
        elapsed: TimeInterval
    ) {
        for sonar in activeSonars {
            let color       = Self.palette[sonar.colorIdx]
            let phaseOffset = Double(sonar.colorIdx) * Self.waveStagger * Self.cycleDuration
            let unitPhase   = (elapsed + phaseOffset)
                                  .truncatingRemainder(dividingBy: Self.cycleDuration)
                              / Self.cycleDuration
            // Smooth cosine position: 0.0 (at sonar) → 1.0 (board edge) → 0.0, looping.
            let waveProgress = 0.5 - 0.5 * cos(2.0 * Double.pi * unitPhase)

            // Uses board.sonarBeams(from:) — geometry-aware (4 beams square, 6 beams hex).
            for beam in board.sonarBeams(from: sonar.coord) {
                guard !beam.isEmpty else { continue }

                // d = 0.0 at sonar's immediate neighbour → 1.0 at board-edge tile.
                // Dividing by (count − 1) ensures the last tile maps exactly to d = 1.0,
                // aligning with waveProgress = 1.0 at the turnaround point.
                let divisor = Double(max(beam.count - 1, 1))

                for (i, coord) in beam.enumerated() {
                    let d            = Double(i) / divisor
                    let distFromWave = abs(d - waveProgress)
                    guard distFromWave < Self.blobHalfWidth else { continue }

                    // Raised-cosine (Hann) profile: smooth zero-crossing edges.
                    // t = 0 at wave centre, t = 1 at blob edge.
                    let t            = distFromWave / Self.blobHalfWidth
                    let pulseOpacity = Self.blobPeak * 0.5 * (1.0 + cos(Double.pi * t))
                    guard pulseOpacity > 0.005 else { continue }

                    ctx.fill(
                        tilePath(for: tileRect(for: coord)),
                        with: .color(color.opacity(pulseOpacity))
                    )
                }
            }
        }
    }

    // MARK: - Layer 3: tile glow

    /// Draws the slow breathing glow on every revealed sonar tile.
    ///
    /// Uses a cosine opacity oscillation between `glowMin` and `glowMax` over
    /// `glowPeriod` seconds. Each sonar is phase-offset by `colorIdx × glowStagger`
    /// seconds so they don't all breathe in perfect unison.
    ///
    /// The glow is drawn on top of the sight-line layers so the sonar tile itself
    /// is always the brightest / most prominent element even when its lines are active.
    private func drawTileGlow(
        ctx: GraphicsContext,
        sonars: [(coord: Coordinate, colorIdx: Int)],
        elapsed: TimeInterval
    ) {
        for sonar in sonars {
            let color       = Self.palette[sonar.colorIdx]
            let phaseOffset = Double(sonar.colorIdx) * Self.glowStagger
            let phase       = (elapsed + phaseOffset)
                                  .truncatingRemainder(dividingBy: Self.glowPeriod)
                              / Self.glowPeriod
            // Cosine breathing: glowMin at t=0 → glowMax at t=0.5 → glowMin at t=1.
            let glowOpacity = Self.glowMin
                            + (Self.glowMax - Self.glowMin)
                            * 0.5 * (1.0 - cos(2.0 * Double.pi * phase))

            ctx.fill(
                tilePath(for: tileRect(for: sonar.coord)),
                with: .color(color.opacity(glowOpacity))
            )
        }
    }

    // MARK: - Helpers

    /// Maps a board coordinate to its pixel rectangle in Canvas space.
    ///
    /// The Canvas is framed to `boardCanvasSize` — the exact pixel size of the tile grid —
    /// so the grid's top-left corner maps to the Canvas origin with no offset required.
    ///
    /// Delegates to `board.geometry.tileOrigin()` so both square and hex boards
    /// produce correct pixel rectangles without hardcoding square grid math here.
    private func tileRect(for coord: Coordinate) -> CGRect {
        let geo    = board.geometry
        let origin = geo.tileOrigin(at: coord, tileSize: tileSize, spacing: gridSpacing)
        return CGRect(
            x:      origin.x,
            y:      origin.y,
            width:  geo.tileWidth(tileSize),
            height: geo.tileHeight(tileSize)
        )
    }

    /// Returns the correct fill/clip Path for `rect` given the board's grid shape.
    ///
    /// Mirrors `TileBackgroundShape` in `TileView.swift` so the overlay silhouettes
    /// are always pixel-perfect matches of the rendered tile outlines:
    /// - Square boards → `RoundedRectangle(cornerRadius: 3)`
    /// - Hex boards    → flat-top hexagon polygon
    ///
    /// All three drawing layers (glow, tint, wave) call this helper so the shape
    /// is never hardcoded at individual call sites.
    private func tilePath(for rect: CGRect) -> Path {
        guard board.gridShape == .hexagonal else {
            return Path(roundedRect: rect, cornerRadius: 3)
        }
        // Flat-top hexagon: circumradius R derived from the bounding rect.
        // tileWidth = 2R, tileHeight = √3·R, so both expressions yield R.
        let cx = rect.midX
        let cy = rect.midY
        let R: CGFloat = min(rect.width / 2.0, rect.height / 1.7320508)
        let h: CGFloat = R * 0.8660254   // R × (√3/2), flat-to-centre distance
        let vertices: [CGPoint] = [
            CGPoint(x: cx + R,       y: cy),       // right
            CGPoint(x: cx + R * 0.5, y: cy - h),   // upper-right
            CGPoint(x: cx - R * 0.5, y: cy - h),   // upper-left
            CGPoint(x: cx - R,       y: cy),        // left
            CGPoint(x: cx - R * 0.5, y: cy + h),   // lower-left
            CGPoint(x: cx + R * 0.5, y: cy + h),   // lower-right
        ]
        var path = Path()
        path.move(to: vertices[0])
        for v in vertices.dropFirst() { path.addLine(to: v) }
        path.closeSubpath()
        return path
    }
}

#Preview {
    Color(red: 0.20, green: 0.22, blue: 0.26)
        .frame(width: 300, height: 300)
        .overlay(
            VStack(spacing: 8) {
                Text("Sonar Overlay v4")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text("Default: gentle tile glow\nHover: sight lines + pulse\nClick: lock sight lines on")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        )
}
