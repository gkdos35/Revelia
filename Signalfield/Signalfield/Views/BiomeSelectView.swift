// Signalfield/Views/BiomeSelectView.swift
//
// Campaign Task 3b — Watercolor continent map visual pass.
//
// The painted continent-map.png is the base layer. Programmatic fog overlays
// (one per biome, animated on unlock) and interactive pin markers sit on top.
// BiomeInfo model + all static biome arrays are preserved unchanged below.

import Combine
import SwiftUI

// ============================================================================
// MARK: - RevealTrigger
// ============================================================================

/// The reason the map is being shown after returning from gameplay.
/// Drives the cinematic reveal sequence in BiomeSelectView.
///
/// - `biomeUnlock(mapIndex:)` — the player just finished the last level of a
///   biome, unlocking the next one at map position 0–8.
/// - `squareCampaignComplete` — the player finished The Delta square (L74),
///   completing the square campaign. Plays the "Campaign Complete!" banner,
///   then chains into the hex campaign unlock reveal: the toggle appears, the
///   map switches to a fully-fogged hex view, hex Training Range dissolves with
///   a golden shimmer, and a "Hex Campaign Unlocked!" banner plays.
/// - `campaignComplete` — the player finished The Delta hex (L148), completing
///   the entire campaign. The whole map gets a golden shimmer and a
///   "Campaign Complete!" banner. No further content is unlocked.
enum RevealTrigger {
    case biomeUnlock(mapIndex: Int)
    case squareCampaignComplete
    case campaignComplete
}

// ============================================================================
// MARK: - BiomeInfo Model (unchanged — used throughout the app)
// ============================================================================

/// Lightweight descriptor for a single biome entry on the campaign screen.
struct BiomeInfo: Identifiable {
    let id: Int               // biomeId (0–17); matches LevelSpec.biomeId
    let name: String
    let icon: String          // SF Symbol name
    let levels: [LevelSpec]

    var levelRange: String {
        guard let first = levels.first, let last = levels.last else { return "" }
        return "\(first.id)–\(last.id)"
    }

    var totalStarsPossible: Int { levels.count * 3 }
}

extension BiomeInfo {
    static let squareBiomes: [BiomeInfo] = [
        BiomeInfo(id: 0, name: "Training Range",  icon: "flag.fill",
                  levels: LevelSpec.trainingRange),
        BiomeInfo(id: 1, name: "Fog Marsh",        icon: "cloud.fog",
                  levels: LevelSpec.fogMarsh),
        BiomeInfo(id: 2, name: "Bioluminescence",  icon: "lightbulb.fill",
                  levels: LevelSpec.bioluminescence),
        BiomeInfo(id: 3, name: "Frozen Mirrors",   icon: "arrow.left.arrow.right",
                  levels: LevelSpec.frozenMirrors),
        BiomeInfo(id: 4, name: "Ruins",            icon: "building.columns",
                  levels: LevelSpec.ruins),
        BiomeInfo(id: 5, name: "The Underside",    icon: "arrow.up.arrow.down",
                  levels: LevelSpec.theUnderside),
        BiomeInfo(id: 6, name: "Coral Basin",      icon: "scope",
                  levels: LevelSpec.coralBasin),
        BiomeInfo(id: 7, name: "Quicksand",        icon: "hourglass.bottomhalf.filled",
                  levels: LevelSpec.quicksand),
        BiomeInfo(id: 8, name: "The Delta",        icon: "water.waves",
                  levels: LevelSpec.theDelta),
    ]

    static let hexBiomes: [BiomeInfo] = [
        BiomeInfo(id: 9,  name: "Training Range — Hex",  icon: "flag.fill",
                  levels: LevelSpec.trainingRangeHex),
        BiomeInfo(id: 10, name: "Fog Marsh — Hex",       icon: "cloud.fog",
                  levels: LevelSpec.fogMarshHex),
        BiomeInfo(id: 11, name: "Bioluminescence — Hex", icon: "lightbulb.fill",
                  levels: LevelSpec.bioluminescenceHex),
        BiomeInfo(id: 12, name: "Frozen Mirrors — Hex",  icon: "arrow.left.arrow.right",
                  levels: LevelSpec.frozenMirrorsHex),
        BiomeInfo(id: 13, name: "Ruins — Hex",           icon: "building.columns",
                  levels: LevelSpec.ruinsHex),
        BiomeInfo(id: 14, name: "The Underside — Hex",   icon: "arrow.up.arrow.down",
                  levels: LevelSpec.theUndersideHex),
        BiomeInfo(id: 15, name: "Coral Basin — Hex",     icon: "scope",
                  levels: LevelSpec.coralBasinHex),
        BiomeInfo(id: 16, name: "Quicksand — Hex",       icon: "hourglass.bottomhalf.filled",
                  levels: LevelSpec.quicksandHex),
        BiomeInfo(id: 17, name: "The Delta — Hex",       icon: "water.waves",
                  levels: LevelSpec.theDeltaHex),
    ]
}

// ============================================================================
// MARK: - Map Geometry
// ============================================================================

/// All fixed geometry for the continent map, in normalized (0–1) coordinates.
/// At render time coordinates are multiplied by the actual rendered canvas size.
private enum MapLayout {

    /// continent-map.png is 1024×1536 — exactly 2:3 width:height.
    static let imageAspect: CGFloat = 2.0 / 3.0

    /// Background color matched to the painted ocean in the image corners.
    /// Sampled average of four corners: approximately RGB(55, 100, 158).
    static let oceanColor = Color(red: 0.22, green: 0.39, blue: 0.62)

    // -------------------------------------------------------------------------
    // MARK: Pin positions (normalized, 0–1)
    // Visual center of each biome region — where the interactive badge sits.
    // -------------------------------------------------------------------------
    static let pinNorms: [CGPoint] = [
        CGPoint(x: 0.44, y: 0.50),  // 0  Training Range  — bright central clearing
        CGPoint(x: 0.17, y: 0.28),  // 1  Fog Marsh        — upper-left teal coast
        CGPoint(x: 0.18, y: 0.52),  // 2  Bioluminescence  — left dark forest
        CGPoint(x: 0.50, y: 0.16),  // 3  Frozen Mirrors   — top snowy peaks
        CGPoint(x: 0.73, y: 0.24),  // 4  Ruins            — upper-right sandy terrain
        CGPoint(x: 0.69, y: 0.47),  // 5  The Underside    — dark rocky cave mass
        CGPoint(x: 0.17, y: 0.72),  // 6  Coral Basin      — lower-left pink shore
        CGPoint(x: 0.72, y: 0.72),  // 7  Quicksand        — lower-right desert
        CGPoint(x: 0.44, y: 0.82),  // 8  The Delta        — southern river delta
    ]

