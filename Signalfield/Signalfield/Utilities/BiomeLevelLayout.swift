// Signalfield/Utilities/BiomeLevelLayout.swift
//
// Provides per-biome layout data for LevelSelectView:
//   - Maps biomeId → Xcode asset image name
//   - Maps biomeId → edge background color (sampled from image borders)
//   - Stores hand-placed normalized (0–1) circle positions for each level
//
// Each position array contains exactly one CGPoint per level in that biome,
// placed visually on the painted path in the background image.
// Hex biomes (id 9–17) reuse the same positions as their square counterparts (0–8)
// via `biomeId % 9`.

import CoreGraphics

enum BiomeLevelLayout {

    // MARK: - Asset Name Mapping

    /// Returns the Xcode asset catalog name for a biome's background image.
    /// Hex biomes (9–17) reuse the same images as square biomes (0–8).
    static func imageName(for biomeId: Int) -> String {
        switch biomeId % 9 {
        case 0: return "TrainingRange"
        case 1: return "FogMarsh"
        case 2: return "Bioluminescence"
        case 3: return "FrozenMirrors"
        case 4: return "Ruins"
        case 5: return "TheUnderside"
        case 6: return "CoralBasin"
        case 7: return "Quicksand"
        case 8: return "TheDelta"
        default: return "TrainingRange"
        }
    }

    // MARK: - Edge Background Colors

    /// Returns an sRGB (r, g, b) triple approximating the dominant edge color of each
    /// biome's background image. Used as the screen background so the scaledToFill image
    /// transition looks seamless when the aspect ratio doesn't cover every pixel.
    static func edgeColor(for biomeId: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch biomeId % 9 {
        case 0: return (0.545, 0.671, 0.290)  // Training Range  — warm yellow-green
        case 1: return (0.290, 0.482, 0.482)  // Fog Marsh       — muted teal
        case 2: return (0.059, 0.122, 0.071)  // Bioluminescence — near-black dark green
        case 3: return (0.784, 0.847, 0.906)  // Frozen Mirrors  — icy pale blue
        case 4: return (0.722, 0.584, 0.416)  // Ruins           — warm sandy tan
        case 5: return (0.071, 0.071, 0.094)  // The Underside   — near-black
        case 6: return (0.722, 0.471, 0.471)  // Coral Basin     — dusty rose
        case 7: return (0.784, 0.565, 0.227)  // Quicksand       — warm amber
        case 8: return (0.227, 0.408, 0.471)  // The Delta       — deep blue-green
        default: return (0.15, 0.15, 0.15)
        }
    }

    // MARK: - Hand-Placed Level Positions
    //
    // One CGPoint per level, normalized (x: 0–1, y: 0–1) where (0,0) is the
    // top-left of the FULL RENDERED background image (not the visible canvas).
    //
    // The background images are 1024×1536 px (aspect 1:1.5).  At any canvas
    // width W, scaledToFill renders them at W × (W×1.5) and center-crops to
    // the canvas height.  Storing positions as image fractions means they track
    // the painted paths correctly at every window size — see levelPositions().
    //
    // Original positions were hand-placed at canvas size 600×663 (window 700 pt
    // minus ~37 pt header).  All y values were converted to image fractions via:
    //   imageY = (canvasY_at_663 + 118.5) / 900
    //          = (oldNormalizedY × 663 + 118.5) / 900
    // x values are unchanged — image width equals canvas width when width-limited.
    //
    // To re-place icons: run the app at default window size, adjust values, rebuild.

    // Biome 0: Training Range (6 levels)
    private static let biome0: [CGPoint] = [
        CGPoint(x: 0.543, y: 0.2370),
        CGPoint(x: 0.464, y: 0.3740),
        CGPoint(x: 0.525, y: 0.5214),
        CGPoint(x: 0.319, y: 0.5796),
        CGPoint(x: 0.311, y: 0.7188),
        CGPoint(x: 0.530, y: 0.7902),
    ]

    // Biome 1: Fog Marsh (8 levels)
    private static let biome1: [CGPoint] = [
        CGPoint(x: 0.615, y: 0.1766),
        CGPoint(x: 0.601, y: 0.2849),
        CGPoint(x: 0.546, y: 0.3608),
        CGPoint(x: 0.488, y: 0.4587),
        CGPoint(x: 0.499, y: 0.5634),
        CGPoint(x: 0.562, y: 0.6348),
        CGPoint(x: 0.623, y: 0.7004),
        CGPoint(x: 0.659, y: 0.8028),
    ]

    // Biome 2: Bioluminescence (8 levels)
    private static let biome2: [CGPoint] = [
        CGPoint(x: 0.390, y: 0.1847),
        CGPoint(x: 0.387, y: 0.3077),
        CGPoint(x: 0.485, y: 0.3792),
        CGPoint(x: 0.488, y: 0.4823),
        CGPoint(x: 0.562, y: 0.5692),
        CGPoint(x: 0.441, y: 0.6348),
        CGPoint(x: 0.380, y: 0.7291),
        CGPoint(x: 0.446, y: 0.8241),
    ]

