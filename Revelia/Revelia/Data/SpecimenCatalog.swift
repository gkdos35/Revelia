// Revelia/Data/SpecimenCatalog.swift
//
// Static catalog of all 166 collectible specimens.
// Defines WHAT EXISTS — not what has been unlocked.
// Unlock state lives in Persistence/SpecimenStore.swift.
//
// Catalog layout:
//   9 biomes × (square level specimens + hex level specimens + 2 rare) = 166 total
//
//   Biome 0 (Training Range):  6 sq + 6 hex + 2 rare = 14
//   Biomes 1–7 (each):         8 sq + 8 hex + 2 rare = 18  →  7 × 18 = 126
//   Biome 8 (The Delta):      12 sq + 12 hex + 2 rare = 26
//   ──────────────────────────────────────────────────────
//   Grand total:               14 + 126 + 26 = 166
//
// Specimens are generated from the level-range tables at the bottom of this file.
// Runtime artwork is copied into Assets.xcassets as `specimen-<Specimen.id>`.

import Foundation

struct SpecimenCatalog {

    // MARK: - Public API

    /// All 166 specimens, ordered biome-by-biome (square specimens first, then hex,
    /// then the two rare specimens, repeating for each biome 0–8).
    static let all: [Specimen] = buildAll()

    /// All specimens for a given biome (square level specimens, hex level specimens,
    /// square rare, hex rare).
    static func specimens(for biomeId: Int) -> [Specimen] {
        all.filter { $0.biomeId == biomeId }
    }

    /// The level specimen unlocked by 3-starring the given level.
    ///
    /// Returns `nil` for unrecognised level IDs.
    static func specimen(for levelId: String) -> Specimen? {
        byId[levelId]
    }

    /// The rare specimen earned by 3-starring every level in a biome.
    ///
    /// - Parameters:
    ///   - biomeId: 0–8.
    ///   - isHex: `true` for the hex-campaign rare specimen, `false` for the square-campaign rare.
    static func rareSpecimen(for biomeId: Int, isHex: Bool) -> Specimen? {
        byId["B\(biomeId)-\(isHex ? "hex" : "sq")"]
    }

    /// Stable asset-catalog image name for a specimen.
    static func imageName(for specimenId: String) -> String {
        "specimen-\(specimenId)"
    }

    // MARK: - Fast Lookup

    /// O(1) lookup by `Specimen.id`.
    private static let byId: [String: Specimen] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    // MARK: - Source Data

    private static let biomeNames: [String] = [
        "Training Range",   // 0
        "Fog Marsh",        // 1
        "Bioluminescence",  // 2
        "Frozen Mirrors",   // 3
        "Ruins",            // 4
        "The Underside",    // 5
        "Coral Basin",      // 6
        "Quicksand",        // 7
        "The Delta",        // 8
    ]

    /// Inclusive level-number ranges for the SQUARE campaign, indexed by biomeId (0–8).
    ///
    /// Biome 0: L1–L6    (6 levels)
    /// Biome 1: L7–L14   (8 levels)
    /// Biome 2: L15–L22  (8 levels)
    /// Biome 3: L23–L30  (8 levels)
    /// Biome 4: L31–L38  (8 levels)
    /// Biome 5: L39–L46  (8 levels)
    /// Biome 6: L47–L54  (8 levels)
    /// Biome 7: L55–L62  (8 levels)
    /// Biome 8: L63–L74  (12 levels — The Delta)
    private static let squareLevelRanges: [ClosedRange<Int>] = [
        1...6,      // Biome 0 — Training Range
        7...14,     // Biome 1 — Fog Marsh
        15...22,    // Biome 2 — Bioluminescence
        23...30,    // Biome 3 — Frozen Mirrors
        31...38,    // Biome 4 — Ruins
        39...46,    // Biome 5 — The Underside
        47...54,    // Biome 6 — Coral Basin
        55...62,    // Biome 7 — Quicksand
        63...74,    // Biome 8 — The Delta
    ]

    /// Inclusive level-number ranges for the HEX campaign, indexed by biomeId (0–8).
    ///
    /// Biome 0: L75–L80    (6 levels)
    /// Biome 1: L81–L88    (8 levels)
    /// Biome 2: L89–L96    (8 levels)
    /// Biome 3: L97–L104   (8 levels)
    /// Biome 4: L105–L112  (8 levels)
    /// Biome 5: L113–L120  (8 levels)
    /// Biome 6: L121–L128  (8 levels)
    /// Biome 7: L129–L136  (8 levels)
    /// Biome 8: L137–L148  (12 levels — Hex Delta)
    private static let hexLevelRanges: [ClosedRange<Int>] = [
        75...80,    // Biome 0 — Hex Training Range
        81...88,    // Biome 1 — Hex Fog Marsh
        89...96,    // Biome 2 — Hex Bioluminescence
        97...104,   // Biome 3 — Hex Frozen Mirrors
        105...112,  // Biome 4 — Hex Ruins
        113...120,  // Biome 5 — Hex The Underside
        121...128,  // Biome 6 — Hex Coral Basin
        129...136,  // Biome 7 — Hex Quicksand
        137...148,  // Biome 8 — Hex The Delta
    ]

