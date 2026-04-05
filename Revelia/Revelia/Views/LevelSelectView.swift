// Revelia/Views/LevelSelectView.swift
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

import AppKit
import SwiftUI

// MARK: - LevelSelectView

struct LevelSelectView: View {
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var leaderboardStore: LeaderboardStore

    let biome:  BiomeInfo
    let onBack: () -> Void
    let onPlay: (LevelSpec) -> Void
    let onShowHighScores: (LevelSpec) -> Void

    /// Index of the currently expanded info card, or nil.
    @State private var expandedIndex: Int? = nil
    @State private var layoutEditMode = false
    @State private var editedNormalizedPositions: [CGPoint]? = nil
    @State private var copiedLayoutText = false

    // MARK: Layout constants

    private let nodeRadius:  CGFloat = 24       // half of the 48 pt circle diameter
    private let cardWidth:   CGFloat = 260
    private let cardHeight:  CGFloat = 330      // approx; used for clamping only
    // MARK: Derived

    private var levels: [LevelSpec] { biome.levels }

    private var baseNormalizedPositions: [CGPoint] {
        BiomeLevelLayout.normalizedPositions(for: biome.id)
    }

    private var activeNormalizedPositions: [CGPoint] {
        editedNormalizedPositions ?? baseNormalizedPositions
    }

    private var totalStarsEarned: Int {
        levels.reduce(0) { $0 + progressStore.bestStars(for: $1.id) }
    }

    /// Xcode asset name for this biome's background image.
    private var imageName: String {
        BiomeLevelLayout.imageName(for: biome.id)
    }

    /// Source aspect ratio for this biome's painted level-select artwork.
    /// Assets are not uniform across the set, so using one shared ratio leaves
    /// some biomes under-filled with unnecessary empty margins.
    private var artworkAspectRatio: CGFloat {
        switch biome.id % 9 {
        case 2, 4:
            return 1.0            // 1024 x 1024
        case 3, 6, 7:
            return 864.0 / 1184.0 // portrait artwork
        default:
            return 1024.0 / 1536.0
        }
    }