    // -------------------------------------------------------------------------
    // MARK: Region boundary vertices (normalized, 0–1)
    //
    // Each array traces the biome's painted boundary. Rendered as smooth closed
    // bezier curves (midpoint-quadratic method). Used ONLY for fog clipping —
    // never stroked or drawn visibly.
    //
    // Coordinate origin: (0,0) = top-left of image, x right, y down.
    // Based on pixel sampling of the 1024×1536 source image.
    // -------------------------------------------------------------------------
    static let regionVerts: [[CGPoint]] = [

        // 0  Training Range — bright yellow-green central meadow + river valley
        [CGPoint(x:0.30,y:0.37), CGPoint(x:0.46,y:0.34), CGPoint(x:0.60,y:0.38),
         CGPoint(x:0.63,y:0.51), CGPoint(x:0.58,y:0.63), CGPoint(x:0.44,y:0.66),
         CGPoint(x:0.29,y:0.59), CGPoint(x:0.26,y:0.47)],

        // 1  Fog Marsh — upper-left teal/blue-green coastal wetlands
        [CGPoint(x:0.08,y:0.17), CGPoint(x:0.22,y:0.15), CGPoint(x:0.32,y:0.21),
         CGPoint(x:0.31,y:0.35), CGPoint(x:0.21,y:0.42), CGPoint(x:0.09,y:0.38),
         CGPoint(x:0.06,y:0.26)],

        // 2  Bioluminescence — left side dense dark forest (very dark green)
        [CGPoint(x:0.08,y:0.38), CGPoint(x:0.24,y:0.36), CGPoint(x:0.32,y:0.42),
         CGPoint(x:0.33,y:0.57), CGPoint(x:0.26,y:0.67), CGPoint(x:0.14,y:0.67),
         CGPoint(x:0.07,y:0.60), CGPoint(x:0.05,y:0.48)],

        // 3  Frozen Mirrors — snowy white mountain peaks, top center
        [CGPoint(x:0.22,y:0.09), CGPoint(x:0.40,y:0.04), CGPoint(x:0.60,y:0.04),
         CGPoint(x:0.76,y:0.09), CGPoint(x:0.80,y:0.21), CGPoint(x:0.68,y:0.31),
         CGPoint(x:0.50,y:0.33), CGPoint(x:0.30,y:0.31), CGPoint(x:0.18,y:0.20)],

        // 4  Ruins — upper-right sandstone, NORTH of the shared border with The Underside.
        //
        // Shared border (identical vertices used by biome 5, traversed in opposite
        // direction — blob algorithm produces matching curves along both paths):
        //   (0.51,0.38) · (0.70,0.38) · (0.88,0.44)
        // On-curve midpoints: (0.605,0.38) and (0.790,0.410) — same in both paths.
        [CGPoint(x:0.57,y:0.08), CGPoint(x:0.76,y:0.05), CGPoint(x:0.93,y:0.13),
         CGPoint(x:0.95,y:0.35), CGPoint(x:0.88,y:0.44),  // → shared border right end
         CGPoint(x:0.70,y:0.38), CGPoint(x:0.51,y:0.38),  // → shared border: mid, left
         CGPoint(x:0.50,y:0.32)],                           // → back toward Frozen Mirrors

        // 5  The Underside — cave mass, SOUTH of the shared border with Ruins.
        //    Starts from the same three shared-border vertices (left→right).
        [CGPoint(x:0.51,y:0.38), CGPoint(x:0.70,y:0.38), CGPoint(x:0.88,y:0.44),  // ← shared border
         CGPoint(x:0.93,y:0.58), CGPoint(x:0.80,y:0.65),
         CGPoint(x:0.64,y:0.65), CGPoint(x:0.54,y:0.58), CGPoint(x:0.52,y:0.48)],

        // 6  Coral Basin — lower-left pink/orange/coral shoreline
        [CGPoint(x:0.07,y:0.62), CGPoint(x:0.22,y:0.60), CGPoint(x:0.32,y:0.65),
         CGPoint(x:0.32,y:0.78), CGPoint(x:0.22,y:0.84), CGPoint(x:0.10,y:0.81),
         CGPoint(x:0.04,y:0.71)],

        // 7  Quicksand — lower-right sandy amber desert dunes
        [CGPoint(x:0.55,y:0.60), CGPoint(x:0.72,y:0.58), CGPoint(x:0.88,y:0.62),
         CGPoint(x:0.93,y:0.74), CGPoint(x:0.88,y:0.86), CGPoint(x:0.72,y:0.88),
         CGPoint(x:0.56,y:0.82), CGPoint(x:0.50,y:0.70)],

        // 8  The Delta — southern river delta where the river meets the ocean
        [CGPoint(x:0.27,y:0.72), CGPoint(x:0.46,y:0.70), CGPoint(x:0.62,y:0.72),
         CGPoint(x:0.66,y:0.83), CGPoint(x:0.56,y:0.92), CGPoint(x:0.36,y:0.92),
         CGPoint(x:0.22,y:0.83)],
    ]