    /// Filename-stem slugs from `reference/brand/specimens`, keyed by specimen ID.
    /// Example: `"L1" -> "meadow-lark"`, `"B0-sq" -> "golden-meadow-hare"`.
    private static let nameSlugsById: [String: String] = [
        "B0-hex": "sunlit-monarch",
        "B0-sq": "golden-meadow-hare",
        "B1-hex": "marshglow-orchid",
        "B1-sq": "phantom-egret",
        "B2-hex": "eternal-foxfire",
        "B2-sq": "aurora-moth",
        "B3-hex": "prismatic-ice-flower",
        "B3-sq": "crystal-stag",
        "B4-hex": "living-stone-rose",
        "B4-sq": "golden-fossil-dragonfly",
        "B5-hex": "crystalline-fungal-bloom",
        "B5-sq": "albino-cave-salamander",
        "B6-hex": "giant-pearl-oyster",
        "B6-sq": "opalescent-seahorse",
        "B7-hex": "midnight-bloom-cactus",
        "B7-sq": "golden-desert-tortoise",
        "B8-hex": "the-archivist",
        "B8-sq": "the-confluent",
        "L1": "meadow-lark",
        "L2": "clover-beetle",
        "L3": "field-mouse",
        "L4": "buttercup",
        "L5": "harvest-spider",
        "L6": "dandelion-puff",
        "L7": "marsh-frog",
        "L8": "bog-orchid",
        "L9": "mud-newt",
        "L10": "rushlight-moth",
        "L11": "swamp-lily",
        "L12": "peat-crawler",
        "L13": "misty-heron",
        "L14": "sphagnum-tuft",
        "L15": "glow-beetle",
        "L16": "foxfire-mushroom",
        "L17": "lantern-moth",
        "L18": "moonpetal-fern",
        "L19": "spark-firefly",
        "L20": "luminous-bracket-fungus",
        "L21": "nightcap-toadstool",
        "L22": "ghost-orchid",
        "L23": "snow-hare",
        "L24": "frost-fern",
        "L25": "ice-wren",
        "L26": "crystal-lichen",
        "L27": "ermine",
        "L28": "snowbell-flower",
        "L29": "glacier-beetle",
        "L30": "silver-birch-sprig",
        "L31": "amber-ant",
        "L32": "temple-moss",
        "L33": "fossil-trilobite",
        "L34": "crumbling-lichen",
        "L35": "stone-centipede",
        "L36": "wall-fern",
        "L37": "petrified-scarab",
        "L38": "pillar-ivy",
        "L39": "cave-bat",
        "L40": "grotto-mushroom",
        "L41": "blind-cavefish",
        "L42": "stalactite-lichen",
        "L43": "cavern-cricket",
        "L44": "mineral-fungus",
        "L45": "echo-moth",
        "L46": "drip-moss",
        "L47": "tide-pool-crab",
        "L48": "sea-lavender",
        "L49": "hermit-snail",
        "L50": "pink-coral-sprig",
        "L51": "starfish",
        "L52": "shore-thistle",
        "L53": "kelp-shrimp",
        "L54": "sand-dollar",
        "L55": "desert-scorpion",
        "L56": "barrel-cactus",
        "L57": "sand-viper",
        "L58": "prickly-pear-bloom",
        "L59": "dune-beetle",
        "L60": "ghost-agave",
        "L61": "sidewinder-lizard",
        "L62": "tumbleweed",
        "L63": "marsh-firefly",
        "L64": "frozen-orchid",
        "L65": "coral-fern",
        "L66": "cave-crab",
        "L67": "dune-heron",
        "L68": "ruin-moth",
        "L69": "glacial-anemone",
        "L70": "luminous-bat",
        "L71": "sandstone-starfish",
        "L72": "frost-scorpion",
        "L73": "bog-fossil",
        "L74": "desert-cave-spider",
        "L75": "copper-butterfly",
        "L76": "thistle-finch",
        "L77": "meadow-vole",
        "L78": "wild-poppy",
        "L79": "grassland-cricket",
        "L80": "foxglove",
        "L81": "fen-salamander",
        "L82": "dew-sedge",
        "L83": "mire-snail",
        "L84": "fog-lantern-lily",
        "L85": "swamp-adder",
        "L86": "marsh-pennywort",
        "L87": "bittern-chick",
        "L88": "tussock-moth",
        "L89": "ember-caterpillar",
        "L90": "starspore-lichen",
        "L91": "dusk-weevil",
        "L92": "shimmer-vine",
        "L93": "candlefly",
        "L94": "twilight-agaric",
        "L95": "glintbug",
        "L96": "undercanopy-moss",
        "L97": "arctic-fox-kit",
        "L98": "rime-orchid",
        "L99": "ice-mite",
        "L100": "frozen-dewdrop-moss",
        "L101": "ptarmigan-chick",
        "L102": "hoarfrost-gentian",
        "L103": "snow-scorpionfly",
        "L104": "winterbloom",
        "L105": "ruin-spider",
        "L106": "ancient-liverwort",
        "L107": "sandstone-cricket",
        "L108": "column-fungus",
        "L109": "buried-ammonite",
        "L110": "vault-creeper",
        "L111": "dust-mantis",
        "L112": "archway-moss",
        "L113": "tunnel-spider",
        "L114": "deep-shelf-fungus",
        "L115": "crystal-worm",
        "L116": "flowstone-lichen",
        "L117": "pale-millipede",
        "L118": "cavern-bell-cap",
        "L119": "abyss-beetle",
        "L120": "underground-coral",
        "L121": "blue-anemone",
        "L122": "dune-grass-tuft",
        "L123": "cowrie-shell",
        "L124": "brain-coral",
        "L125": "sea-urchin",
        "L126": "coastal-daisy",
        "L127": "mantis-shrimp",
        "L128": "saltmarsh-reed",
        "L129": "horned-toad",
        "L130": "saguaro-flower",
        "L131": "sand-wasp",
        "L132": "desert-marigold",
        "L133": "fennec-fox-kit",
        "L134": "joshua-tree-sprig",
        "L135": "camel-spider",
        "L136": "sunstone-succulent",
        "L137": "tidal-firefly",
        "L138": "frozen-centipede",
        "L139": "marsh-crystal",
        "L140": "cavern-cactus",
        "L141": "luminous-coral",
        "L142": "sand-hare",
        "L143": "mossy-stalactite",
        "L144": "glowing-marsh-orchid",
        "L145": "ice-shore-crab",
        "L146": "temple-bat",
        "L147": "desert-foxfire",
        "L148": "delta-meadow-bloom",
    ]

