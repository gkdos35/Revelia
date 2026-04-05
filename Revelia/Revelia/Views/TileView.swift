// Revelia/Views/TileView.swift

import SwiftUI

// MARK: - TileBackgroundShape

/// Grid-shape–aware InsettableShape used for tile backgrounds, borders, and highlight rings.
///
/// - Square grids: renders a `RoundedRectangle` with the specified `cornerRadius` (default 3).
/// - Hex grids:    renders a flat-top hexagon whose 6 vertices fit the frame.
///                 `cornerRadius` is ignored for hex shapes.
///
/// Implements `InsettableShape` so both `.fill()` and `.strokeBorder()` work
/// identically to the way they work on `RoundedRectangle`.
struct TileBackgroundShape: InsettableShape {

    /// Whether to render a flat-top hexagon instead of a rounded rectangle.
    let isHex: Bool

    /// Corner radius for the rounded-rectangle path (square grids only).
    /// Default is 3 pt — matching game tile appearance. Pass a larger value
    /// (e.g. 12) for level-select node markers where a more rounded look is desired.
    /// Ignored when `isHex` is true.
    var cornerRadius: CGFloat = 3

    /// Accumulated inset amount applied by `inset(by:)`.
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        // Apply inset to the drawing rect
        let r = CGRect(
            x:      rect.minX  + insetAmount,
            y:      rect.minY  + insetAmount,
            width:  max(0, rect.width  - 2 * insetAmount),
            height: max(0, rect.height - 2 * insetAmount)
        )
        return isHex ? flatTopHexPath(in: r) : roundedRectPath(in: r)
    }

    func inset(by amount: CGFloat) -> TileBackgroundShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    // MARK: Rounded rectangle (square grid)

    private func roundedRectPath(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: max(0, cornerRadius - insetAmount))
    }

    // MARK: Flat-top hexagon (hex grid)
    //
    // For a flat-top hexagon with circumradius R:
    //   Total width  = 2R
    //   Total height = √3 × R
    //
    // Vertex angles (0° = right, counterclockwise in screen space where y↓):
    //   0°   → right         ( R,     0)
    //   60°  → upper-right   ( R/2, -R×√3/2)
    //   120° → upper-left    (-R/2, -R×√3/2)
    //   180° → left          (-R,     0)
    //   240° → lower-left    (-R/2,  R×√3/2)
    //   300° → lower-right   ( R/2,  R×√3/2)

    private func flatTopHexPath(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        // Circumradius: fit inside the given rect
        let R: CGFloat = min(rect.width / 2.0, rect.height / 1.7320508)
        let h: CGFloat = R * 0.8660254   // R × (√3/2) = half hex height

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

// MARK: -

/// Renders a single tile on the game board.
/// Appearance depends on tile state: hidden, revealed (with signal), tagged, or exploded.
///
/// ## Rendering layers (bottom → top)
/// 1. **Base layer** — texture image (hidden), biome overlay (revealed), hazard fill (exploded)
/// 2. **Flag glow** — blurred fill in flagAccentColor behind the flagged-tile border
/// 3. **Border** — thin strokeBorder; colour and width vary by state
/// 4. **Quicksand tint** — sand colour bleeds in as numbers fade (Biome 7 only)
/// 5. **Content** — signal glyph, hazard icon, lock badge, or tag symbols
/// 6. **Fogged-tile dashed border** — inset dashed ring on hidden fogged tiles (Biome 1)
/// 7. **Linked dot indicator** — bottom-right corner dot on hidden linked tiles (Biome 3)
/// 8. **Linked badge** — bottom-left chain icon on revealed linked tiles (Biome 3)
/// 9. **Partner highlight ring** — white ring when this is the hovered partner (Biome 3)
///
/// ## Biome-aware rendering notes
/// - Biome 1 (Fog Marsh): fogged tile shows range in signalColor after reveal;
///   hidden fogged tile shows a dashed border indicator.
/// - Biome 2 (Bioluminescence): illuminated tiles temporarily override to a teal
///   background + white signal (true state, no theme colour).
/// - Biome 3 (Frozen Mirrors): hidden linked tiles show a small dot indicator;
///   revealed tiles keep the pair-tint system for clear visual pairing.
/// - Biome 4 (Ruins): locked tiles render texture at 50 % opacity + padlock content.
/// - Biome 5 (The Underside): inverted colour scale retained (reversed danger signal).
/// - Biome 6 (Coral Basin): sonar heat-map colours retained (communicates intensity).
/// - Biome 7 (Quicksand): fade applies to signal opacity; tint uses theme signalColor.
struct TileView: View {
    let tile: Tile
    let gameOver: Bool  // True when game is won or lost (for board reveal styling)
    let tileSize: CGFloat
    /// The grid topology. Defaults to `.square`; set to `.hexagonal` for hex levels.
    var gridShape: GridShape = .square
    /// Biome ID (0–17). Used to look up the BiomeTheme palette. Defaults to 0.
    var biomeId: Int = 0
    /// True when this tile is the linked partner of the currently hovered/just-revealed tile.
    var isHighlighted: Bool = false
    /// Biome 2 (Bioluminescence): true when this tile is inside an active conductor flash.
    /// Overrides the hidden-state rule for 1 second — shows the tile's true state
    /// (signal or hazard) with a deep teal bioluminescent glow. Read-only: does not
    /// change any tile state, purely a visual burst.
    var isIlluminated: Bool = false
    /// Biome 7 (Quicksand): board-wide fade progress, 0.0 (visible) → 1.0 (invisible).
    /// Zero on all non-Quicksand boards — has no visual effect when at 0.
    var quicksandFadeProgress: Double = 0.0

    // MARK: - Theme

    /// Biome palette used for all colour decisions in this tile.
    private var theme: BiomeTheme { BiomeTheme.theme(for: biomeId) }

    var body: some View {
        ZStack {
            // 1. Base fill / texture layer
            tileBaseLayer

            // 2. Flag glow — blurred halo in flagAccentColor drawn BELOW the border
            //    so the crisp 2.5 pt border sits on top of the soft glow.
            if !isIlluminated && tile.state == .hidden && tile.tagState == .confirmed {
                tileBackground
                    .fill(theme.flagAccentColor.opacity(0.45))
                    .blur(radius: 8)
            }

            // 3. Border
            tileBackground
                .strokeBorder(
                    isIlluminated ? Color.cyan.opacity(0.85) : tileBorderColor,
                    lineWidth: isIlluminated ? 1.5 : tileBorderWidth
                )

            // 4. Biome 7 (Quicksand): sand tint bleeds in as numbers fade.
            //    Suppressed during an illumination flash so the true state is always clear.
            if !isIlluminated && tile.isRevealed && !tile.isHazard && !gameOver
                && quicksandFadeProgress > 0 {
                tileBackground
                    .fill(quicksandTintColor.opacity(quicksandFadeProgress * 0.22))
            }

            // 5. Content
            if isIlluminated {
                illuminatedContent
            } else {
                tileContent
            }

            // 6. Fogged-tile dashed border — inset ring that signals "fog mechanic active
            //    on this tile" without revealing any information about its contents.
            //    Only shown on hidden (not yet revealed) fogged tiles.
            if !isIlluminated && tile.hasFog && tile.state == .hidden {
                tileBackground
                    .inset(by: 3)
                    .stroke(
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    .foregroundColor(theme.signalColor.opacity(0.25))
            }

            // 7. Linked dot indicator — small circle in bottom-right corner of hidden
            //    linked tiles. Both tiles in a pair show this dot so the player knows
            //    a link relationship exists before either tile is revealed.
            if !isIlluminated && tile.isLinked && tile.state == .hidden {
                linkedDotIndicator
            }

            // 8. Linked badge — chain icon on revealed linked tiles (Biome 3).
            if !isIlluminated && tile.isLinked && tile.isRevealed {
                linkedBadge
            }

            // 9. Partner highlight ring
            if !isIlluminated && isHighlighted {
                tileBackground
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2.5)
                    .animation(.easeInOut(duration: 0.25), value: isHighlighted)
            }
        }
        .frame(width: tileRenderWidth, height: tileRenderHeight)
        .animation(.easeOut(duration: 0.3), value: isIlluminated)
        // Biome 4: spring animation when a locked tile unlocks (lockedData → nil + state → revealed)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: tile.isLocked)
    }

    // MARK: - Tile Shape

    /// Grid-shape–aware InsettableShape for backgrounds, borders, and highlight rings.
    private var tileBackground: TileBackgroundShape {
        TileBackgroundShape(isHex: gridShape == .hexagonal)
    }

    /// Rendered pixel width for this tile's frame.
    private var tileRenderWidth: CGFloat {
        gridShape == .hexagonal ? tileSize * 2.0 : tileSize
    }

    /// Rendered pixel height for this tile's frame.
    private var tileRenderHeight: CGFloat {
        gridShape == .hexagonal ? tileSize * 1.7320508 : tileSize
    }

    // MARK: - Base Layer

    /// The bottom-most visual layer: texture image for hidden tiles, biome overlay
    /// for revealed tiles, or hazard fill for exploded/loss-reveal tiles.
    @ViewBuilder
    private var tileBaseLayer: some View {
        if isIlluminated {
            // Bioluminescence flash — deep teal background overrides everything
            tileBackground.fill(bioluminescentBackground)
        } else {
            switch tile.state {
            case .hidden:
                hiddenBaseLayer
            case .revealed:
                revealedBaseLayer
            case .exploded:
                // The tile the player clicked on loss — same amber/rust as revealed hazards
                tileBackground.fill(hazardLossColor)
            }
        }
    }

    /// Base layer for hidden tiles: texture image or game-over indicator fills.
    @ViewBuilder
    private var hiddenBaseLayer: some View {
        if gameOver && tile.isHazard && tile.hasConfirmedTag {
            // Correctly tagged hazard: green tint
            tileBackground.fill(Color.green.opacity(0.25))
        } else if gameOver && !tile.isHazard && tile.hasConfirmedTag {
            // Incorrectly tagged safe tile: red tint
            tileBackground.fill(Color.red.opacity(0.25))
        } else if tile.isLocked {
            // Locked tile (Biome 4 Ruins): desaturated grey texture at low opacity
            // so it reads as "inaccessible" rather than a normal hidden tile.
            // scaleEffect(1.35) zooms into the texture centre, eliminating edge
            // artifacts on both square and hex grids (hex fix included).
            Image(theme.tileTextureName)
                .resizable()
                .scaledToFill()
                .frame(width: tileRenderWidth, height: tileRenderHeight)
                .scaleEffect(1.35)
                .saturation(0.0)   // fully desaturate → grey/washed out
                .opacity(0.35)     // reduced from 0.50 for clear inactive signal
                .clipShape(tileBackground)
        } else {
            // Normal hidden tile: watercolour texture zoomed in 35 % so the
            // centre-of-interest fills the tile and no image-edge artifacts show
            // at the border of either rounded-rect or hex clip masks.
            Image(theme.tileTextureName)
                .resizable()
                .scaledToFill()
                .frame(width: tileRenderWidth, height: tileRenderHeight)
                .scaleEffect(1.35)
                .clipShape(tileBackground)
        }
    }

    /// Base layer for revealed tiles: biome-tinted semi-transparent dark overlay.
    ///
    /// Zero-signal ("blank") tiles use 0.60 opacity so they recede relative to
    /// numbered tiles, which use 0.75 opacity. Both values let a portion of the
    /// biome background image bleed through the tile shape.
    @ViewBuilder
    private var revealedBaseLayer: some View {
        if tile.isHazard {
            // Hazard revealed on board-reveal after loss: warm amber/rust fill
            tileBackground.fill(hazardLossColor)
        } else {
            let overlayOpacity: Double = isZeroSignalTile ? 0.60 : 0.75
            tileBackground.fill(theme.revealedOverlayColor.opacity(overlayOpacity))
        }
    }

    /// Warm amber/rust used for ALL hazard tiles after a loss — both the exploded
    /// tile the player clicked and the full board reveal. Specified as #c0603a.
    private var hazardLossColor: Color {
        Color(red: 0xC0/255, green: 0x60/255, blue: 0x3A/255)
    }

    /// True when this revealed tile will show a blank (zero-signal) face —
    /// used to apply the slightly-lower 0.60 opacity overlay so blank tiles
    /// recede behind numbered tiles.
    private var isZeroSignalTile: Bool {
        guard tile.isRevealed && !tile.isHazard else { return false }
        if tile.isSonar  { return false }  // sonar always renders content
        if tile.hasFog   { return false }  // fogged tiles show range
        if tile.isInverted, let trueSignal = tile.signal {
            // Inverted zero means ALL neighbours are safe — shown as blank
            return trueSignal == 0
        }
        return (tile.displayedSignal ?? 0) == 0
    }

    // MARK: - Border

    /// Border colour for non-illuminated tiles.
    private var tileBorderColor: Color {
        switch tile.state {
        case .hidden:
            // Confirmed tag (flagged): bright flag accent colour
            if tile.tagState == .confirmed {
                return theme.flagAccentColor
            }
            // Locked tile: white border matching the white padlock accent,
            // slightly visible over the desaturated grey texture.
            if tile.isLocked {
                return Color.white.opacity(0.35)
            }
            // Normal hidden: dark separator to define grid lines clearly
            return Color.black.opacity(0.35)

        case .revealed:
            // Hazard revealed: amber/rust border matching the fill
            if tile.isHazard {
                return hazardLossColor.opacity(0.6)
            }
            // Biome 1: fogged — retain cyan border so the mechanic is visually distinct
            if tile.hasFog {
                return Color.cyan.opacity(0.3)
            }
            // Biome 3: linked — pair-colour border preserved for clear visual pairing
            if let pairIdx = tile.linkedData?.pairIndex {
                return linkedPairBorder(pairIndex: pairIdx)
            }
            // Biome 5: inverted — muted teal border matching the seafoam background
            if tile.isInverted {
                return Color(red: 0.25, green: 0.65, blue: 0.58).opacity(0.55)
            }
            // Biome 6: sonar — deeper amber border matching the warm background
            if tile.isSonar {
                return Color(red: 0.72, green: 0.48, blue: 0.15).opacity(0.8)
            }
            // Standard revealed: dark separator matching the hidden-tile grid lines
            return Color.black.opacity(0.35)

        case .exploded:
            return hazardLossColor.opacity(0.6)
        }
    }

    /// Border line width: flagged tiles get a bold 2.5 pt; all other states
    /// use 1.5 pt so grid lines are clearly visible over biome textures.
    private var tileBorderWidth: CGFloat {
        if tile.state == .hidden && tile.tagState == .confirmed { return 2.5 }
        return 1.5
    }

    // MARK: - Content

    @ViewBuilder
    private var tileContent: some View {
        switch tile.state {
        case .hidden:
            hiddenContent

        case .revealed:
            // Biome 7: apply linear fade opacity — numbers fade at a constant rate.
            // gameOver bypasses the fade so the post-loss board reveal is always clear.
            revealedContent
                .opacity(revealedContentOpacity)

        case .exploded:
            hazardIcon(exploded: true)
        }
    }

    /// Content for a revealed safe tile — shows exact signal, fog range, or nothing.
    ///
    /// Uses `tile.displayedSignal` which routes through biome mechanics:
    /// - Linked tiles: shows partner's signal (not own)
    /// - All others: shows own true signal (or fog range for fogged tiles)
    @ViewBuilder
    private var revealedContent: some View {
        if tile.isHazard {
            // Board reveal after loss — hazard indicator in white/cream over the amber fill
            hazardIcon(exploded: false)
        } else if tile.hasFog, let fogData = tile.fogData {
            // Biome 1: fogged tile still shows range (fog not yet cleared).
            // Uses theme signalColor since this IS the signal for this tile.
            fogRangeText(min: fogData.signalMin, max: fogData.signalMax)
        } else if tile.isSonar, let total = tile.sonarData?.totalCount {
            // Biome 6: sonar tile shows the total hazard count across all four cardinal
            // sight lines. Heat-map colour scale retained — it communicates intensity, not count.
            ZStack {
                sonarDirectionMarks
                if total > 0 {
                    Text("\(total)")
                        .font(.system(size: tileSize * 0.45, weight: .bold, design: .rounded))
                        .foregroundColor(sonarSignalColor(for: total))
                        .shadow(color: Color.black.opacity(0.50), radius: 1, x: 0, y: 0)
                }
            }
        } else if tile.isInverted && !tile.isLinked,
                  let safeCount = tile.invertedData?.safeNeighborCount {
            // Biome 5: inverted tile shows safe-neighbor count with a reversed colour scale.
            // Reversed danger-direction scale retained for mechanic clarity.
            // signal == 0 means ALL neighbors are safe — show blank, mirroring normal zero.
            if tile.signal != 0 {
                Text("\(safeCount)")
                    .font(.system(size: tileSize * 0.5, weight: .bold, design: .rounded))
                    .foregroundColor(invertedSignalColor(for: safeCount))
                    .shadow(color: Color.black.opacity(0.50), radius: 1, x: 0, y: 0)
            }
        } else if let displayed = tile.displayedSignal, displayed > 0 {
            if tile.isLinked {
                // Linked tile: prefix "↔" so the player knows this number came from
                // the partner, not this tile's own neighbourhood.
                Text("↔\(displayed)")
                    .font(.system(size: tileSize * 0.38, weight: .bold, design: .rounded))
                    .foregroundColor(theme.signalColor)
                    .shadow(color: Color.black.opacity(0.50), radius: 1, x: 0, y: 0)
            } else {
                // Normal or fog-cleared tile: signal count as numeral.
                Text("\(displayed)")
                    .font(.system(size: tileSize * 0.5, weight: .bold, design: .rounded))
                    .foregroundColor(theme.signalColor)
                    .shadow(color: Color.black.opacity(0.50), radius: 1, x: 0, y: 0)
            }
        }
        // displayedSignal == 0 (not fogged, not inverted, not sonar): blank revealed tile
    }

    // MARK: - Bioluminescence Flash (Biome 2)

    /// Deep teal-blue used as the tile background during a conductor flash.
    private var bioluminescentBackground: Color {
        Color(red: 0.05, green: 0.42, blue: 0.55)
    }

    /// Content shown during a bioluminescent flash — true board state, theme-free.
    @ViewBuilder
    private var illuminatedContent: some View {
        if tile.isHazard {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: tileSize * 0.4))
                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.35))
        } else if let signal = tile.signal, signal > 0 {
            Text("\(signal)")
                .font(.system(size: tileSize * 0.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        // signal == 0 (clear tile) → blank; teal background speaks for itself
    }

    // MARK: - Fog Range (Biome 1)

    /// Fog range display: "2–4" style in biome signalColor with text shadow.
    private func fogRangeText(min: Int, max: Int) -> some View {
        Text("\(min)–\(max)")
            .font(.system(size: tileSize * 0.32, weight: .bold, design: .rounded))
            .foregroundColor(theme.signalColor)
            .shadow(color: Color.black.opacity(0.50), radius: 1, x: 0, y: 0)
    }

    // MARK: - Hidden Content

    /// Content rendered on hidden tiles.
    ///
    /// Locked tiles show a padlock + countdown (Biome 4 exception — the lock
    /// IS the information the player needs).
    ///
    /// All other hidden tiles show only tag markers:
    /// - `.none`      → nothing (the texture IS the tile face)
    /// - `.suspect`   → "?" in orange
    /// - `.confirmed` → "◆" diamond in flagAccentColor (replaces SF Symbol flag)
    @ViewBuilder
    private var hiddenContent: some View {
        if let locked = tile.lockedData {
            lockedTileContent(remaining: locked.remainingNeighborsNeeded)
        } else {
            switch tile.tagState {
            case .none:
                EmptyView()
            case .suspect:
                Text("?")
                    .font(.system(size: tileSize * 0.45, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            case .confirmed:
                // Dark landing pad + diamond in flagAccentColor.
                // The landing pad (black circle at 55 % opacity) creates a
                // consistent readable background over any biome texture so the
                // flag is unmistakable at a glance regardless of watercolour colour.
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: tileSize * 0.60, height: tileSize * 0.60)
                    Text("◆")
                        .font(.system(size: tileSize * 0.48, weight: .semibold))
                        .foregroundColor(theme.flagAccentColor)
                        .shadow(color: Color.black.opacity(0.60), radius: 2, x: 0, y: 0)
                }
            }
        }
    }

    // MARK: - Ruins Locked Tile Visual (Biome 4)

    /// Padlock icon + countdown shown on locked tiles.
    ///
    /// Both elements use `lockedAccentColor` with a text shadow so they stand
    /// out clearly over the desaturated grey texture.
    private func lockedTileContent(remaining: Int) -> some View {
        VStack(spacing: 1) {
            Image(systemName: "lock.fill")
                .font(.system(size: tileSize * 0.28, weight: .semibold))
                .foregroundColor(lockedAccentColor)
                .shadow(color: Color.black.opacity(0.40), radius: 1, x: 0, y: 0)
            Text("\(remaining)")
                .font(.system(size: tileSize * 0.30, weight: .bold, design: .rounded))
                .foregroundColor(lockedAccentColor)
                .shadow(color: Color.black.opacity(0.40), radius: 1, x: 0, y: 0)
        }
    }

    /// White — high contrast over the desaturated grey locked tile texture.
    /// The warm stone-gold used previously blended into the sandstone hue;
    /// white stands out clearly against any desaturated biome texture.
    private var lockedAccentColor: Color {
        Color.white.opacity(0.85)
    }

    // MARK: - Hazard Icon

    /// Hazard icon for exploded tile or board-reveal after loss.
    ///
    /// White/cream foreground ensures maximum contrast over the amber/rust fill
    /// (`hazardLossColor`) — red or orange would clash with the warm fill.
    private func hazardIcon(exploded: Bool) -> some View {
        Image(systemName: exploded ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: tileSize * 0.4))
            .foregroundColor(Color(red: 1.0, green: 0.95, blue: 0.85))  // warm cream
    }

    // MARK: - Linked Pair Visuals (Biome 3)

    /// Small indicator dot shown in the bottom-right corner of hidden linked tiles.
    ///
    /// Both tiles in a pair show this dot so the player knows a link relationship
    /// exists *before* either tile is revealed. Biome signalColor at 40 % opacity
    /// — visible but not distracting against the texture image.
    private var linkedDotIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Circle()
                    .fill(theme.signalColor.opacity(0.40))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(4)
    }

    /// Small chain-link badge shown in the bottom-left corner of revealed linked tiles.
    /// Indicates to the player that this tile shows its partner's signal, not its own.
    private var linkedBadge: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "link")
                    .font(.system(size: tileSize * 0.18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.85).opacity(0.8))
                Spacer()
            }
        }
        .padding(3)
    }

    /// Linked pair background tints — used for revealed linked tiles only.
    ///
    /// Five distinct swatches cycle with pairIndex % 5. Both tiles in a pair share
    /// the same index so they always receive matching colours after reveal.
    private func linkedPairBorder(pairIndex: Int) -> Color {
        switch pairIndex % 5 {
        case 0:  return Color(red: 0.10, green: 0.40, blue: 0.90).opacity(0.85)  // Blue
        case 1:  return Color(red: 0.88, green: 0.42, blue: 0.02).opacity(0.85)  // Orange
        case 2:  return Color(red: 0.08, green: 0.60, blue: 0.18).opacity(0.85)  // Green
        case 3:  return Color(red: 0.52, green: 0.15, blue: 0.85).opacity(0.85)  // Purple
        default: return Color(red: 0.82, green: 0.08, blue: 0.08).opacity(0.85)  // Red
        }
    }

    // MARK: - Inverted Signal Colour (Biome 5)
    //
    // Reversed emotional colour scale: low safe counts = danger (warm/red tones),
    // high safe counts = safety (cool/blue-green tones).
    //
    //   0,1 → Red   2 → Maroon   3 → Orange   4 → Purple
    //   5   → Teal  6 → Dark green            7 → Blue

    private func invertedSignalColor(for safeCount: Int) -> Color {
        switch safeCount {
        case 0, 1: return .red
        case 2:    return Color(red: 0.50, green: 0.00, blue: 0.00)   // Maroon
        case 3:    return Color(red: 0.88, green: 0.42, blue: 0.02)   // Orange
        case 4:    return .purple
        case 5:    return .teal
        case 6:    return Color(red: 0.00, green: 0.50, blue: 0.00)   // Dark green
        default:   return .blue   // 7 = safest non-blank
        }
    }

    // MARK: - Sonar Visuals (Biome 6)
    //
    // Revealed sonar tiles show:
    //   1. Four inward-pointing chevrons at the tile edges (N/S/E/W for square,
    //      N/NE/SE/S/SW/NW for hex) — the "crosshair" communicating line-of-sight.
    //   2. A central total count using a heat-map colour scale. Sonar totals can
    //      exceed 8 (spanning a full board edge), so ranges are used:
    //      0       → secondary (muted: sight lines all clear)
    //      1–3     → blue (low hazard presence)
    //      4–6     → dark green (moderate)
    //      7–10    → orange (significant)
    //      11+     → red (high hazard density)

    @ViewBuilder
    private var sonarDirectionMarks: some View {
        let markSize   = tileSize * 0.16
        let markOffset = tileSize * 0.33
        if gridShape == .hexagonal {
            let h: CGFloat = markOffset * 0.866_025   // markOffset × √3/2
            let q: CGFloat = markOffset * 0.5         // markOffset × ½
            ZStack {
                Image(systemName: "chevron.down")   // N  → rot 0°
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .rotationEffect(.degrees(0))
                    .offset(x: 0, y: -markOffset)
                Image(systemName: "chevron.down")   // NE → rot 120°
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .rotationEffect(.degrees(120))
                    .offset(x: h, y: -q)
                Image(systemName: "chevron.down")   // SE → rot 240°
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .rotationEffect(.degrees(240))
                    .offset(x: h, y: q)
                Image(systemName: "chevron.down")   // S  → rot 180°
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .rotationEffect(.degrees(180))
                    .offset(x: 0, y: markOffset)
                Image(systemName: "chevron.down")   // SW → rot −60°
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .rotationEffect(.degrees(-60))
                    .offset(x: -h, y: q)
                Image(systemName: "chevron.down")   // NW → rot 60°
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .rotationEffect(.degrees(60))
                    .offset(x: -h, y: -q)
            }
        } else {
            ZStack {
                Image(systemName: "chevron.down")   // N → points ↓ (inward)
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .offset(y: -markOffset)
                Image(systemName: "chevron.up")     // S → points ↑ (inward)
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .offset(y: markOffset)
                Image(systemName: "chevron.right")  // W → points → (inward)
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .offset(x: -markOffset)
                Image(systemName: "chevron.left")   // E → points ← (inward)
                    .font(.system(size: markSize, weight: .semibold))
                    .foregroundColor(sonarAccent)
                    .offset(x: markOffset)
            }
        }
    }

    /// Muted bronze for sonar direction-mark chevrons.
    private var sonarAccent: Color {
        Color(red: 0.62, green: 0.40, blue: 0.08).opacity(0.55)
    }

    /// Heat-map colour for the sonar's total directional hazard count.
    private func sonarSignalColor(for total: Int) -> Color {
        switch total {
        case 0:        return .secondary
        case 1...3:    return .blue
        case 4...6:    return Color(red: 0.0, green: 0.5, blue: 0.0)   // Dark green
        case 7...10:   return .orange
        default:       return .red   // 11+
        }
    }

    // MARK: - Quicksand Fade (Biome 7)

    /// Opacity for the revealed-tile number layer (linear fade).
    private var revealedContentOpacity: Double {
        guard quicksandFadeProgress > 0.0 && !gameOver else { return 1.0 }
        return 1.0 - quicksandFadeProgress
    }

    /// Tint colour that bleeds into the overlay as the number fades.
    ///
    /// Updated to use biome theme colours where applicable so the colour memory
    /// matches what the player actually saw on that tile.
    private var quicksandTintColor: Color {
        guard tile.isRevealed, !tile.isHazard, !tile.isLocked else { return .clear }

        if tile.isSonar, let total = tile.sonarData?.totalCount {
            return sonarSignalColor(for: total)
        }
        if tile.isInverted && !tile.isLinked,
           let safeCount = tile.invertedData?.safeNeighborCount,
           let trueSignal = tile.signal, trueSignal != 0 {
            return invertedSignalColor(for: safeCount)
        }
        // Fog range, linked, normal, or zero-signal: use the biome signalColor
        // so the colour echo matches what the tile actually displayed.
        return theme.signalColor
    }
}