    // -------------------------------------------------------------------------
    // MARK: Continent outline (normalized, 0–1, clockwise from NW)
    //
    // Single closed path tracing the outer landmass boundary.
    // Used by UnifiedFogView as the fog "container" — unlocked biome regions
    // are subtracted from it via the even-odd fill rule to create clean holes.
    // -------------------------------------------------------------------------
    static let continentVerts: [CGPoint] = [
        CGPoint(x: 0.16, y: 0.07),  // NW — Fog Marsh top
        CGPoint(x: 0.38, y: 0.01),  // N  — Frozen Mirrors west peak
        CGPoint(x: 0.62, y: 0.01),  // N  — Frozen Mirrors east peak
        CGPoint(x: 0.82, y: 0.04),  // NE — Ruins top
        CGPoint(x: 0.97, y: 0.12),  // NE coast
        CGPoint(x: 0.97, y: 0.38),  // E  coast mid-upper
        CGPoint(x: 0.95, y: 0.58),  // E  coast mid-lower
        CGPoint(x: 0.94, y: 0.76),  // E  coast — Quicksand right
        CGPoint(x: 0.88, y: 0.91),  // SE — Quicksand bottom-right
        CGPoint(x: 0.70, y: 0.96),  // S  — Quicksand / Delta seam
        CGPoint(x: 0.50, y: 0.97),  // S  — The Delta centre
        CGPoint(x: 0.32, y: 0.96),  // S  — The Delta left
        CGPoint(x: 0.14, y: 0.86),  // SW — Coral Basin bottom
        CGPoint(x: 0.02, y: 0.74),  // W  coast lower
        CGPoint(x: 0.02, y: 0.52),  // W  coast mid
        CGPoint(x: 0.03, y: 0.35),  // W  coast upper — Bioluminescence
        CGPoint(x: 0.05, y: 0.18),  // NW coast — Fog Marsh lower
        CGPoint(x: 0.10, y: 0.08),  // NW — Fog Marsh upper
    ]

    /// Returns the largest canvas size that fits `viewSize` while maintaining
    /// the image's 2:3 aspect ratio (scaledToFit behaviour).
    static func canvasSize(for viewSize: CGSize) -> CGSize {
        let viewAspect = viewSize.width / viewSize.height
        if viewAspect <= imageAspect {
            // View is more portrait-ish: constrain by width
            return CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // View is more landscape-ish: constrain by height
            return CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
    }
}

// ============================================================================
// MARK: - Path: Smooth Blob
// ============================================================================

private extension Path {
    /// Smooth closed path through `points` via midpoint-quadratic-Bézier.
    /// Each vertex is a control point; on-curve knots are midpoints between
    /// consecutive vertices. Produces organic rounded shapes from simple arrays.
    static func blob(through points: [CGPoint]) -> Path {
        guard points.count >= 3 else { return Path() }
        var path = Path()
        let n = points.count
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        path.move(to: mid(points[n - 1], points[0]))
        for i in 0..<n {
            path.addQuadCurve(
                to: mid(points[i], points[(i + 1) % n]),
                control: points[i]
            )
        }
        path.closeSubpath()
        return path
    }
}

// ============================================================================
// MARK: - BiomeRegionShape
// ============================================================================

/// Smooth closed shape for one biome's territory.
/// Receives normalized (0–1) vertices; scales to the rect given by SwiftUI.
/// Used only as a fog fill shape — never stroked.
private struct BiomeRegionShape: Shape {
    let verts: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let pts = verts.map { CGPoint(x: $0.x * rect.width, y: $0.y * rect.height) }
        return Path.blob(through: pts)
    }
}

// ============================================================================
// MARK: - UnifiedFogView
// ============================================================================

/// Single-layer subtractive fog.
///
/// Starts with a full-image rectangle at opacity 0.82 and boolean-subtracts
/// each UNLOCKED biome region from it, leaving a transparent hole where the
/// terrain should show through. Locked biome regions are never subtracted, so
/// they remain fully fogged regardless of path geometry.
///
/// `Path.subtracting()` (macOS 12+) is used instead of even-odd fill because
/// it is robust against overlapping region paths: each region is removed
/// independently from the fog rectangle, so no double-subtraction artefacts
/// can occur even if adjacent biome boundaries share area.
///
/// `.blur(radius: 18)` gives soft feathered edges at every fog/clear boundary,
/// hiding sub-pixel seams between adjacent region paths.
private struct UnifiedFogView: View {
    let lockedBiomes: Set<Int>
    let canvasSize: CGSize

    var body: some View {
        Canvas { ctx, size in
            // Fog covers the entire image by default.
            var fogPath = Path(CGRect(origin: .zero, size: size))

            // Boolean-subtract each unlocked biome to reveal its terrain.
            for i in 0..<9 where !lockedBiomes.contains(i) {
                let region = Path.blob(through: MapLayout.regionVerts[i].map {
                    CGPoint(x: $0.x * size.width, y: $0.y * size.height)
                })
                fogPath = fogPath.subtracting(region)
            }

            ctx.fill(fogPath, with: .color(Color.white.opacity(0.82)))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .blur(radius: 18)
        .allowsHitTesting(false)
    }
}

// ============================================================================
// MARK: - BiomeSelectView
// ============================================================================

struct BiomeSelectView: View {
    @EnvironmentObject private var progressStore: ProgressStore
    @EnvironmentObject private var settingsStore: SettingsStore

    /// Called when the player taps an unlocked biome pin.
    var onSelect: (BiomeInfo) -> Void

    /// Why we're returning to the map. Drives the cinematic reveal sequence.
    /// nil = normal back navigation, no animation needed.
    var revealTrigger: RevealTrigger? = nil

    /// Which campaign mode to open in. Passed by RootView so the map restores
    /// the correct campaign after returning from a hex biome, instead of always
    /// defaulting to the square campaign.
    var initialShowHex: Bool = false

    // MARK: State

    @State private var showingHex:  Bool    = false
    @State private var zoomScale:   CGFloat = 1.0
    @State private var zoomAnchor:  CGFloat = 1.0
    @State private var panOffset:   CGSize  = .zero
    @State private var dragAnchor:  CGSize  = .zero

    /// Biomes whose regions are still included in the unified fog path.
    /// Removing an index punches a transparent hole into the fog instantly.
    @State private var lockedBiomes: Set<Int> = Set(0..<9)

    /// Per-biome fade-out overlays active during the unlock animation.
    /// Each entry animates from 0.82 → 0.0 over ~1–2 s, then is removed.
    @State private var dissolvingBiomes: [Int: Double] = [:]

    // MARK: Cinematic reveal state

