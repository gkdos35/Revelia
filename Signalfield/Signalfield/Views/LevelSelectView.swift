// Signalfield/Views/LevelSelectView.swift
//
// Campaign Task 4 — Level Select Screen (Watercolor Reskin).
//
// Each biome displays its hand-painted watercolor background image full-bleed.
// Level circles are placed at hand-placed normalized coordinates defined in
// BiomeLevelLayout.swift — one position per level, visually matched to the painted path.
//
// Circle states
//   Locked    — faint ghost circle (~30% opacity), no number, no interaction
//   Unlocked  — white circle with animated glow + pulse; shows level number; tappable
//   Completed — bronze / silver / gold fill by star count; stars below; tappable
//
// Tapping an unlocked or completed node expands a parchment-toned info card.
// Tapping elsewhere (or the same node again) collapses the card.
// Only one card is open at a time.

import SwiftUI

// MARK: - LevelSelectView

struct LevelSelectView: View {
    @EnvironmentObject private var progressStore: ProgressStore

    let biome:  BiomeInfo
    let onBack: () -> Void
    let onPlay: (LevelSpec) -> Void

    /// Index of the currently expanded info card, or nil.
    @State private var expandedIndex: Int? = nil

    // MARK: Layout constants

    private let nodeRadius:  CGFloat = 24       // half of the 48 pt circle diameter
    private let cardWidth:   CGFloat = 260
    private let cardHeight:  CGFloat = 290      // approx; used for clamping only

    // MARK: Derived

    private var levels: [LevelSpec] { biome.levels }

    private var totalStarsEarned: Int {
        levels.reduce(0) { $0 + progressStore.bestStars(for: $1.id) }
    }

    /// Xcode asset name for this biome's background image.
    private var imageName: String {
        BiomeLevelLayout.imageName(for: biome.id)
    }