    /// Edge background color matching the dominant hue of the biome image borders.
    private var bgColor: Color {
        let c = BiomeLevelLayout.edgeColor(for: biome.id)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b)
    }

    // MARK: Body

    var body: some View {
        // Header sits above a single fitted art canvas. The watercolor image keeps its
        // source aspect ratio and shrinks to remain fully visible inside the window.
        // Nodes and the info card are positioned relative to that visible image rect.
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                let imageSize = fittedArtworkSize(in: geo.size)
                let positions = activeNormalizedPositions.map {
                    CGPoint(x: $0.x * imageSize.width, y: $0.y * imageSize.height)
                }

                ZStack {
                    bgColor
                        .ignoresSafeArea(edges: .bottom)

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                expandedIndex = nil
                            }
                        }

                    ZStack(alignment: .topLeading) {
                        bgColor
                            .frame(width: imageSize.width, height: imageSize.height)

                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize.width, height: imageSize.height)
                            .allowsHitTesting(false)

                        ForEach(levels.indices, id: \.self) { i in
                            if layoutEditMode {
                                LevelNodeView(
                                    number:      i + 1,
                                    isLocked:    !progressStore.isUnlocked(levels[i]),
                                    isCompleted: progressStore.isCompleted(levels[i].id),
                                    stars:       progressStore.bestStars(for: levels[i].id),
                                    isExpanded:  false,
                                    isHex:       biome.id >= 9,
                                    showsDebugIndex: true
                                ) { }
                                .position(positions[i])
                                .gesture(dragGesture(for: i, in: imageSize))
                            } else {
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
                        }

                        if let i = expandedIndex, !layoutEditMode {
                            let placement = cardPlacement(nodePos: positions[i], in: imageSize)
                            LevelInfoCard(
                                level:           levels[i],
                                stars:           progressStore.bestStars(for: levels[i].id),
                                bestEntry:       leaderboardStore.bestEntry(for: levels[i].id),
                                isCompleted:     progressStore.isCompleted(levels[i].id),
                                hasLeaderboardEntries: leaderboardStore.hasEntries(for: levels[i].id),
                                pointerEdge:     placement.pointerEdge,
                                pointerFraction: placement.pointerFraction,
                                onPlay: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        expandedIndex = nil
                                    }
                                    onPlay(levels[i])
                                },
                                onShowHighScores: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        expandedIndex = nil
                                    }
                                    onShowHighScores(levels[i])
                                }
                            )
                            .frame(width: min(cardWidth, max(imageSize.width - 20, 180)))
                            .position(placement.center)
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                            .zIndex(10)
                        }

                        if layoutEditMode {
                            layoutEditorOverlay
                                .padding(12)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .zIndex(20)
                        }
                    }
                    .frame(width: imageSize.width, height: imageSize.height)
                }
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: expandedIndex)
        .background(layoutShortcutButtons)
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
        let margin: CGFloat = 10          // minimum distance from window edge
        let effectiveCardWidth = min(cardWidth, max(size.width - (margin * 2), 180))
        let halfW     = effectiveCardWidth / 2
        let halfH     = cardHeight / 2

        // ── Attempt horizontal placement ─────────────────────────────────────

        // Right side: card's left edge is gap away from node's right edge
        let rightCenterX = nodePos.x + gap + halfW
        if rightCenterX + halfW + margin <= size.width {
            let cy = clampedCenter(nodePos.y, half: halfH, limit: size.height, margin: margin)
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
            let cy = clampedCenter(nodePos.y, half: halfH, limit: size.height, margin: margin)
            let frac = ((nodePos.y - (cy - halfH)) / cardHeight).clamped(to: 0.2...0.8)
            return CardPlacement(
                center:          CGPoint(x: leftCenterX, y: cy),
                pointerEdge:     .trailing,
                pointerFraction: frac
            )
        }

        // ── Fall back to vertical placement ──────────────────────────────────

        let cx = clampedCenter(nodePos.x, half: halfW, limit: size.width, margin: margin)

        // Above the node
        let aboveCenterY = nodePos.y - gap - halfH
        if aboveCenterY - halfH - margin >= 0 {
            let frac = ((nodePos.x - (cx - halfW)) / effectiveCardWidth).clamped(to: 0.2...0.8)
            return CardPlacement(
                center:          CGPoint(x: cx, y: aboveCenterY),
                pointerEdge:     .bottom,
                pointerFraction: frac
            )
        }

        // Below the node (last resort)
        let belowCenterY = nodePos.y + gap + halfH
        let cy = clampedCenter(belowCenterY, half: halfH, limit: size.height, margin: margin)
        let frac = ((nodePos.x - (cx - halfW)) / effectiveCardWidth).clamped(to: 0.2...0.8)
        return CardPlacement(
            center:          CGPoint(x: cx, y: cy),
            pointerEdge:     .top,
            pointerFraction: frac
        )
    }

    private func fittedArtworkSize(in availableSize: CGSize) -> CGSize {
        guard availableSize.width > 0, availableSize.height > 0 else {
            return .zero
        }

        let widthLimitedHeight = availableSize.width / artworkAspectRatio
        if widthLimitedHeight <= availableSize.height {
            return CGSize(width: availableSize.width, height: widthLimitedHeight)
        }

        return CGSize(width: availableSize.height * artworkAspectRatio, height: availableSize.height)
    }

    private func clampedCenter(
        _ preferred: CGFloat,
        half: CGFloat,
        limit: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        let minimum = half + margin
        let maximum = limit - half - margin
        guard minimum <= maximum else { return limit / 2 }
        return preferred.clamped(to: minimum ... maximum)
    }

    private func dragGesture(for index: Int, in imageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard imageSize.width > 0, imageSize.height > 0 else { return }
                var next = activeNormalizedPositions
                next[index] = CGPoint(
                    x: (value.location.x / imageSize.width).clamped(to: 0...1),
                    y: (value.location.y / imageSize.height).clamped(to: 0...1)
                )
                editedNormalizedPositions = next
            }
    }

    private var layoutEditorOverlay: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("Layout Edit Mode")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.sRGB, red: 0.18, green: 0.12, blue: 0.06))

            Text("Drag nodes. `Copy` exports the current biome array for `BiomeLevelLayout.swift`.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(.sRGB, red: 0.28, green: 0.20, blue: 0.12).opacity(0.88))
                .frame(width: 240, alignment: .trailing)
                .multilineTextAlignment(.trailing)

            HStack(spacing: 8) {
                Button("Reset") {
                    editedNormalizedPositions = nil
                    copiedLayoutText = false
                }

                Button(copiedLayoutText ? "Copied" : "Copy") {
                    copyLayoutPositionsToClipboard()
                }

                Button("Done") {
                    layoutEditMode = false
                    copiedLayoutText = false
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.sRGB, red: 0.95, green: 0.90, blue: 0.82).opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.sRGB, red: 0.40, green: 0.28, blue: 0.16).opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }

    private var layoutShortcutButtons: some View {
        Group {
            Button("") { toggleLayoutEditMode() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .hidden()

            Button("") { copyLayoutPositionsToClipboard() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .hidden()
        }
    }

    private func toggleLayoutEditMode() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            layoutEditMode.toggle()
            expandedIndex = nil
            copiedLayoutText = false
        }
    }

    private func copyLayoutPositionsToClipboard() {
        let text = BiomeLevelLayout.debugArrayText(
            for: biome.id,
            positions: activeNormalizedPositions
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedLayoutText = true
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
    var showsDebugIndex: Bool = false
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

                if showsDebugIndex {
                    Text("\(number)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.72)))
                        .offset(y: -(outerSize / 2) - 10)
                        .allowsHitTesting(false)
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
    let bestEntry:       LeaderboardEntry?
    let isCompleted:     Bool
    let hasLeaderboardEntries: Bool
    let pointerEdge:     Edge
    let pointerFraction: CGFloat
    let onPlay:          () -> Void
    let onShowHighScores: () -> Void

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
        ScoringCalculator.previewParScore(for: level)
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
                    value: bestEntry.map { LeaderboardFormatting.formattedScore($0.score) } ?? "—"
                )
                sepiaStroke.opacity(0.30)
                    .frame(width: 1, height: 36)
                    .padding(.horizontal, 10)
                statColumn(
                    label: "TIME",
                    value: bestEntry.map { LeaderboardFormatting.formattedRunTime($0.timeSeconds) } ?? "—"
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
                Text("\(LeaderboardFormatting.formattedScore(parScore))  ·  \(parTimeFormatted)")
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

            HStack(spacing: 8) {
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

                Button(action: onShowHighScores) {
                    Text("High Scores")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hasLeaderboardEntries ? inkPrimary : inkSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(hasLeaderboardEntries ? 0.65 : 0.35))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasLeaderboardEntries)
                .opacity(hasLeaderboardEntries ? 1.0 : 0.55)
            }
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

}

// MARK: - Previews

#Preview("Level Select — Training Range") {
    LevelSelectView(
        biome:  BiomeInfo.squareBiomes[0],
        onBack: { },
        onPlay: { _ in },
        onShowHighScores: { _ in }
    )
    .environmentObject(ProgressStore())
    .environmentObject(LeaderboardStore())
    .frame(width: 600, height: 700)
}

#Preview("Level Select — The Delta (12 levels)") {
    LevelSelectView(
        biome:  BiomeInfo.squareBiomes[8],
        onBack: { },
        onPlay: { _ in },
        onShowHighScores: { _ in }
    )
    .environmentObject(ProgressStore())
    .environmentObject(LeaderboardStore())
    .frame(width: 600, height: 700)
}

#Preview("Level Select — Frozen Mirrors (hex)") {
    LevelSelectView(
        biome:  BiomeInfo.hexBiomes[3],
        onBack: { },
        onPlay: { _ in },
        onShowHighScores: { _ in }
    )
    .environmentObject(ProgressStore())
    .environmentObject(LeaderboardStore())
    .frame(width: 600, height: 700)
}