    /// Map index of the biome currently receiving a golden shimmer overlay.
    /// nil = no biome-specific shimmer active.
    @State private var shimmerBiomeIndex: Int?      = nil
    /// Opacity of the biome-specific golden shimmer (0–1).
    @State private var shimmerOpacity:    Double    = 0.0
    /// Opacity of the full-map golden shimmer used for Campaign Complete.
    @State private var fullShimmerOpacity: Double   = 0.0
    /// Text displayed in the floating unlock / campaign-complete banner.
    @State private var bannerText:        String?   = nil
    /// Opacity of the banner (0 = hidden, 1 = fully visible).
    @State private var bannerOpacity:     Double    = 0.0
    /// Scale overrides for individual pins during their bounce-in animation.
    /// Absent keys → pin renders at scale 1.0 (normal).
    @State private var pinScales: [Int: CGFloat]    = [:]

    @State private var showingCabinet    = false
    @State private var cabinetBiomeId: Int? = nil
    @State private var showSettings      = false
    @State private var showTitleScreen   = false

    /// Scale factor for the globe toggle button's tap-pulse animation.
    @State private var globeScale: CGFloat = 1.0

    /// Set to true during the Phase 2 hex unlock reveal that follows
    /// `.squareCampaignComplete`. While true, `initLockState()` forces all
    /// hex biomes into the locked (fogged) set so the dissolve animation has
    /// something to fade away, even though ProgressStore already reflects L75
    /// as unlocked (since L74 was just completed).
    @State private var hexRevealPending: Bool = false

    // MARK: Derived

    // The hex toggle only appears once the entire square campaign is complete (L74).
    private var hexCampaignVisible: Bool { progressStore.isCompleted("L74") }

    private var displayedBiomes: [BiomeInfo] {
        showingHex ? BiomeInfo.hexBiomes : BiomeInfo.squareBiomes
    }

    private var totalStarsEarned: Int {
        displayedBiomes.reduce(0) { sum, b in
            sum + b.levels.reduce(0) { $0 + progressStore.bestStars(for: $1.id) }
        }
    }

    private var totalStarsPossible: Int {
        displayedBiomes.reduce(0) { $0 + $1.totalStarsPossible }
    }

    // MARK: Body

    /// Top-level body — conditionally shows the specimen cabinet hierarchy or the map.
    var body: some View {
        if let biomeId = cabinetBiomeId {
            // Biome display room — navigated to from the cabinet hub
            BiomeDisplayRoomView(biomeId: biomeId, onBack: { cabinetBiomeId = nil })
        } else if showingCabinet {
            // Cabinet hub — navigated to from the Specimens button
            SpecimenCabinetView(
                onBack:         { showingCabinet = false },
                onSelectBiome:  { cabinetBiomeId = $0 }
            )
        } else {
            mapContent
        }
    }

    /// The campaign map view — identical to the former `body` implementation.
    /// Extracted so `body` can conditionally swap between map and cabinet screens.
    private var mapContent: some View {
        GeometryReader { geo in
            let canvas = MapLayout.canvasSize(for: geo.size)

            ZStack {
                // Layer 1 — ocean background (seamless with the painting's ocean edges)
                MapLayout.oceanColor

                // Layer 2 — map group: painting + fog + pins, transformed together
                mapGroup(canvas: canvas)
                    .scaleEffect(zoomScale, anchor: .center)
                    .offset(panOffset)

                // Layer 3 — UI chrome (title, toggle, specimen) — stays fixed
                chromeOverlay

                // Layer 4 — Cinematic unlock / campaign-complete banner.
                // Floats above everything; non-interactive.
                if let text = bannerText {
                    Text(text)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .shadow(color: .black.opacity(0.85), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.black.opacity(0.45)))
                        .opacity(bannerOpacity)
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            // Pan via click-drag (or two-finger drag on trackpad)
            .gesture(
                DragGesture()
                    .onChanged { v in
                        let proposed = CGSize(
                            width:  dragAnchor.width  + v.translation.width,
                            height: dragAnchor.height + v.translation.height
                        )
                        panOffset = clamp(proposed, canvas: canvas, view: geo.size)
                    }
                    .onEnded { _ in dragAnchor = panOffset }
            )
            // Zoom via trackpad pinch
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in
                        zoomScale  = min(2.5, max(0.85, zoomAnchor * v))
                        panOffset  = clamp(panOffset, canvas: canvas, view: geo.size)
                    }
                    .onEnded { _ in zoomAnchor = zoomScale }
            )
            .onAppear {
                panOffset  = .zero ; dragAnchor = .zero
                zoomScale  = 1.0   ; zoomAnchor = 1.0
                // Restore the campaign mode the player was in before navigating
                // into a biome. Without this, returning from a hex biome always
                // drops back to the square map (showingHex defaults to false).
                showingHex = initialShowHex
                initLockState()
                // If a cinematic reveal was requested, let the view settle for
                // 0.3 s (first layout pass) before kicking off the sequence.
                if let trigger = revealTrigger {
                    let capturedCanvas   = canvas
                    let capturedViewSize = geo.size
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        startRevealSequence(
                            trigger:  trigger,
                            canvas:   capturedCanvas,
                            viewSize: capturedViewSize
                        )
                    }
                }
            }
            .onReceive(progressStore.objectWillChange) { _ in
                DispatchQueue.main.async { animateFogReveal() }
            }
            .onChange(of: showingHex) { initLockState() }
            .onChange(of: hexCampaignVisible) {
                if !hexCampaignVisible { showingHex = false }
            }
        }
        // DEBUG — remove before release
        // Cmd+Shift+D: dump level records from the map screen.
        .background(
            Button("") { progressStore.dumpRecords() }
                .keyboardShortcut("D", modifiers: [.command, .shift])
                .hidden()
        )
        // Title splash overlay — covers the full view when the home button is tapped.
        // fullScreenCover is unavailable on macOS; ZStack overlay achieves the same result.
        .overlay {
            if showTitleScreen {
                TitleSplashView(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showTitleScreen = false
                    }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showTitleScreen)
    }

    // -------------------------------------------------------------------------
    // MARK: Map Group
    // -------------------------------------------------------------------------