    /// Edge background color matching the dominant hue of the biome image borders.
    private var bgColor: Color {
        let c = BiomeLevelLayout.edgeColor(for: biome.id)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b)
    }

    // MARK: Body

    var body: some View {
        // Header sits above the GeometryReader in a VStack.  Inside the GeometryReader,
        // the image is rendered at its full natural height (canvasWidth × 1.5) and
        // wrapped in a ScrollView so the entire painting is visible.  Level icon positions
        // are stored as image-fractions in BiomeLevelLayout, so they are passed imageSize
        // (not geo.size) to place icons correctly anywhere in the scrollable content.
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                // The background images are 1024×1536 (1:1.5 aspect ratio).  Render the
                // image at the full canvas width with its natural proportionate height so
                // the entire painting is visible when the player scrolls.  Icon positions
                // are stored as image-fractions (see BiomeLevelLayout), so passing
                // imageSize to levelPositions() maps them correctly into scroll-space.
                let canvasWidth = geo.size.width
                let imageHeight = canvasWidth * 1.5
                let imageSize   = CGSize(width: canvasWidth, height: imageHeight)
                let positions   = BiomeLevelLayout.levelPositions(
                    for: biome.id,
                    in: imageSize
                )

                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // 1. Edge color — fills any gap if image dimensions vary slightly
                        bgColor
                            .frame(width: canvasWidth, height: imageHeight)

                        // 2. Watercolor biome image — full natural height, no crop
                        Image(imageName)
                            .resizable()
                            .frame(width: canvasWidth, height: imageHeight)
                            .allowsHitTesting(false)

                        // 3. Full-content dismiss tap (behind nodes)
                        Color.clear
                            .frame(width: canvasWidth, height: imageHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    expandedIndex = nil
                                }
                            }

                        // 4. Level nodes
                        ForEach(levels.indices, id: \.self) { i in
                            LevelNodeView(
                                number:      i + 1,
                                isLocked:    !progressStore.isUnlocked(levels[i]),
                                isCompleted: progressStore.isCompleted(levels[i].id),
                                stars:       progressStore.bestStars(for: levels[i].id),
                                isExpanded:  expandedIndex == i,
                                isHex:       biome.id >= 9
                            ) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    expandedIndex = (expandedIndex == i) ? nil : i
                                }
                            }
                            .position(positions[i])
                        }

                        // 5. Info card (topmost layer, one at a time).
                        // cardPlacement receives imageSize so clamping is in scroll-space;
                        // the card scrolls with the content just like the level nodes.
                        if let i = expandedIndex {
                            let placement = cardPlacement(nodePos: positions[i], in: imageSize)
                            LevelInfoCard(
                                level:           levels[i],
                                stars:           progressStore.bestStars(for: levels[i].id),
                                bestScore:       progressStore.bestScore(for: levels[i].id),
                                bestTime:        progressStore.bestTime(for: levels[i].id),
                                isCompleted:     progressStore.isCompleted(levels[i].id),
                                pointerEdge:     placement.pointerEdge,
                                pointerFraction: placement.pointerFraction,
                                onPlay: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        expandedIndex = nil
                                    }
                                    onPlay(levels[i])
                                }
                            )
                            .frame(width: cardWidth)
                            .position(placement.center)
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                            .zIndex(10)
                        }
                    }
                    .frame(width: canvasWidth, height: imageHeight)
                }
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: expandedIndex)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            // Back button
            Button(action: onBack) {
                Label("Biomes", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            // Divider tinted for dark/light biomes
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 10)

            // Biome icon + name
            Image(systemName: biome.icon)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.trailing, 5)
            Text(biome.name)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            // Star tally
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text("\(totalStarsEarned) / \(biome.totalStarsPossible)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Card placement

    private struct CardPlacement {
        let center:          CGPoint
        let pointerEdge:     Edge      // which edge of the card the pointer lives on
        let pointerFraction: CGFloat   // 0–1, where along that edge the pointer tip sits
    }

    /// Computes where to place the info card and which edge its pointer notch appears on.
    ///
    /// Priority: horizontal placement (card to the left or right of the node) is preferred
    /// because it doesn't obscure the path trail above/below. Falls back to vertical
    /// (above then below) when there isn't enough horizontal room.
    private func cardPlacement(nodePos: CGPoint, in size: CGSize) -> CardPlacement {
        let gap       = nodeRadius + 10   // gap between node edge and card edge
        let halfW     = cardWidth  / 2
        let halfH     = cardHeight / 2
        let margin: CGFloat = 10          // minimum distance from window edge

        // ── Attempt horizontal placement ─────────────────────────────────────

        // Right side: card's left edge is gap away from node's right edge
        let rightCenterX = nodePos.x + gap + halfW
        if rightCenterX + halfW + margin <= size.width {
            let cy = (nodePos.y).clamped(to: halfH + margin ... size.height - halfH - margin)
            let frac = ((nodePos.y - (cy - halfH)) / cardHeight).clamped(to: 0.2...0.8)
            return CardPlacement(
                center:          CGPoint(x: rightCenterX, y: cy),
                pointerEdge:     .leading,
                pointerFraction: frac
            )
        }

        // Left side: card's right edge is gap away from node's left edge
        let leftCenterX = nodePos.x - gap - halfW
        if leftCenterX - halfW - margin >= 0 {
            let cy = (nodePos.y).clamped(to: halfH + margin ... size.height - halfH - margin)
            let frac = ((nodePos.y - (cy - halfH)) / cardHeight).clamped(to: 0.2...0.8)
            return CardPlacement(
                center:          CGPoint(x: leftCenterX, y: cy),
                pointerEdge:     .trailing,
                pointerFraction: frac
            )
        }

        // ── Fall back to vertical placement ──────────────────────────────────

        let cx = (nodePos.x).clamped(to: halfW + margin ... size.width - halfW - margin)

        // Above the node
        let aboveCenterY = nodePos.y - gap - halfH
        if aboveCenterY - halfH - margin >= 0 {
            let frac = ((nodePos.x - (cx - halfW)) / cardWidth).clamped(to: 0.2...0.8)
            return CardPlacement(
                center:          CGPoint(x: cx, y: aboveCenterY),
                pointerEdge:     .bottom,
                pointerFraction: frac
            )
        }

        // Below the node (last resort)
        let belowCenterY = nodePos.y + gap + halfH
        let cy = belowCenterY.clamped(to: halfH + margin ... size.height - halfH - margin)
        let frac = ((nodePos.x - (cx - halfW)) / cardWidth).clamped(to: 0.2...0.8)
        return CardPlacement(
            center:          CGPoint(x: cx, y: cy),
            pointerEdge:     .top,
            pointerFraction: frac
        )
    }

}

// MARK: - Comparable clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - LevelNodeView

