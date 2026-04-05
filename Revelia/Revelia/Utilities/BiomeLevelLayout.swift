// Revelia/Utilities/BiomeLevelLayout.swift
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

import Foundation
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
        case 5: return (0.624, 0.435, 0.337)  // The Underside   — warm terra-cotta
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
        CGPoint(x: 0.473, y: 0.1523),
        CGPoint(x: 0.562, y: 0.3104),
        CGPoint(x: 0.535, y: 0.4784),
        CGPoint(x: 0.236, y: 0.6165),
        CGPoint(x: 0.559, y: 0.7414),
        CGPoint(x: 0.383, y: 0.8717),
    ]

    // Biome 1: Fog Marsh (8 levels)
    private static let biome1: [CGPoint] = [
        CGPoint(x: 0.415, y: 0.0830),
        CGPoint(x: 0.539, y: 0.1920),
        CGPoint(x: 0.615, y: 0.3059),
        CGPoint(x: 0.526, y: 0.4304),
        CGPoint(x: 0.499, y: 0.5634),
        CGPoint(x: 0.639, y: 0.6572),
        CGPoint(x: 0.639, y: 0.7941),
        CGPoint(x: 0.509, y: 0.9051),
    ]

    // Biome 2: Bioluminescence (8 levels)
    private static let biome2: [CGPoint] = [
        CGPoint(x: 0.456, y: 0.1177),
        CGPoint(x: 0.381, y: 0.2499),
        CGPoint(x: 0.460, y: 0.3563),
        CGPoint(x: 0.544, y: 0.4950),
        CGPoint(x: 0.499, y: 0.6283),
        CGPoint(x: 0.404, y: 0.7044),
        CGPoint(x: 0.416, y: 0.8523),
        CGPoint(x: 0.515, y: 0.9295),
    ]

    // Biome 3: Frozen Mirrors (8 levels)
    private static let biome3: [CGPoint] = [
        CGPoint(x: 0.497, y: 0.0675),
        CGPoint(x: 0.533, y: 0.1848),
        CGPoint(x: 0.489, y: 0.2940),
        CGPoint(x: 0.552, y: 0.3925),
        CGPoint(x: 0.477, y: 0.5206),
        CGPoint(x: 0.516, y: 0.6635),
        CGPoint(x: 0.453, y: 0.7845),
        CGPoint(x: 0.496, y: 0.9047),
    ]

    // Biome 4: Ruins (8 levels)
    private static let biome4: [CGPoint] = [
        CGPoint(x: 0.508, y: 0.1172),
        CGPoint(x: 0.499, y: 0.2396),
        CGPoint(x: 0.443, y: 0.3622),
        CGPoint(x: 0.565, y: 0.4557),
        CGPoint(x: 0.493, y: 0.5569),
        CGPoint(x: 0.541, y: 0.6701),
        CGPoint(x: 0.450, y: 0.7625),
        CGPoint(x: 0.540, y: 0.9087),
    ]

    // Biome 5: The Underside (8 levels)
    private static let biome5: [CGPoint] = [
        CGPoint(x: 0.351, y: 0.2078),
        CGPoint(x: 0.565, y: 0.2963),
        CGPoint(x: 0.672, y: 0.4311),
        CGPoint(x: 0.461, y: 0.5063),
        CGPoint(x: 0.358, y: 0.6430),
        CGPoint(x: 0.539, y: 0.7303),
        CGPoint(x: 0.700, y: 0.8174),
        CGPoint(x: 0.592, y: 0.9449),
    ]

    // Biome 6: Coral Basin (8 levels)
    private static let biome6: [CGPoint] = [
        CGPoint(x: 0.382, y: 0.0674),
        CGPoint(x: 0.465, y: 0.2156),
        CGPoint(x: 0.333, y: 0.3073),
        CGPoint(x: 0.401, y: 0.4226),
        CGPoint(x: 0.280, y: 0.5213),
        CGPoint(x: 0.370, y: 0.6639),
        CGPoint(x: 0.226, y: 0.7532),
        CGPoint(x: 0.369, y: 0.8994),
    ]

    // Biome 7: Quicksand (8 levels)
    private static let biome7: [CGPoint] = [
        CGPoint(x: 0.421, y: 0.0614),
        CGPoint(x: 0.335, y: 0.2107),
        CGPoint(x: 0.527, y: 0.3122),
        CGPoint(x: 0.456, y: 0.4691),
        CGPoint(x: 0.666, y: 0.5432),
        CGPoint(x: 0.612, y: 0.6887),
        CGPoint(x: 0.793, y: 0.7885),
        CGPoint(x: 0.582, y: 0.9091),
    ]

    // Biome 8: The Delta (12 levels)
    private static let biome8: [CGPoint] = [
        CGPoint(x: 0.415, y: 0.0519),
        CGPoint(x: 0.466, y: 0.1563),
        CGPoint(x: 0.594, y: 0.2201),
        CGPoint(x: 0.427, y: 0.2761),
        CGPoint(x: 0.650, y: 0.3438),
        CGPoint(x: 0.635, y: 0.4393),
        CGPoint(x: 0.499, y: 0.4808),
        CGPoint(x: 0.598, y: 0.5633),
        CGPoint(x: 0.454, y: 0.6110),
        CGPoint(x: 0.297, y: 0.6737),
        CGPoint(x: 0.411, y: 0.7758),
        CGPoint(x: 0.620, y: 0.7923),
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

    /// Formats a biome's normalized positions as Swift source so layout edits
    /// can be pasted directly back into this file.
    static func debugArrayText(for biomeId: Int, positions: [CGPoint]) -> String {
        let label = "biome\(biomeId % 9)"
        let body = positions.map { point in
            String(format: "    CGPoint(x: %.3f, y: %.4f)", point.x, point.y)
        }.joined(separator: ",\n")

        return """
        private static let \(label): [CGPoint] = [
        \(body)
        ]
        """
    }
}