    @ViewBuilder
    private func mapGroup(canvas: CGSize) -> some View {
        ZStack(alignment: .topLeading) {

            // Base layer: the watercolor painting, rendered at canvas size
            Image("ContinentMap")
                .resizable()
                .frame(width: canvas.width, height: canvas.height)

            // Unified fog: single even-odd path (continent MINUS unlocked holes).
            // One continuous fog mass — no internal seams between biome regions.
            UnifiedFogView(lockedBiomes: lockedBiomes, canvasSize: canvas)

            // Dissolve overlays: per-biome fade-outs active only during the
            // unlock animation. Empty (and invisible) at steady state.
            ForEach(Array(dissolvingBiomes.keys).sorted(), id: \.self) { i in
                BiomeRegionShape(verts: MapLayout.regionVerts[i])
                    .fill(Color.white.opacity(dissolvingBiomes[i] ?? 0))
                    .frame(width: canvas.width, height: canvas.height)
                    .blur(radius: 12)
                    .allowsHitTesting(false)
            }

            // Biome-specific golden shimmer: fires during a biome-unlock reveal.
            // Rendered below pins via .blendMode(.screen) for a warm luminous glow.
            if let idx = shimmerBiomeIndex {
                BiomeRegionShape(verts: MapLayout.regionVerts[idx])
                    .fill(Color(red: 1.0, green: 0.85, blue: 0.30).opacity(shimmerOpacity))
                    .frame(width: canvas.width, height: canvas.height)
                    .blendMode(.screen)
                    .blur(radius: 25)
                    .allowsHitTesting(false)
            }

            // Full-map golden shimmer: fires during the Campaign Complete reveal.
            if fullShimmerOpacity > 0 {
                Color(red: 1.0, green: 0.85, blue: 0.30)
                    .opacity(fullShimmerOpacity)
                    .frame(width: canvas.width, height: canvas.height)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            // Pin markers: interactive labels rendered above fog and shimmer.
            // `pinScales[i]` is set to 0 during the spring bounce-in animation
            // so the pin appears to grow from nothing when the biome unlocks.
            ForEach(0..<9, id: \.self) { i in
                let biome       = displayedBiomes[i]
                let isLocked    = !progressStore.isUnlocked(biome.levels[0])
                let isCompleted = biome.levels.allSatisfy { progressStore.isCompleted($0.id) }
                let stars       = biome.levels.reduce(0) { $0 + progressStore.bestStars(for: $1.id) }

                BiomePinView(
                    biome:        biome,
                    isLocked:     isLocked,
                    isCompleted:  isCompleted,
                    starsEarned:  stars,
                    isStartBiome: i == 0,
                    onTap:        { onSelect(biome) }
                )
                .scaleEffect(pinScales[i] ?? 1.0)
                .position(
                    x: MapLayout.pinNorms[i].x * canvas.width,
                    y: MapLayout.pinNorms[i].y * canvas.height
                )
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }

    // -------------------------------------------------------------------------
    // MARK: Chrome Overlay
    // -------------------------------------------------------------------------

    /// UI chrome that overlays the map at fixed screen positions.
    /// Not part of the transformed map group — unaffected by pan and zoom.
    private var chromeOverlay: some View {
        VStack(spacing: 0) {

            // Top bar — home button + title + star total + Square/Hex toggle + settings
            HStack(alignment: .center, spacing: 10) {
                // Home button — returns to the title / splash screen
                Button(action: { showTitleScreen = true }) {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.60), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .help("Title Screen")

                Text("Signalfield")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.75), radius: 3, x: 0, y: 1)

                Spacer()

                // Aggregate star count for the active campaign
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.yellow)
                    Text("\(totalStarsEarned)/\(totalStarsPossible)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white)
                }
                .shadow(color: .black.opacity(0.7), radius: 2)

                // Settings gear button
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.60), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.50), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settingsStore)
                    .environmentObject(progressStore)
                    .frame(width: 600, height: 500)
            }

            Spacer()

            // Bottom-right controls: globe campaign toggle (when unlocked) + Specimens
            HStack(alignment: .bottom, spacing: 0) {
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    // Globe toggle — only visible once hex campaign is unlocked (L74 done)
                    if hexCampaignVisible {
                        campaignGlobeButton
                    }
                    // Specimen Collection button
                    Button { showingCabinet = true } label: {
                        Label("Specimens", systemImage: "ladybug.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.black.opacity(0.48)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Fog / Lock Helpers
    // -------------------------------------------------------------------------

    /// Snaps lock state to current unlock progress without animation.
    /// Called on appear and whenever the Square/Hex toggle changes.
    ///
    /// If `revealTrigger` is `.biomeUnlock(mapIndex:)`, that biome is temporarily
    /// kept in `lockedBiomes` even though ProgressStore already reflects it as
    /// unlocked. This ensures the map renders with the fog still covering it on
    /// first appear, so the subsequent cinematic reveal has something to dissolve.
    private func initLockState() {

        // ── Hex reveal pending ───────────────────────────────────────────────
        // When Phase 2 of the squareCampaignComplete sequence kicks in, we've
        // just flipped showingHex = true. ProgressStore already knows L75 is
        // unlocked, so the normal path below would immediately reveal hex
        // Training Range — but we need it fogged so the dissolve has something
        // to animate. Override: fog the entire hex map and hide pin 0.
        if hexRevealPending {
            lockedBiomes     = Set(0..<9)
            dissolvingBiomes = [:]
            pinScales        = [0: 0.0]
            return
        }

        // ── Normal path ──────────────────────────────────────────────────────
        var locked = Set<Int>()
        for i in 0..<9 {
            if !progressStore.isUnlocked(displayedBiomes[i].levels[0]) {
                locked.insert(i)
            }
        }
        // For a biome-unlock reveal, temporarily re-fog the newly unlocked biome
        // so the cinematic dissolve has something to fade away.
        // Campaign-complete variants need no re-fog (all biomes stay as-is).
        if case .biomeUnlock(let idx) = revealTrigger, (0..<9).contains(idx) {
            locked.insert(idx)
        }
        lockedBiomes     = locked
        dissolvingBiomes = [:]
        pinScales        = [:]

        // Immediately hide the newly unlocked biome's pin so it is invisible
        // from the very first rendered frame. startRevealSequence() will scale
        // it back to 1.0 with a spring bounce at Step 5 of the sequence.
        // Without this, the pin is visible for the ~0.3 s settle delay before
        // startRevealSequence runs, then disappears, then reappears — breaking
        // the intended order.
        if case .biomeUnlock(let idx) = revealTrigger, (0..<9).contains(idx) {
            pinScales[idx] = 0.0
        }
    }

    /// Dissolves fog for any biome that is now unlocked but still showing fog.
    ///
    /// Called by `.onReceive(progressStore.objectWillChange)` for incidental
    /// progress updates (default 1 s) and by `startRevealSequence` for the
    /// cinematic reveal (2 s).
    ///
    /// For each affected biome:
    ///   1. A dissolve overlay begins at 0.82 opacity, matching the fog colour.
    ///   2. The biome is removed from `lockedBiomes`, punching a transparent hole.
    ///   3. The overlay fades to 0 over `duration` seconds (easeInOut).
    ///   4. The overlay entry is removed once the animation finishes.
    private func animateFogReveal(duration: Double = 1.0) {
        for i in 0..<9 {
            guard progressStore.isUnlocked(displayedBiomes[i].levels[0]) else { continue }
            guard lockedBiomes.contains(i) else { continue }

            dissolvingBiomes[i] = 0.82
            lockedBiomes.remove(i)

            withAnimation(.easeInOut(duration: duration)) {
                dissolvingBiomes[i] = 0.0
            }
            let idx = i
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.15) {
                dissolvingBiomes.removeValue(forKey: idx)
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Cinematic Reveal Sequence
    // -------------------------------------------------------------------------

    /// Kicks off the multi-step reveal animation appropriate for `trigger`.
    ///
    /// **Biome unlock timing** (all times relative to call site):
    ///   - t = 0.5 s   Camera pans to the newly unlocked biome (1.0 s easeInOut)
    ///   - t = 1.5 s   Fog dissolves (2.0 s) + golden shimmer begins
    ///   - t = 1.8 s   Shimmer starts fading out (1.8 s easeOut → 0)
    ///   - t = 2.0 s   "[Biome] Unlocked!" banner fades in
    ///   - t = 2.3 s   Pin scales in with spring bounce
    ///   - t = 3.5 s   Banner fades out (0.5 s)
    ///   - t = 4.2 s   Cleanup: shimmer index, banner text, pin scale entry
    ///
    /// **Campaign complete timing:**
    ///   - t = 0.5 s   Full-map golden shimmer fades in (0.5 s)
    ///   - t = 0.8 s   "Campaign Complete!" banner fades in (0.6 s)
    ///   - t = 1.5 s   Full-map shimmer begins fading out (2.0 s)
    ///   - t = 3.5 s   Banner fades out (0.8 s)
    ///   - t = 4.5 s   Cleanup: banner text
    ///
    /// The player may interact with the map at any point — nothing is blocked.
    private func startRevealSequence(
        trigger:  RevealTrigger,
        canvas:   CGSize,
        viewSize: CGSize
    ) {
        switch trigger {

        // ── Biome unlock ───────────────────────────────────────────────────
        case .biomeUnlock(let mapIndex):
            guard (0..<9).contains(mapIndex) else {
                // Out-of-range index (shouldn't happen) — fall back to simple dissolve.
                animateFogReveal()
                return
            }

            // Hide the new pin immediately; it will scale in at t = 2.3 s.
            pinScales[mapIndex] = 0.0

            let base = DispatchTime.now()

            // t = 0.5 s — Camera pan to the newly unlocked biome
            DispatchQueue.main.asyncAfter(deadline: base + 0.5) {
                let target = computePanTarget(for: mapIndex, canvas: canvas, viewSize: viewSize)
                withAnimation(.easeInOut(duration: 1.0)) { panOffset = target }
                dragAnchor = target
            }

            // t = 1.5 s — Fog dissolve (2.0 s) + golden shimmer begins
            DispatchQueue.main.asyncAfter(deadline: base + 1.5) {
                animateFogReveal(duration: 2.0)
                shimmerBiomeIndex = mapIndex
                withAnimation(.easeIn(duration: 0.3)) { shimmerOpacity = 0.7 }
            }

            // t = 1.8 s — Shimmer fades out over 1.8 s
            DispatchQueue.main.asyncAfter(deadline: base + 1.8) {
                withAnimation(.easeOut(duration: 1.8)) { shimmerOpacity = 0.0 }
            }

            // t = 2.0 s — "[Biome] Unlocked!" banner
            DispatchQueue.main.asyncAfter(deadline: base + 2.0) {
                bannerText = "\(displayedBiomes[mapIndex].name) Unlocked!"
                withAnimation(.easeIn(duration: 0.4)) { bannerOpacity = 1.0 }
            }

            // t = 2.3 s — Pin spring bounce-in
            DispatchQueue.main.asyncAfter(deadline: base + 2.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) {
                    pinScales[mapIndex] = 1.0
                }
            }

            // t = 3.5 s — Banner fades out
            DispatchQueue.main.asyncAfter(deadline: base + 3.5) {
                withAnimation(.easeOut(duration: 0.5)) { bannerOpacity = 0.0 }
            }

            // t = 4.2 s — Full cleanup
            DispatchQueue.main.asyncAfter(deadline: base + 4.2) {
                shimmerBiomeIndex = nil
                bannerText        = nil
                pinScales.removeValue(forKey: mapIndex)
            }

        // ── Square campaign complete + hex unlock reveal ───────────────────
        //
        // Phase 1 (t = 0–4.5 s): identical to campaignComplete — full-map
        // golden shimmer and "Campaign Complete!" banner.
        //
        // Phase 2 (t = 5.0 s+): hex reveal sequence — toggle appears,
        // map switches to a fully-fogged hex view, then hex Training Range
        // (map index 0) dissolves with a golden shimmer, a "Hex Campaign
        // Unlocked!" banner, and a pin spring bounce-in.
        case .squareCampaignComplete:
            let base = DispatchTime.now()

            // ── Phase 1: Square campaign banner ────────────────────────────

            // t = 0.5 s — Full-map golden shimmer fades in
            DispatchQueue.main.asyncAfter(deadline: base + 0.5) {
                withAnimation(.easeIn(duration: 0.5)) { fullShimmerOpacity = 0.55 }
            }

            // t = 0.8 s — "Campaign Complete!" banner fades in
            DispatchQueue.main.asyncAfter(deadline: base + 0.8) {
                bannerText = "Campaign Complete!"
                withAnimation(.easeIn(duration: 0.6)) { bannerOpacity = 1.0 }
            }

            // t = 1.5 s — Full-map shimmer begins long fade-out
            DispatchQueue.main.asyncAfter(deadline: base + 1.5) {
                withAnimation(.easeOut(duration: 2.0)) { fullShimmerOpacity = 0.0 }
            }

            // t = 3.5 s — Banner fades out
            DispatchQueue.main.asyncAfter(deadline: base + 3.5) {
                withAnimation(.easeOut(duration: 0.8)) { bannerOpacity = 0.0 }
            }

            // t = 4.5 s — Phase 1 cleanup
            DispatchQueue.main.asyncAfter(deadline: base + 4.5) {
                bannerText = nil
            }

            // ── Phase 2: Hex campaign unlock reveal ─────────────────────────

            // t = 5.0 s — Toggle appears (hexRevealPending = true first so
            // initLockState() — triggered by onChange(of: showingHex) — renders
            // the hex map fully fogged before the dissolve begins).
            DispatchQueue.main.asyncAfter(deadline: base + 5.0) {
                hexRevealPending = true
                showingHex       = true   // onChange calls initLockState() → sees hexRevealPending
            }

            // t = 5.3 s — Fog dissolve over hex Training Range (map index 0)
            // + golden shimmer fades in. animateFogReveal only acts on biomes
            // that are genuinely unlocked; at this moment only index 0 (L75)
            // qualifies, so only Training Range dissolves.
            DispatchQueue.main.asyncAfter(deadline: base + 5.3) {
                animateFogReveal(duration: 2.0)
                shimmerBiomeIndex = 0
                withAnimation(.easeIn(duration: 0.3)) { shimmerOpacity = 0.7 }
            }

            // t = 5.6 s — Shimmer fades out over 1.8 s
            DispatchQueue.main.asyncAfter(deadline: base + 5.6) {
                withAnimation(.easeOut(duration: 1.8)) { shimmerOpacity = 0.0 }
            }

            // t = 5.8 s — "Hex Campaign Unlocked!" banner fades in
            DispatchQueue.main.asyncAfter(deadline: base + 5.8) {
                bannerText = "Hex Campaign Unlocked!"
                withAnimation(.easeIn(duration: 0.4)) { bannerOpacity = 1.0 }
            }

            // t = 6.1 s — Training Range pin spring bounce-in
            DispatchQueue.main.asyncAfter(deadline: base + 6.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) {
                    pinScales[0] = 1.0
                }
            }

            // t = 7.5 s — Banner fades out
            DispatchQueue.main.asyncAfter(deadline: base + 7.5) {
                withAnimation(.easeOut(duration: 0.5)) { bannerOpacity = 0.0 }
            }

            // t = 8.3 s — Full cleanup
            DispatchQueue.main.asyncAfter(deadline: base + 8.3) {
                hexRevealPending  = false
                shimmerBiomeIndex = nil
                bannerText        = nil
                pinScales.removeValue(forKey: 0)
            }

        // ── Campaign complete (true final — hex L148) ──────────────────────
        case .campaignComplete:
            let base = DispatchTime.now()

            // t = 0.5 s — Full-map golden shimmer fades in
            DispatchQueue.main.asyncAfter(deadline: base + 0.5) {
                withAnimation(.easeIn(duration: 0.5)) { fullShimmerOpacity = 0.55 }
            }

            // t = 0.8 s — "Campaign Complete!" banner fades in
            DispatchQueue.main.asyncAfter(deadline: base + 0.8) {
                bannerText = "Campaign Complete!"
                withAnimation(.easeIn(duration: 0.6)) { bannerOpacity = 1.0 }
            }

            // t = 1.5 s — Full-map shimmer begins long fade-out
            DispatchQueue.main.asyncAfter(deadline: base + 1.5) {
                withAnimation(.easeOut(duration: 2.0)) { fullShimmerOpacity = 0.0 }
            }

            // t = 3.5 s — Banner fades out
            DispatchQueue.main.asyncAfter(deadline: base + 3.5) {
                withAnimation(.easeOut(duration: 0.8)) { bannerOpacity = 0.0 }
            }

            // t = 4.5 s — Cleanup
            DispatchQueue.main.asyncAfter(deadline: base + 4.5) {
                bannerText = nil
            }
        }
    }

    /// Returns the clamped pan offset that centers the given biome's pin
    /// in the viewport.
    private func computePanTarget(
        for biomeIndex: Int,
        canvas:   CGSize,
        viewSize: CGSize
    ) -> CGSize {
        let norm = MapLayout.pinNorms[biomeIndex]
        let pinX = norm.x * canvas.width
        let pinY = norm.y * canvas.height
        let raw  = CGSize(
            width:  canvas.width  / 2 - pinX,
            height: canvas.height / 2 - pinY
        )
        return clamp(raw, canvas: canvas, view: viewSize)
    }

    // -------------------------------------------------------------------------
    // MARK: Pan Clamping
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // MARK: Campaign Globe Toggle
    // -------------------------------------------------------------------------

    /// Floating circular button that cycles the map between square and hex campaigns.
    /// Appears in the bottom-right corner once L74 is complete.
    private var campaignGlobeButton: some View {
        ZStack(alignment: .topTrailing) {

            // ── Globe body ────────────────────────────────────────────────────
            Button {
                // Scale-pulse feedback
                withAnimation(.spring(response: 0.15, dampingFraction: 0.55)) {
                    globeScale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.70)) {
                        globeScale = 1.0
                    }
                }
                // Switch campaign
                showingHex.toggle()
            } label: {
                ZStack {
                    // Slate-blue watercolor texture — same crop technique as level markers
                    Image("LevelIconBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .scaleEffect(1.30)
                        .clipShape(Circle())

                    // Mini continent map centered inside
                    Image("ContinentMap")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                    // White border — same opacity/weight as level markers
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 58, height: 58)
                }
                .frame(width: 58, height: 58)
            }
            .buttonStyle(.plain)
            .scaleEffect(globeScale)
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .help(showingHex ? "Switch to Square Campaign" : "Switch to Hex Campaign")

            // ── Mode badge ────────────────────────────────────────────────────
            campaignModeBadge
                .offset(x: 6, y: -6)   // Overlaps the top-right edge of the globe
        }
    }

    /// Small badge on the globe button that indicates the active campaign mode.
    /// Shape and label both animate when the campaign is toggled.
    private var campaignModeBadge: some View {
        let meadowGreen = Color(red: 0x7A / 255.0, green: 0xAA / 255.0, blue: 0x58 / 255.0)

        return ZStack {
            // Badge shape — rounded square (■) for square mode, hexagon (⬡) for hex mode.
            // ZStack with conditional shapes + matching transitions gives a spring cross-fade.
            ZStack {
                if showingHex {
                    HexagonBadgeShape()
                        .fill(meadowGreen)
                        .overlay(HexagonBadgeShape().stroke(Color.black.opacity(0.30), lineWidth: 0.5))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(meadowGreen)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.30), lineWidth: 0.5))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.70), value: showingHex)

            // Mode label
            Text(showingHex ? "H" : "S")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .animation(.spring(response: 0.25, dampingFraction: 0.70), value: showingHex)
        }
        .frame(width: 22, height: 22)
    }

    // -------------------------------------------------------------------------
    // MARK: Pan Clamping
    // -------------------------------------------------------------------------

    /// Clamps `offset` so the scaled canvas never exposes the ocean background
    /// outside the painted image edges. Accounts for current zoom level.
    private func clamp(_ offset: CGSize, canvas: CGSize, view: CGSize) -> CGSize {
        let scaledW = canvas.width  * zoomScale
        let scaledH = canvas.height * zoomScale
        let maxX = max(0, (scaledW - view.width)  / 2)
        let maxY = max(0, (scaledH - view.height) / 2)
        return CGSize(
            width:  min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }
}