    // Biome 3: Frozen Mirrors (8 levels)
    private static let biome3: [CGPoint] = [
        CGPoint(x: 0.480, y: 0.1759),
        CGPoint(x: 0.522, y: 0.2547),
        CGPoint(x: 0.483, y: 0.3394),
        CGPoint(x: 0.549, y: 0.4285),
        CGPoint(x: 0.477, y: 0.5206),
        CGPoint(x: 0.514, y: 0.6297),
        CGPoint(x: 0.456, y: 0.6945),
        CGPoint(x: 0.525, y: 0.7851),
    ]

    // Biome 4: Ruins (8 levels)
    private static let biome4: [CGPoint] = [
        CGPoint(x: 0.512, y: 0.2046),
        CGPoint(x: 0.469, y: 0.2797),
        CGPoint(x: 0.443, y: 0.3622),
        CGPoint(x: 0.527, y: 0.4241),
        CGPoint(x: 0.578, y: 0.5214),
        CGPoint(x: 0.541, y: 0.6105),
        CGPoint(x: 0.472, y: 0.6982),
        CGPoint(x: 0.512, y: 0.7895),
    ]

    // Biome 5: The Underside (8 levels)
    private static let biome5: [CGPoint] = [
        CGPoint(x: 0.599, y: 0.1773),
        CGPoint(x: 0.506, y: 0.2716),
        CGPoint(x: 0.646, y: 0.3534),
        CGPoint(x: 0.609, y: 0.4587),
        CGPoint(x: 0.459, y: 0.5029),
        CGPoint(x: 0.356, y: 0.5987),
        CGPoint(x: 0.367, y: 0.7107),
        CGPoint(x: 0.485, y: 0.8079),
    ]

    // Biome 6: Coral Basin (8 levels)
    private static let biome6: [CGPoint] = [
        CGPoint(x: 0.419, y: 0.1744),
        CGPoint(x: 0.435, y: 0.2709),
        CGPoint(x: 0.319, y: 0.3460),
        CGPoint(x: 0.401, y: 0.4226),
        CGPoint(x: 0.274, y: 0.5103),
        CGPoint(x: 0.390, y: 0.5980),
        CGPoint(x: 0.219, y: 0.6591),
        CGPoint(x: 0.343, y: 0.7600),
    ]

    // Biome 7: Quicksand (8 levels)
    private static let biome7: [CGPoint] = [
        CGPoint(x: 0.338, y: 0.1707),
        CGPoint(x: 0.332, y: 0.2908),
        CGPoint(x: 0.475, y: 0.3357),
        CGPoint(x: 0.456, y: 0.4691),
        CGPoint(x: 0.572, y: 0.4926),
        CGPoint(x: 0.586, y: 0.6238),
        CGPoint(x: 0.736, y: 0.6834),
        CGPoint(x: 0.723, y: 0.8146),
    ]

    // Biome 8: The Delta (12 levels)
    private static let biome8: [CGPoint] = [
        CGPoint(x: 0.446, y: 0.1648),
        CGPoint(x: 0.525, y: 0.1935),
        CGPoint(x: 0.549, y: 0.2680),
        CGPoint(x: 0.596, y: 0.3306),
        CGPoint(x: 0.533, y: 0.3836),
        CGPoint(x: 0.578, y: 0.4470),
        CGPoint(x: 0.499, y: 0.4808),
        CGPoint(x: 0.565, y: 0.5442),
        CGPoint(x: 0.470, y: 0.5737),
        CGPoint(x: 0.475, y: 0.6657),
        CGPoint(x: 0.414, y: 0.7181),
        CGPoint(x: 0.433, y: 0.8182),
    ]

    // MARK: - Position Lookup

    /// Returns the hand-placed normalized positions for the given biome.
    /// Hex biomes (9–17) mirror their square counterparts via `biomeId % 9`.
    static func normalizedPositions(for biomeId: Int) -> [CGPoint] {
        switch biomeId % 9 {
        case 0: return biome0
        case 1: return biome1
        case 2: return biome2
        case 3: return biome3
        case 4: return biome4
        case 5: return biome5
        case 6: return biome6
        case 7: return biome7
        case 8: return biome8
        default: return []
        }
    }

    /// Converts image-fraction positions into canvas coordinates for `canvasSize`.
    ///
    /// Background images are 1024×1536 px (aspect 1:1.5).  With `.scaledToFill`
    /// constrained by canvas width, the image always renders at
    ///   renderedHeight = canvasSize.width × 1.5
    /// and is center-cropped to `canvasSize.height`.  Positions stored as image
    /// fractions map to canvas coordinates as:
    ///   canvasX = normalizedX × canvasWidth          (image width = canvas width)
    ///   canvasY = normalizedY × renderedHeight − cropFromTop
    ///
    /// This produces correct alignment at any canvas / window size.
    static func levelPositions(for biomeId: Int, in canvasSize: CGSize) -> [CGPoint] {
        let renderedImageHeight = canvasSize.width * 1.5
        // max(0, …) guards against windows taller than the rendered image (> 900 pt
        // at W=600), where scaledToFill would switch to height-limited fill instead.
        let cropFromTop = max(0, (renderedImageHeight - canvasSize.height) / 2)

        return normalizedPositions(for: biomeId).map {
            CGPoint(
                x: $0.x * canvasSize.width,
                y: $0.y * renderedImageHeight - cropFromTop
            )
        }
    }
}
