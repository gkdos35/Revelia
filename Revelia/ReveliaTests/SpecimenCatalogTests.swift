// ReveliaTests/SpecimenCatalogTests.swift
//
// Verification tests for the Specimen data model, SpecimenCatalog, and SpecimenStore.
// Run these after adding the new files to the Xcode target.

import XCTest
@testable import Revelia

final class SpecimenCatalogTests: XCTestCase {

    // MARK: - SpecimenCatalog: Total Count

    func testTotalSpecimenCount() {
        XCTAssertEqual(SpecimenCatalog.all.count, 166,
            "Expected 166 total specimens (148 level + 18 rare)")
    }

    // MARK: - SpecimenCatalog: Unique IDs

    func testAllSpecimenIdsAreUnique() {
        let ids = SpecimenCatalog.all.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count,
            "All specimen IDs must be unique — found \(ids.count - uniqueIds.count) duplicates")
    }

    // MARK: - SpecimenCatalog: Per-Biome Counts

    func testBiome0Count() {
        // Biome 0 (Training Range): 6 sq + 6 hex + 2 rare = 14
        XCTAssertEqual(SpecimenCatalog.specimens(for: 0).count, 14)
    }

    func testBiomes1Through7Count() {
        // Biomes 1–7: 8 sq + 8 hex + 2 rare = 18 each
        for biomeId in 1...7 {
            XCTAssertEqual(SpecimenCatalog.specimens(for: biomeId).count, 18,
                "Biome \(biomeId) should have 18 specimens")
        }
    }

    func testBiome8Count() {
        // Biome 8 (The Delta): 12 sq + 12 hex + 2 rare = 26
        XCTAssertEqual(SpecimenCatalog.specimens(for: 8).count, 26)
    }

    func testTotalAcrossBiomesMatchesAll() {
        let sumAcrossBiomes = (0...8).map { SpecimenCatalog.specimens(for: $0).count }.reduce(0, +)
        XCTAssertEqual(sumAcrossBiomes, 166,
            "Sum of per-biome counts must equal 166 total")
    }

    // MARK: - SpecimenCatalog: Level Specimen Lookups

    func testSpecimenForL1UsesRealSpecimenName() {
        let s = SpecimenCatalog.specimen(for: "L1")
        XCTAssertNotNil(s, "L1 should have a specimen")
        XCTAssertEqual(s?.name, "Meadow Lark")
        XCTAssertEqual(s?.biomeId, 0)
        XCTAssertFalse(s?.isHex ?? true, "L1 is a square level")
        XCTAssertFalse(s?.isRare ?? true, "L1 specimen is not rare")
        XCTAssertEqual(s?.levelId, "L1")
    }

    func testSpecimenForL6UsesRealSpecimenName() {
        let s = SpecimenCatalog.specimen(for: "L6")
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.name, "Dandelion Puff")
        XCTAssertEqual(s?.biomeId, 0)
        XCTAssertFalse(s?.isHex ?? true)
    }

    func testSpecimenForL75UsesRealSpecimenName() {
        let s = SpecimenCatalog.specimen(for: "L75")
        XCTAssertNotNil(s, "L75 should have a specimen")
        XCTAssertEqual(s?.name, "Copper Butterfly")
        XCTAssertEqual(s?.biomeId, 0)
        XCTAssertTrue(s?.isHex ?? false, "L75 is a hex level")
        XCTAssertFalse(s?.isRare ?? true)
    }

    func testSpecimenForL80UsesRealSpecimenName() {
        let s = SpecimenCatalog.specimen(for: "L80")
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.name, "Foxglove")
        XCTAssertEqual(s?.biomeId, 0)
        XCTAssertTrue(s?.isHex ?? false)
    }

    func testSpecimenForL148UsesRealSpecimenName() {
        let s = SpecimenCatalog.specimen(for: "L148")
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.biomeId, 8)
        XCTAssertTrue(s?.isHex ?? false)
        XCTAssertEqual(s?.name, "Delta Meadow Bloom")
        XCTAssertFalse(s?.isRare ?? true)
    }

    func testUnrecognisedLevelIdReturnsNil() {
        XCTAssertNil(SpecimenCatalog.specimen(for: "L0"))
        XCTAssertNil(SpecimenCatalog.specimen(for: "L149"))
        XCTAssertNil(SpecimenCatalog.specimen(for: ""))
        XCTAssertNil(SpecimenCatalog.specimen(for: "B0-sq"))
    }

    // MARK: - SpecimenCatalog: Rare Specimen Lookups

    func testSquareRareSpecimenBiome0() {
        let s = SpecimenCatalog.rareSpecimen(for: 0, isHex: false)
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.id, "B0-sq")
        XCTAssertEqual(s?.name, "Golden Meadow Hare")
        XCTAssertEqual(s?.biomeId, 0)
        XCTAssertTrue(s?.isRare ?? false)
        XCTAssertFalse(s?.isHex ?? true)
        XCTAssertNil(s?.levelId, "Rare specimens have no levelId")
    }

    func testHexRareSpecimenBiome0() {
        let s = SpecimenCatalog.rareSpecimen(for: 0, isHex: true)
        XCTAssertNotNil(s)
        XCTAssertEqual(s?.id, "B0-hex")
        XCTAssertEqual(s?.name, "Sunlit Monarch")
        XCTAssertEqual(s?.biomeId, 0)
        XCTAssertTrue(s?.isRare ?? false)
        XCTAssertTrue(s?.isHex ?? false)
        XCTAssertNil(s?.levelId)
    }

    func testRealNamesComeFromCanonicalSpecimenArtFilenames() {
        XCTAssertEqual(SpecimenCatalog.specimen(for: "L22")?.name, "Ghost Orchid")
        XCTAssertEqual(SpecimenCatalog.rareSpecimen(for: 8, isHex: false)?.name, "The Confluent")
        XCTAssertEqual(SpecimenCatalog.rareSpecimen(for: 8, isHex: true)?.name, "The Archivist")
    }

    func testAllBiomesHaveBothRareSpecimens() {
        for biomeId in 0...8 {
            XCTAssertNotNil(SpecimenCatalog.rareSpecimen(for: biomeId, isHex: false),
                "Biome \(biomeId) missing square rare specimen")
            XCTAssertNotNil(SpecimenCatalog.rareSpecimen(for: biomeId, isHex: true),
                "Biome \(biomeId) missing hex rare specimen")
        }
    }

    func testAllRareSpecimensHaveNilLevelId() {
        let rares = SpecimenCatalog.all.filter { $0.isRare }
        XCTAssertEqual(rares.count, 18, "Expected 18 rare specimens (9 biomes × 2 campaigns)")
        for r in rares {
            XCTAssertNil(r.levelId, "Rare specimen \(r.id) should have nil levelId")
        }
    }

    // MARK: - SpecimenCatalog: imageName

    func testAllSpecimensUseStableAssetNames() {
        let wrongImages = SpecimenCatalog.all.filter {
            $0.imageName != SpecimenCatalog.imageName(for: $0.id)
        }
        let mismatchDescriptions = wrongImages.map { "\($0.id)=\($0.imageName)" }
        XCTAssertTrue(wrongImages.isEmpty,
            "Every specimen should resolve to the stable asset name pattern. " +
            "Found \(wrongImages.count) mismatches: \(mismatchDescriptions)")
    }

    func testKnownImageNames() {
        XCTAssertEqual(SpecimenCatalog.specimen(for: "L1")?.imageName, "specimen-L1")
        XCTAssertEqual(SpecimenCatalog.specimen(for: "L148")?.imageName, "specimen-L148")
        XCTAssertEqual(
            SpecimenCatalog.rareSpecimen(for: 0, isHex: false)?.imageName,
            "specimen-B0-sq"
        )
        XCTAssertEqual(
            SpecimenCatalog.rareSpecimen(for: 8, isHex: true)?.imageName,
            "specimen-B8-hex"
        )
    }

    // MARK: - SpecimenCatalog: isHex consistency

    func testSquareLevelSpecimensAreNotHex() {
        // Levels L1–L74 should all have isHex = false
        for n in 1...74 {
            let s = SpecimenCatalog.specimen(for: "L\(n)")
            XCTAssertNotNil(s, "L\(n) should exist in catalog")
            XCTAssertFalse(s?.isHex ?? true, "L\(n) should have isHex = false")
        }
    }

    func testHexLevelSpecimensAreHex() {
        // Levels L75–L148 should all have isHex = true
        for n in 75...148 {
            let s = SpecimenCatalog.specimen(for: "L\(n)")
            XCTAssertNotNil(s, "L\(n) should exist in catalog")
            XCTAssertTrue(s?.isHex ?? false, "L\(n) should have isHex = true")
        }
    }

    // MARK: - SpecimenStore: Unlock / Save / Load Round-Trip

    /// Creates a SpecimenStore backed by a throw-away temp file so tests
    /// never touch real Application Support data.
    @MainActor
    private func makeTempStore() -> SpecimenStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sf-specimens-test-\(UUID().uuidString).json")
        return SpecimenStore(saveURL: url)
    }

    @MainActor
    func testSpecimenStoreUnlockAndQuery() {
        let store = makeTempStore()
        XCTAssertFalse(store.isUnlocked("L1"), "Fresh store should have nothing unlocked")

        store.unlock("L1")
        XCTAssertTrue(store.isUnlocked("L1"))
        XCTAssertFalse(store.isUnlocked("L2"))
        XCTAssertEqual(store.unlockedSpecimenIds.count, 1)
    }

    @MainActor
    func testSpecimenStoreUnlockIsIdempotent() {
        let store = makeTempStore()
        store.unlock("L1")
        store.unlock("L1")   // second call should be a no-op
        XCTAssertEqual(store.unlockedSpecimenIds.count, 1)
    }

    @MainActor
    func testSpecimenStoreSaveAndReload() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sf-specimens-roundtrip-\(UUID().uuidString).json")

        let store1 = SpecimenStore(saveURL: url)
        store1.unlock("L1")
        store1.unlock("L42")
        store1.save()

        // Second store reads the same file
        let store2 = SpecimenStore(saveURL: url)
        XCTAssertTrue(store2.isUnlocked("L1"),  "L1 should survive save/load round-trip")
        XCTAssertTrue(store2.isUnlocked("L42"), "L42 should survive save/load round-trip")
        XCTAssertFalse(store2.isUnlocked("L2"), "L2 was never unlocked")

        try FileManager.default.removeItem(at: url)
    }

    @MainActor
    func testUnlockedCountForBiome() {
        let store = makeTempStore()
        // Unlock the first 3 Training Range square specimens (L1, L2, L3)
        store.unlock("L1")
        store.unlock("L2")
        store.unlock("L3")
        // Unlock a Fog Marsh specimen (L7) — must NOT count toward biome 0
        store.unlock("L7")

        XCTAssertEqual(store.unlockedCount(for: 0), 3,
            "Biome 0 should report 3 unlocked (only Training Range specimens count)")
        XCTAssertEqual(store.unlockedCount(for: 1), 1,
            "Biome 1 should report 1 unlocked")
    }

    @MainActor
    func testAllLevelSpecimensUnlocked() {
        let store = makeTempStore()

        // Unlock all square Training Range level specimens (L1–L6)
        for n in 1...6 { store.unlock("L\(n)") }

        XCTAssertTrue(store.allLevelSpecimensUnlocked(for: 0, isHex: false),
            "All square Biome 0 level specimens are unlocked")
        XCTAssertFalse(store.allLevelSpecimensUnlocked(for: 0, isHex: true),
            "Hex Biome 0 level specimens are NOT all unlocked yet")

        // Unlock all hex Training Range level specimens (L75–L80)
        for n in 75...80 { store.unlock("L\(n)") }

        XCTAssertTrue(store.allLevelSpecimensUnlocked(for: 0, isHex: true),
            "All hex Biome 0 level specimens are now unlocked")
    }
}