// ============================================================================
// MARK: - BiomePinView
// ============================================================================

/// Tappable map pin: circular icon badge + biome name + star count.
/// Positioned absolutely inside the map ZStack via `.position(_:)`.
private struct BiomePinView: View {
    let biome:        BiomeInfo
    let isLocked:     Bool
    let isCompleted:  Bool
    let starsEarned:  Int
    let isStartBiome: Bool   // Training Range gets a slightly larger badge
    let onTap:        () -> Void

    private var badgeSize: CGFloat { isStartBiome ? 44 : 36 }

    /// True for hex biomes (id 9–17). Hex pins render with a hexagonal badge.
    private var isHex: Bool { biome.id >= 9 }

    /// Grid-aware badge shape — round for square biomes, flat-top hex for hex biomes.
    private var badgeShape: TileBackgroundShape { TileBackgroundShape(isHex: isHex) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {

                // Icon badge
                ZStack {
                    badgeShape
                        .fill(badgeFill)
                        .frame(width: badgeSize, height: badgeSize)
                        .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 2)

                    // Completion glow ring (slightly larger than badge)
                    if isCompleted {
                        badgeShape
                            .strokeBorder(Color.yellow.opacity(0.82), lineWidth: 2.5)
                            .frame(width: badgeSize + 6, height: badgeSize + 6)
                    }

                    Image(systemName: isLocked ? "lock.fill" : biome.icon)
                        .font(.system(size: isStartBiome ? 18 : 14, weight: .semibold))
                        .foregroundStyle(
                            isLocked
                                ? AnyShapeStyle(Color.white.opacity(0.45))
                                : AnyShapeStyle(Color.white)
                        )
                }

                // Biome name
                Text(biome.name)
                    .font(.system(size: isStartBiome ? 11 : 10, weight: .bold))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.90), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .fixedSize()