/// A single node on the biome trail.
///
/// **Locked** — ghost shape, no number, no interaction.
/// **Unlocked** — white shape with animated outer glow pulse, shows level number.
/// **Completed** — bronze/silver/gold fill; level number in upper portion,
///   star indicators in lower portion, both inside the marker shape.
///
/// Shape is a circle for square biomes and a flat-top hexagon for hex biomes
/// (`isHex: true`), driven by the parent's `biome.id >= 9` check.
/// Hex markers are ~17 % larger (56 pt vs 48 pt) so both number and stars
/// fit comfortably inside the narrower hexagonal interior.
private struct LevelNodeView: View {
    let number:      Int
    let isLocked:    Bool
    let isCompleted: Bool
    let stars:       Int
    let isExpanded:  Bool
    /// True for hex biomes (id 9–17) — renders a hexagonal marker instead of circle.
    var isHex:       Bool = false
    let onTap:       () -> Void

    @State private var pulsing = false

    /// Shape used for the marker body and borders.  Switching on isHex gives
    /// hex markers their distinctive shape while reusing all the same styling.
    /// Square markers use cornerRadius 12 (≈25 % of the 48 pt marker diameter)
    /// for a soft rounded-square look consistent with the watercolor aesthetic.
    /// Hex markers ignore cornerRadius — their path is always the flat-top hexagon.
    private var nodeShape: TileBackgroundShape {
        TileBackgroundShape(isHex: isHex, cornerRadius: isHex ? 3 : 12)
    }

    // MARK: Size constants
    //
    // Hex markers are enlarged ~17 % so the hexagonal interior (height ≈ R×√3)
    // can comfortably hold a two-line layout (number + stars row) without crowding.
    //   Square: 48 pt marker  →  ~32 pt usable interior  →  number 14 + stars 6.5
    //   Hex:    56 pt marker  →  ~38 pt usable interior  →  number 15 + stars 7.5

    private var markerSize: CGFloat { isHex ? 56 : 48 }  // main filled shape
    private var ringSize:   CGFloat { isHex ? 70 : 60 }  // expanded-selection ring
    private var outerSize:  CGFloat { isHex ? 82 : 70 }  // glow + button frame
    private var numberSize: CGFloat { isHex ? 15 : 14 }  // number label font pt
    private var starSize:   CGFloat { isHex ? 7.5 : 6.5 }// star icon font pt

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer glow — only for unlocked + not completed
                if !isLocked && !isCompleted {
                    Circle()
                        .fill(Color.white.opacity(0.30))
                        .frame(width: outerSize, height: outerSize)
                        .blur(radius: 12)
                        .scaleEffect(pulsing ? 1.28 : 0.80)
                        .opacity(pulsing ? 1.0 : 0.35)
                        .animation(
                            .easeInOut(duration: 1.8)
                                .repeatForever(autoreverses: true),
                            value: pulsing
                        )
                }

                // Selection ring when card is expanded
                if isExpanded && !isLocked {
                    nodeShape
                        .strokeBorder(ringColor, lineWidth: 2.5)
                        .frame(width: ringSize, height: ringSize)
                }

                // Main marker body: texture (completed) or flat fill, + soft bright border.
                // Completed markers show the watercolor slate-blue texture, scaled to 130 %
                // so the painted white border around the source image is cropped by
                // clipShape — same technique used for hidden tile textures in TileView.
                // White border at ~55 % opacity reads against both light and dark
                // biome backgrounds without looking harsh.
                ZStack {
                    if isCompleted {
                        Image("LevelIconBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: markerSize, height: markerSize)
                            .scaleEffect(1.30)
                            .clipShape(nodeShape)
                    } else {
                        nodeShape.fill(circleFill)
                    }
                    nodeShape.strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                }
                .frame(width: markerSize, height: markerSize)
                .scaleEffect(pulsing && !isLocked && !isCompleted ? 1.07 : 1.0)
                .animation(
                    .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true),
                    value: pulsing
                )
                .shadow(
                    color: (!isLocked && isExpanded) ? ringColor.opacity(0.45) : .clear,
                    radius: 10
                )

