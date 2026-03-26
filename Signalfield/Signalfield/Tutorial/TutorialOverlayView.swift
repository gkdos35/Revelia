// Signalfield/Tutorial/TutorialOverlayView.swift
//
// Full-screen guided tutorial overlay. Sits on top of the entire GameView ZStack.
//
// Composed of three layers (bottom to top):
//   1. Semi-transparent scrim with a spotlight cutout revealing the target tile
//   2. Amber pulsing glow rings around neighbor-highlight tiles
//   3. TutorialTooltipView positioned near (but not obscuring) the spotlight
//
// Hit-testing strategy:
//   - Scrim + highlight layers: .allowsHitTesting(false) on their GeometryReader
//     wrapper — taps pass through to the board. The TutorialManager gates input
//     at the logic level, only allowing clicks on the expected tile.
//   - Tooltip layer: rendered DIRECTLY in the outer ZStack (not inside a
//     full-screen container). Only the tooltip card's natural bounds intercept
//     taps; all surrounding area is transparent and passes through to the
//     AppKit BoardInputView below. Critical on macOS: a full-screen SwiftUI
//     container (GeometryReader, ZStack) above an NSViewRepresentable will
//     intercept mouse events in its entire frame even when visually empty.
//
// Positioning contract:
//   boardFrame  — frame of boardWithInput in the overlay's coordinate space
//                 (measured via GeometryReader + coordinateSpace in GameView)
//   tileSize    — same value used by GameView to render tiles
//   gridSpacing — same value used by GameView (always 2pt)
//   board       — the game board, used for geometry calculations
//   manager     — the TutorialManager driving step state

import SwiftUI

// MARK: - TutorialOverlayView

struct TutorialOverlayView: View {

    @ObservedObject var manager: TutorialManager
    let boardFrame: CGRect  // Frame of boardWithInput in the overlay's coordinate space
    let tileSize: CGFloat
    let gridSpacing: CGFloat
    let board: Board

    // Amber highlight pulse animation
    @State private var highlightPulse: Bool = false

    /// Overlay size captured from Layer A's GeometryReader via OverlaySizeKey.
    /// Used by tooltipLayer() to position the tooltip card. Starts at .zero
    /// and is updated on first layout; the tooltip is gated on width > 0 so
    /// it never renders at the origin before the first measurement.
    @State private var measuredOverlaySize: CGSize = .zero

    /// True once boardFrame has been measured (non-zero size).
    /// Guards spotlight cutout and highlight positioning so they don't render
    /// at the origin before the first layout pass completes.
    /// The tooltip layer has its own guard: steps without a spotlight (step1,
    /// step9) render the tooltip at the overlay center without needing boardFrame.
    private var boardFrameReady: Bool {
        boardFrame.width > 0 && boardFrame.height > 0
    }