                // Star count (unlocked only)
                if !isLocked {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.yellow)
                        Text("\(starsEarned)/\(biome.totalStarsPossible)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.90))
                    }
                    .shadow(color: .black.opacity(0.7), radius: 1)
                }
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.48 : 1.0)
        .help("\(biome.name) · \(starsEarned)/\(biome.totalStarsPossible) stars")
    }

    private var badgeFill: Color {
        if isLocked    { return Color(white: 0.22) }
        if isCompleted { return Color(red: 0.10, green: 0.55, blue: 0.20) }
        // Unlocked: use the biome's distinct pin colour so each biome is
        // immediately recognisable on the map. Hex biomes reuse the same
        // pinColor as their square counterpart (biomeId % 9 mapping).
        return BiomeTheme.theme(for: biome.id).pinColor
    }
}

// ============================================================================
// MARK: - HexagonBadgeShape
// ============================================================================

/// Flat-top regular hexagon used for the campaign-mode badge on the globe toggle button.
/// Pointy-top orientation (vertices at 0°, 60°, 120°, 180°, 240°, 300° with a −30° phase
/// shift) so the hex reads upright and matches the hex biome pin badges.
private struct HexagonBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r  = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            // −30° phase shift gives flat-top orientation
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let pt    = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

// ============================================================================
// MARK: - Previews
// ============================================================================

