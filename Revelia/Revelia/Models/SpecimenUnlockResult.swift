// Revelia/Models/SpecimenUnlockResult.swift
//
// Communicates to EndOfLevelView what specimen unlock happened during a winning run.
// Computed in GameView immediately on the .won state change — before EndOfLevelView's
// onAppear — so the correct animation state is ready when the card first renders.
//
// Timing note: the unlock (specimenStore.unlock) happens AFTER isAlreadyCollected is
// checked, so .newDiscovery always means "the player did not already own this specimen."

import Foundation

/// Describes the specimen outcome of a completed level.
/// Passed from GameView → EndOfLevelView at the moment of win.
enum SpecimenUnlockResult: Equatable {

    /// Fewer than 3 stars — no specimen awarded.
    /// The victory screen shows a faint static "?" silhouette as a teaser.
    case none

    /// 3 stars earned, but this specimen was already in the collection.
    /// Shows the specimen image with no animation — confirms the player already has it.
    case alreadyCollected(specimen: Specimen)

    /// 3 stars earned and this is a brand-new unlock.
    /// `rare` is non-nil when this level's unlock also triggered the biome rare specimen.
    /// The victory screen plays the burst reveal animation.
    case newDiscovery(specimen: Specimen, rare: Specimen?)

    // MARK: - Equatable

    static func == (lhs: SpecimenUnlockResult, rhs: SpecimenUnlockResult) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.alreadyCollected(let a), .alreadyCollected(let b)):
            return a.id == b.id
        case (.newDiscovery(let a, let ar), .newDiscovery(let b, let br)):
            return a.id == b.id && ar?.id == br?.id
        default:
            return false
        }
    }
}
