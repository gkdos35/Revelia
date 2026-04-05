// Revelia/Persistence/SuspendedRunStore.swift

import Foundation

@MainActor
final class SuspendedRunStore {
    private(set) var currentRun: SuspendedRun?

    private let saveURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = appSupport.appendingPathComponent("Revelia", isDirectory: true)
        saveURL = folder.appendingPathComponent("suspended-run.json")
        load()
    }

    var hasSuspendedRun: Bool {
        currentRun != nil
    }

    func save(_ run: SuspendedRun) {
        currentRun = run
        persist()
    }

    func clear() {
        currentRun = nil
        try? FileManager.default.removeItem(at: saveURL)
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: saveURL),
            let run = try? JSONDecoder().decode(SuspendedRun.self, from: data),
            run.schemaVersion == SuspendedRun.currentSchemaVersion
        else {
            currentRun = nil
            return
        }

        currentRun = run
    }

    private func persist() {
        guard let currentRun else {
            try? FileManager.default.removeItem(at: saveURL)
            return
        }

        let directory = saveURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let encoded = try? JSONEncoder().encode(currentRun) else { return }
        try? encoded.write(to: saveURL, options: .atomic)
    }
}