    private static func displayName(for specimenId: String) -> String {
        guard let slug = nameSlugsById[specimenId] else { return specimenId }
        return slug
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    // MARK: - Builder

    /// Builds the complete ordered list of all 166 specimens.
    private static func buildAll() -> [Specimen] {
        var specimens: [Specimen] = []
        specimens.reserveCapacity(166)

        for biomeId in 0...8 {
            let sqRange     = squareLevelRanges[biomeId]
            let hexRange    = hexLevelRanges[biomeId]

            // ── Square level specimens ──────────────────────────────────
            for levelNumber in sqRange {
                let levelId = "L\(levelNumber)"
                specimens.append(Specimen(
                    id:         levelId,
                    name:       displayName(for: levelId),
                    imageName:  imageName(for: levelId),
                    biomeId:    biomeId,
                    isRare:     false,
                    levelId:    levelId,
                    isHex:      false
                ))
            }

            // ── Hex level specimens ─────────────────────────────────────
            for levelNumber in hexRange {
                let levelId = "L\(levelNumber)"
                specimens.append(Specimen(
                    id:         levelId,
                    name:       displayName(for: levelId),
                    imageName:  imageName(for: levelId),
                    biomeId:    biomeId,
                    isRare:     false,
                    levelId:    levelId,
                    isHex:      true
                ))
            }

            // ── Square rare specimen ────────────────────────────────────
            let squareRareId = "B\(biomeId)-sq"
            specimens.append(Specimen(
                id:         squareRareId,
                name:       displayName(for: squareRareId),
                imageName:  imageName(for: squareRareId),
                biomeId:    biomeId,
                isRare:     true,
                levelId:    nil,
                isHex:      false
            ))

            // ── Hex rare specimen ───────────────────────────────────────
            let hexRareId = "B\(biomeId)-hex"
            specimens.append(Specimen(
                id:         hexRareId,
                name:       displayName(for: hexRareId),
                imageName:  imageName(for: hexRareId),
                biomeId:    biomeId,
                isRare:     true,
                levelId:    nil,
                isHex:      true
            ))
        }

        return specimens
    }
}
