// Signalfield/Persistence/SettingsStore.swift
//
// App-level settings, persisted to Application Support as settings.json.
// Injected at app launch as @EnvironmentObject alongside ProgressStore.

import Foundation
import Combine

// MARK: - SettingsStore

final class SettingsStore: ObservableObject {

    // MARK: Published settings

    @Published var soundEnabled: Bool = true {
        didSet { save() }
    }

    /// Biome IDs whose mechanic intro the player has dismissed with "Don't show again".
    /// Square and hex campaigns track independently — biome 1 (square) and biome 10
    /// (hex Fog Marsh) are stored as separate IDs so each campaign's intro can be
    /// shown once.
    @Published var shownBiomeIntros: [Int] = [] {
        didSet { save() }
    }

    // MARK: - Persistence

    private static let fileName = "settings.json"

    private static var fileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Signalfield", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    // MARK: - Codable snapshot

    private struct Snapshot: Codable {
        var soundEnabled: Bool
        var shownBiomeIntros: [Int]?    // optional so old settings.json (pre-1.1) still decodes
    }

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Load / Save

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        soundEnabled      = snapshot.soundEnabled
        shownBiomeIntros  = snapshot.shownBiomeIntros ?? []
    }

    private func save() {
        let snapshot = Snapshot(soundEnabled: soundEnabled, shownBiomeIntros: shownBiomeIntros)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    // MARK: - Biome intro helpers

    /// Records that the player has chosen "Don't show again" for this biome's intro.
    func markBiomeIntroShown(_ biomeId: Int) {
        guard !shownBiomeIntros.contains(biomeId) else { return }
        shownBiomeIntros.append(biomeId)
    }

    /// True when the mechanic intro for this biome should be suppressed.
    func isBiomeIntroSuppressed(_ biomeId: Int) -> Bool {
        shownBiomeIntros.contains(biomeId)
    }
}