                // Content: number (upper) + stars (lower) inside the marker.
                // Locked nodes show nothing; unlocked-not-completed show number only.
                if !isLocked {
                    VStack(spacing: 2) {
                        Text("\(number)")
                            .font(.system(size: numberSize, weight: .bold, design: .rounded))
                            .foregroundStyle(isCompleted ? .white : Color(.sRGB, red: 0.12, green: 0.12, blue: 0.12))
                            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0)

                        if isCompleted {
                            HStack(spacing: 1) {
                                ForEach(1...3, id: \.self) { s in
                                    Image(systemName: s <= stars ? "star.fill" : "star")
                                        .font(.system(size: starSize, weight: .semibold))
                                        .foregroundStyle(
                                            s <= stars
                                                ? Color.yellow
                                                : Color.white.opacity(0.40)
                                        )
                                }
                            }
                            // Strong shadow gives star icons a visible dark outline
                            // so they read against both light and dark biome backgrounds.
                            .shadow(color: .black.opacity(0.75), radius: 1, x: 0, y: 0)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        // Consistent outer frame for all node states; .position() centres on this.
        .frame(width: outerSize, height: outerSize)
        .onAppear {
            guard !isLocked && !isCompleted else { return }
            pulsing = true
        }
        .onChange(of: isCompleted) { _, newValue in
            if newValue { pulsing = false }
        }
    }

    // MARK: Helpers

    private var circleFill: Color {
        if isLocked    { return Color.white.opacity(0.28) }
        // Completed: deep slate blue retained as fallback if "LevelIconBackground"
        // asset fails to load. In normal use the texture image is rendered instead
        // (see the isCompleted branch in the marker body ZStack above).
        if isCompleted { return Color(red: 0x2A/255, green: 0x3A/255, blue: 0x4A/255) }
        return Color.white
    }

    private var ringColor: Color {
        isCompleted ? starColor : Color.white
    }

    private var starColor: Color {
        switch stars {
        case 3: return Color(.sRGB, red: 1.000, green: 0.843, blue: 0.000) // gold   #FFD700
        case 2: return Color(.sRGB, red: 0.753, green: 0.753, blue: 0.753) // silver #C0C0C0
        default: return Color(.sRGB, red: 0.804, green: 0.498, blue: 0.196) // bronze #CD7F32
        }
    }
}

// MARK: - CardWithNotchShape

/// A rounded rectangle with a triangular pointer notch on one edge.
///
/// The notch tip extends `notchDepth` points BEYOND the rect's boundary,
/// so the rendered shape will visually overflow the SwiftUI frame — this is
/// intentional.  The tip points toward the level node, giving the card a
/// tooltip-style affordance that clearly indicates which level it describes.
///
/// The path is traced clockwise from the top-left corner arc start point.
/// The notch is inserted at the correct moment during traversal of the
/// specified edge so the overall winding is always consistent.
private struct CardWithNotchShape: Shape {

    /// Which edge of the card the pointer notch lives on.
    var pointerEdge:     Edge

    /// 0–1 fraction along the chosen edge where the notch tip appears.
    /// 0 = leading end of the edge, 1 = trailing end.
    /// Callers clamp this to 0.2...0.8 to avoid the corner arcs.
    var pointerFraction: CGFloat

    var cornerRadius:  CGFloat = 12
    var notchDepth:    CGFloat = 12   // how far the tip extends beyond the edge
    var notchHalfBase: CGFloat = 8    // half-width of the triangle base