    var body: some View {
        ZStack {
            // ── Layer A: Non-interactive scrim + highlights ───────────────────
            // GeometryReader measures the overlay size for spotlight/highlight
            // positioning AND publishes it via OverlaySizeKey so the tooltip
            // (rendered outside this layer) can use it for positioning.
            // .allowsHitTesting(false) on this entire layer ensures the
            // full-screen container never swallows taps — HUD buttons and
            // other underlying controls remain reachable at all times.
            GeometryReader { geo in
                let overlaySize = geo.size

                ZStack {
                    // Scrim with spotlight cutout (or uniform scrim before measured)
                    if boardFrameReady {
                        scrimLayer(overlaySize: overlaySize)
                    } else {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }

                    // Amber neighbor highlight rings
                    if boardFrameReady && !manager.highlightCoords.isEmpty {
                        highlightLayer
                    }
                }
                // Animate scrim spotlight moves and highlight ring
                // transitions here — inside the non-interactive layer only.
                // Keeping animation off the outer ZStack prevents SwiftUI
                // from creating full-frame animation wrappers above
                // BoardInputView that would block AppKit mouse events.
                .animation(.easeInOut(duration: 0.2), value: manager.currentStep)
                // Publish the measured overlay size upward so the tooltip
                // layer (outside this GeometryReader) can use it.
                .preference(key: OverlaySizeKey.self, value: overlaySize)
            }
            .allowsHitTesting(false) // ← KEY: entire scrim/highlight layer is non-interactive
            .onPreferenceChange(OverlaySizeKey.self) { size in
                if size.width > 0 { measuredOverlaySize = size }
            }

            // ── Tooltip: rendered DIRECTLY in the outer ZStack ───────────────
            // No wrapping GeometryReader or full-screen container. On macOS,
            // a full-screen SwiftUI container above an AppKit NSViewRepresentable
            // (BoardInputView) intercepts mouse events in its entire frame even
            // when visually empty. By rendering TutorialTooltipView here with
            // .position(), SwiftUI's hit testing is limited to the card's natural
            // bounds (~280×120 pt). Everything outside the card is transparent —
            // taps pass through to BoardInputView unobstructed.
            //
            // Guarded on measuredOverlaySize.width > 0 so the tooltip never
            // flashes at the origin (0,0) during the initial layout pass before
            // the first OverlaySizeKey measurement arrives.
            if measuredOverlaySize.width > 0 {
                tooltipLayer(overlaySize: measuredOverlaySize)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                highlightPulse = true
            }
            // Step 9: auto-dismiss
            if manager.currentStep == .step9_release {
                manager.scheduleStep9AutoDismiss()
            }
        }
        .onChange(of: manager.currentStep) {
            if manager.currentStep == .step9_release {
                manager.scheduleStep9AutoDismiss()
            }
        }
        // NOTE: No .animation() here. Keeping animation scoped to Layer A's
        // non-interactive inner ZStack (above) prevents full-frame SwiftUI
        // animation wrappers from blocking AppKit mouse events on the board.
    }

    // MARK: - Scrim Layer

