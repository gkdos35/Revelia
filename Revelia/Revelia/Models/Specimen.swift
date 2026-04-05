// Revelia/Models/Specimen.swift
//
// Value type representing a single collectible specimen.
// The catalog of what exists is defined in Data/SpecimenCatalog.swift.
// Which specimens have been unlocked is tracked in Persistence/SpecimenStore.swift.

import Foundation

/// A single collectible specimen in the Specimen Collection meta-reward system.
///
/// There are 166 specimens total:
/// - 148 level specimens — one unlocked by earning 3 stars on each level.
/// - 18 rare specimens — one per biome per campaign (9 biomes × 2 campaigns = 18),
///   unlocked by earning 3 stars on every level in a biome.
///
/// Specimens are defined statically in `SpecimenCatalog.all` and never change at runtime.
/// Unlock state is tracked separately in `SpecimenStore`.
struct Specimen: Codable, Identifiable {

    /// Unique identifier.
    ///
    /// - Level specimens: matches the level ID, e.g. `"L1"`, `"L75"`, `"L148"`.
    /// - Rare specimens: `"B0-sq"` through `"B8-sq"` (square campaign rares),
    ///   `"B0-hex"` through `"B8-hex"` (hex campaign rares).
    let id: String

    /// Human-readable display name.
    ///
    /// Sourced from the canonical specimen illustration filenames in
    /// `reference/brand/specimens`, converted into title case.
    /// Examples: `"Meadow Lark"`, `"Ghost Orchid"`, `"Golden Meadow Hare"`.
    let name: String

    /// Asset catalog image name for the specimen illustration.
    /// All specimens default to `"specimen-placeholder"` until real art is created.
    let imageName: String

    /// The biome this specimen belongs to, 0–8.
    ///
    /// Both the square and hex campaign specimens for the same biome share the same
    /// `biomeId`. Use `isHex` to distinguish campaign.
    let biomeId: Int

    /// `true` for biome-completion rare specimens; `false` for level specimens.
    let isRare: Bool

    /// The level ID whose 3-star completion unlocks this specimen.
    ///
    /// `"L1"` through `"L148"` for level specimens. `nil` for rare biome specimens
    /// (those are unlocked by `SpecimenStore.allLevelSpecimensUnlocked(for:isHex:)`).
    let levelId: String?

    /// `true` for hex campaign specimens (levels L75–L148 and hex rare specimens).
    /// `false` for square campaign specimens.
    let isHex: Bool
}