#Preview("Map — fresh start") {
    BiomeSelectView(onSelect: { _ in })
        .environmentObject(ProgressStore())
        .environmentObject(SettingsStore())
        .frame(width: 620, height: 720)
}

#Preview("Map — all unlocked") {
    let store = ProgressStore()
    store.allUnlocked = true
    return BiomeSelectView(onSelect: { _ in })
        .environmentObject(store)
        .environmentObject(SettingsStore())
        .frame(width: 620, height: 720)
}

#Preview("Map — biome unlock reveal (Fog Marsh)") {
    BiomeSelectView(
        onSelect:      { _ in },
        revealTrigger: .biomeUnlock(mapIndex: 1)
    )
    .environmentObject({
        let store = ProgressStore()
        store.allUnlocked = true
        return store
    }())
    .environmentObject(SettingsStore())
    .frame(width: 620, height: 720)
}

#Preview("Map — Square Campaign Complete + Hex Unlock reveal") {
    BiomeSelectView(
        onSelect:      { _ in },
        revealTrigger: .squareCampaignComplete
    )
    .environmentObject({
        let store = ProgressStore()
        store.allUnlocked = true
        return store
    }())
    .environmentObject(SettingsStore())
    .frame(width: 620, height: 720)
}

#Preview("Map — Campaign Complete reveal (Hex L148)") {
    BiomeSelectView(
        onSelect:      { _ in },
        revealTrigger: .campaignComplete
    )
    .environmentObject({
        let store = ProgressStore()
        store.allUnlocked = true
        return store
    }())
    .environmentObject(SettingsStore())
    .frame(width: 620, height: 720)
}