    func path(in rect: CGRect) -> Path {
        let r  = min(cornerRadius, rect.width / 2, rect.height / 2)
        let nd = notchDepth
        let nh = notchHalfBase

        let minX = rect.minX, maxX = rect.maxX
        let minY = rect.minY, maxY = rect.maxY
        let w    = rect.width, h   = rect.height

        var p = Path()

        // ── Start: top-left arc approach point ───────────────────────────────
        p.move(to: CGPoint(x: minX + r, y: minY))

        // ── Top edge (left → right) ───────────────────────────────────────────
        if pointerEdge == .top {
            let tx = minX + pointerFraction * w
            p.addLine(to: CGPoint(x: tx - nh, y: minY))
            p.addLine(to: CGPoint(x: tx,      y: minY - nd))  // tip (above card)
            p.addLine(to: CGPoint(x: tx + nh, y: minY))
        }
        p.addLine(to: CGPoint(x: maxX - r, y: minY))

        // top-right arc  (-90° → 0°)
        p.addArc(center: CGPoint(x: maxX - r, y: minY + r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        // ── Right edge (top → bottom) ─────────────────────────────────────────
        if pointerEdge == .trailing {
            let ty = minY + pointerFraction * h
            p.addLine(to: CGPoint(x: maxX,      y: ty - nh))
            p.addLine(to: CGPoint(x: maxX + nd, y: ty))       // tip (right of card)
            p.addLine(to: CGPoint(x: maxX,      y: ty + nh))
        }
        p.addLine(to: CGPoint(x: maxX, y: maxY - r))

        // bottom-right arc  (0° → 90°)
        p.addArc(center: CGPoint(x: maxX - r, y: maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

        // ── Bottom edge (right → left) ────────────────────────────────────────
        if pointerEdge == .bottom {
            let tx = minX + pointerFraction * w
            p.addLine(to: CGPoint(x: tx + nh, y: maxY))
            p.addLine(to: CGPoint(x: tx,      y: maxY + nd))  // tip (below card)
            p.addLine(to: CGPoint(x: tx - nh, y: maxY))
        }
        p.addLine(to: CGPoint(x: minX + r, y: maxY))

        // bottom-left arc  (90° → 180°)
        p.addArc(center: CGPoint(x: minX + r, y: maxY - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // ── Left edge (bottom → top) ──────────────────────────────────────────
        if pointerEdge == .leading {
            let ty = minY + pointerFraction * h
            p.addLine(to: CGPoint(x: minX,      y: ty + nh))
            p.addLine(to: CGPoint(x: minX - nd, y: ty))       // tip (left of card)
            p.addLine(to: CGPoint(x: minX,      y: ty - nh))
        }
        p.addLine(to: CGPoint(x: minX, y: minY + r))

        // top-left arc  (180° → 270°)
        p.addArc(center: CGPoint(x: minX + r, y: minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        p.closeSubpath()
        return p
    }
}

// MARK: - LevelInfoCard

/// Parchment field-note card shown when a level node is tapped.
///
/// A triangular notch on one edge points toward the selected node.
/// Background: the `ParchmentCard` texture image, overscaled 110 % and
/// clipped to the notch shape for a torn-paper feel.
/// Border: dark sepia stroke at 50 % opacity.
/// Drop shadow follows the notch shape.
///
/// Content rows (top → bottom):
///   1. Hero level number ("Level 7" or "Level 82 — Hex")
///   2. Star row if completed; "Not yet played" if first visit
///   3. Two-column best score / best time stats
///   4. Par score and par time target
///   5. Biome name (in biome signal colour) + mechanic hint
///   6. Full-width Play button in biome play-button colour
private struct LevelInfoCard: View {

    let level:           LevelSpec
    let stars:           Int
    let bestScore:       Int
    let bestTime:        Double?
    let isCompleted:     Bool
    let pointerEdge:     Edge
    let pointerFraction: CGFloat
    let onPlay:          () -> Void

    // MARK: Palette

    private let inkPrimary   = Color(.sRGB, red: 0.18,  green: 0.12,  blue: 0.06)
    private let inkSecondary = Color(.sRGB, red: 0.42,  green: 0.32,  blue: 0.20)
    private let sepiaStroke  = Color(.sRGB, red: 0.42,  green: 0.35,  blue: 0.24)
    // #6b5b3e @ 50 %
    private let borderColor  = Color(.sRGB, red: 0.420, green: 0.357, blue: 0.243).opacity(0.50)
    // Parchment fallback (shown if texture asset is missing)
    private let parchmentFill = Color(.sRGB, red: 0.953, green: 0.910, blue: 0.843)

    // MARK: Theme helpers

    private var theme: BiomeTheme { BiomeTheme.theme(for: level.biomeId) }

    private var notchShape: CardWithNotchShape {
        CardWithNotchShape(pointerEdge: pointerEdge, pointerFraction: pointerFraction)
    }

    // MARK: Par helpers

    private var parScore: Int {
        max(0, 100_000 - level.parTimeSeconds * 20 + 15_000)
    }

    private var parTimeFormatted: String {
        let t = level.parTimeSeconds
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    // MARK: Star tier colour

    private var starTierColor: Color {
        switch stars {
        case 3:  return Color(.sRGB, red: 1.000, green: 0.843, blue: 0.000) // gold   #FFD700
        case 2:  return Color(.sRGB, red: 0.753, green: 0.753, blue: 0.753) // silver #C0C0C0
        default: return Color(.sRGB, red: 0.804, green: 0.498, blue: 0.196) // bronze #CD7F32
        }
    }

    // MARK: Static formatter

    private static let scoreFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle    = .decimal
        f.groupingSize   = 3
        return f
    }()

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Hero: level number ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Level \(level.absoluteLevelNumber)")
                        .font(.system(size: 21, weight: .bold, design: .serif))
                        .foregroundStyle(inkPrimary)
                    if level.gridShape == .hexagonal {
                        Text("· Hex")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(inkSecondary)
                    }
                }

                // Star row or "not yet played"
                if isCompleted {
                    HStack(spacing: 4) {
                        ForEach(1...3, id: \.self) { s in
                            Image(systemName: s <= stars ? "star.fill" : "star")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(
                                    s <= stars
                                        ? starTierColor
                                        : inkSecondary.opacity(0.28)
                                )
                                // Dark outline: tight shadow at zero offset gives
                                // ~1 pt stroke that reads against warm parchment.
                                .shadow(color: Color(.sRGB, red: 0.29, green: 0.23, blue: 0.16).opacity(0.65),
                                        radius: 0.8, x: 0, y: 0)
                        }
                    }
                } else {
                    Text("Not yet played")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(inkSecondary.opacity(0.70))
                }
            }
            .padding(.bottom, 10)

            sepiaDivider

            // ── Best score / time columns ───────────────────────────────────
            HStack(alignment: .top, spacing: 0) {
                statColumn(
                    label: "BEST",
                    value: isCompleted ? formattedScore(bestScore) : "—"
                )
                sepiaStroke.opacity(0.30)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, 10)
                statColumn(
                    label: "TIME",
                    value: isCompleted ? formattedTime(bestTime) : "—"
                )
                Spacer()
            }
            .padding(.vertical, 8)

            sepiaDivider

            // ── Par targets ─────────────────────────────────────────────────
            HStack(spacing: 5) {
                Text("Par")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(inkSecondary)
                Text("\(formattedScore(parScore))  ·  \(parTimeFormatted)")
                    .font(.system(size: 11, design: .serif).monospacedDigit())
                    .foregroundStyle(inkSecondary.opacity(0.85))
            }
            .padding(.vertical, 7)

            // ── Mechanic indicator ──────────────────────────────────────────
            // Hidden for Training Range (empty hint) — no divider or row rendered.
            // For The Delta, shows a comma-separated list of active mechanics.
            // For all other biomes, shows the biome's single mechanic description.
            if !level.mechanicHint.isEmpty {
                sepiaDivider

                Text(level.mechanicHint)
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                    .padding(.vertical, 7)
            }

            // ── Play button ─────────────────────────────────────────────────
            Button(action: onPlay) {
                Text("Play")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.playButtonColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        // ── Parchment texture background + border ────────────────────────────
        // All three layers share one ZStack so they get the exact same rect
        // from a single layout pass — this prevents the corner-gap misalignment
        // that occurs when .background{} and a separate .overlay{} compute the
        // shape's rect independently.
        .background {
            ZStack {
                // Fallback solid fill — also serves as the shadow-casting layer
                notchShape
                    .fill(parchmentFill)
                    .shadow(color: .black.opacity(0.17), radius: 5, x: 0, y: 3)
                // Texture overscaled 110 % so edges bleed slightly into the
                // border, preventing a hard white rectangle look
                Image("ParchmentCard")
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.10)
                    .clipShape(notchShape)
                // Border drawn last so it sits on top of the texture — same
                // rect as everything else, so corners always meet cleanly
                notchShape
                    .stroke(borderColor, lineWidth: 1.5)
            }
        }
    }

    // MARK: Sub-views

    private var sepiaDivider: some View {
        Rectangle()
            .fill(sepiaStroke.opacity(0.38))
            .frame(height: 1)
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .serif))
                .foregroundStyle(inkSecondary.opacity(0.70))
                .kerning(0.8)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .serif).monospacedDigit())
                .foregroundStyle(inkPrimary)
        }
    }

    // MARK: Formatters

    private func formattedScore(_ score: Int) -> String {
        Self.scoreFormatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    private func formattedTime(_ t: Double?) -> String {
        guard let t else { return "—" }
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Previews

#Preview("Level Select — Training Range") {
    LevelSelectView(
        biome:  BiomeInfo.squareBiomes[0],
        onBack: { },
        onPlay: { _ in }
    )
    .environmentObject(ProgressStore())
    .frame(width: 600, height: 700)
}

#Preview("Level Select — The Delta (12 levels)") {
    LevelSelectView(
        biome:  BiomeInfo.squareBiomes[8],
        onBack: { },
        onPlay: { _ in }
    )
    .environmentObject(ProgressStore())
    .frame(width: 600, height: 700)
}

#Preview("Level Select — Frozen Mirrors (hex)") {
    LevelSelectView(
        biome:  BiomeInfo.hexBiomes[3],
        onBack: { },
        onPlay: { _ in }
    )
    .environmentObject(ProgressStore())
    .frame(width: 600, height: 700)
}
