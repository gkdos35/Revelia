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

        soundEnabled = snapshot.soundEnabled
    }

    private func save() {
        let snapshot = Snapshot(soundEnabled: soundEnabled)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