    @ViewBuilder
    private func scrimLayer(overlaySize: CGSize) -> some View {
        if let coord = manager.spotlightCoord {
            let holeRect = tileRect(for: coord)

            // Even-odd fill punches a hole in the scrim at the tile position.
            // The hole is expanded by 2pt on each side to give a generous
            // spotlight — the border of the tile is visible, not clipped.
            let expandedHole = holeRect.insetBy(dx: -2, dy: -2)

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: overlaySize))
                    path.addRoundedRect(
                        in: expandedHole,
                        cornerSize: CGSize(width: 5, height: 5)
                    )
                }
                .fill(style: FillStyle(eoFill: true))
                .foregroundColor(.black.opacity(0.58))
                .ignoresSafeArea()
                .allowsHitTesting(false)  // Scrim itself is non-interactive
            }
        } else {
            // No spotlight — full uniform scrim
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: - Highlight Layer

    @ViewBuilder
    private var highlightLayer: some View {
        let geo = board.geometry

        ForEach(manager.highlightCoords, id: \.self) { coord in
            let rect   = tileRect(for: coord)
            let w      = geo.tileWidth(tileSize)
            let h      = geo.tileHeight(tileSize)

            // Amber pulsing ring drawn around each highlighted tile
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    Color(red: 0xFF/255.0, green: 0xB7/255.0, blue: 0x00/255.0)
                        .opacity(highlightPulse ? 0.85 : 0.35),
                    lineWidth: 2.5
                )
                .frame(width: w + 6, height: h + 6)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Tooltip Layer

    @ViewBuilder
    private func tooltipLayer(overlaySize: CGSize) -> some View {
        let text = manager.tooltipText

        // For steps that need a spotlight-relative position, wait for boardFrame.
        // For steps with no spotlight (step1, step9), render at overlay center immediately.
        let needsBoardFrame = manager.spotlightCoord != nil
        let canRender = !text.isEmpty && (!needsBoardFrame || boardFrameReady)

        if canRender {
            let spotRect   = (boardFrameReady && manager.spotlightCoord != nil)
                ? manager.spotlightCoord.map { tileRect(for: $0) }
                : nil
            let arrowEdge  = preferredArrowEdge(spotlightRect: spotRect, in: overlaySize)
            let tooltipPos = preferredTooltipPosition(
                spotlightRect: spotRect,
                arrowEdge: arrowEdge,
                in: overlaySize
            )

            TutorialTooltipView(
                message:     text,
                buttonLabel: manager.requiresGotItButton ? "Got it" : "",
                arrowEdge:   arrowEdge,
                onAction:    { manager.advance() }
            )
            .position(tooltipPos)
            // Tooltip is hit-testable — "Got it" button must receive taps
        }
    }

    // MARK: - Tooltip Positioning

    /// Determine which edge of the tooltip the arrow should appear on,
    /// based on whether the spotlight is above or below center.
    private func preferredArrowEdge(spotlightRect: CGRect?, in overlaySize: CGSize) -> TooltipArrowEdge {
        guard let rect = spotlightRect else { return .none }
        // If spotlight is in the upper half, put tooltip below it (arrow on top)
        // If spotlight is in the lower half, put tooltip above it (arrow on bottom)
        return rect.midY < overlaySize.height * 0.5 ? .top : .bottom
    }

    /// Position the tooltip near the spotlight without going off-screen.
    private func preferredTooltipPosition(
        spotlightRect: CGRect?,
        arrowEdge: TooltipArrowEdge,
        in overlaySize: CGSize
    ) -> CGPoint {
        guard let rect = spotlightRect else {
            // No spotlight: center of overlay
            return CGPoint(x: overlaySize.width / 2, y: overlaySize.height / 2)
        }

        let tooltipWidth: CGFloat  = 280    // Approximate, including padding
        let tooltipHeight: CGFloat = 120    // Approximate
        let gap: CGFloat           = 16     // Distance between tile edge and tooltip
        let arrowH: CGFloat        = 10     // Arrow notch height

        var x = rect.midX
        var y: CGFloat

        if arrowEdge == .top {
            // Tooltip appears below the spotlight tile
            y = rect.maxY + gap + tooltipHeight / 2 + arrowH
        } else {
            // Tooltip appears above the spotlight tile
            y = rect.minY - gap - tooltipHeight / 2 - arrowH
        }

        // Clamp to overlay bounds with margin
        let margin: CGFloat = 20
        x = max(tooltipWidth / 2 + margin, min(overlaySize.width - tooltipWidth / 2 - margin, x))
        y = max(tooltipHeight / 2 + margin, min(overlaySize.height - tooltipHeight / 2 - margin, y))

        return CGPoint(x: x, y: y)
    }

    // MARK: - Tile Rect Calculation

    /// Computes the on-screen CGRect for a tile in the overlay's coordinate space.
    ///
    /// boardFrame is the frame of boardWithInput (includes 8pt internal padding).
    /// tileOrigin gives the tile's top-left within the tileGrid.
    /// The tileGrid starts 8pt inside boardWithInput, so we add that offset.
    private func tileRect(for coord: Coordinate) -> CGRect {
        let geo    = board.geometry
        let origin = geo.tileOrigin(at: coord, tileSize: tileSize, spacing: gridSpacing)
        let w      = geo.tileWidth(tileSize)
        let h      = geo.tileHeight(tileSize)

        // boardFrame is the frame of boardWithInput (which has 8pt padding inside it)
        let tileGridOriginX = boardFrame.minX + 8
        let tileGridOriginY = boardFrame.minY + 8

        return CGRect(
            x:      tileGridOriginX + origin.x,
            y:      tileGridOriginY + origin.y,
            width:  w,
            height: h
        )
    }
}

// MARK: - Board Frame Preference Key

/// Propagates the boardWithInput frame from the inner view to TutorialOverlayView.
struct BoardFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Overlay Size Preference Key

/// Propagates the TutorialOverlayView's measured size (from Layer A's GeometryReader)
/// to the overlay's own @State, so the tooltip can be positioned correctly without
/// living inside a full-screen container that would intercept mouse events on macOS.
struct OverlaySizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
