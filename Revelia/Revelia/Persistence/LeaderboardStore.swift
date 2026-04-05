// Revelia/Persistence/LeaderboardStore.swift

import Combine
import Foundation

struct LeaderboardData: Codable {
    var levelEntries: [String: [LeaderboardEntry]] = [:]
}

@MainActor
final class LeaderboardStore: ObservableObject {
    @Published private(set) var data = LeaderboardData()

    private let saveURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = appSupport.appendingPathComponent("Revelia", isDirectory: true)
        saveURL = folder.appendingPathComponent("leaderboards.json")
        load()
    }

    func entries(for levelId: String) -> [LeaderboardEntry] {
        data.levelEntries[levelId] ?? []
    }

    func bestEntry(for levelId: String) -> LeaderboardEntry? {
        entries(for: levelId).first
    }

    func hasEntries(for levelId: String) -> Bool {
        !(data.levelEntries[levelId] ?? []).isEmpty
    }

    @discardableResult
    func recordWinningRun(
        levelId: String,
        score: Int,
        timeSeconds: Double,
        stars: Int? = nil,
        achievedAt: Date = Date()
    ) -> LeaderboardRecordResult {
        let previousEntries = entries(for: levelId)
        let previousFastestTime = previousEntries.map(\.timeSeconds).min()
        let newEntry = LeaderboardEntry(
            score: score,
            timeSeconds: timeSeconds,
            stars: stars,
            achievedAt: achievedAt
        )

        var levelEntries = previousEntries
        levelEntries.append(newEntry)
        levelEntries.sort(by: Self.isHigherRanked(_:_:))

        let insertedIndex = levelEntries.firstIndex(where: { $0.id == newEntry.id })
        let topTen = Array(levelEntries.prefix(10))
        data.levelEntries[levelId] = topTen
        save()

        return LeaderboardRecordResult(
            bestEntry: topTen[0],
            insertedRank: insertedIndex.flatMap { $0 < 10 ? ($0 + 1) : nil },
            isNewNumberOne: topTen.first?.id == newEntry.id,
            isFirstRecordedWin: previousEntries.isEmpty,
            isNewBestTime: previousFastestTime.map { timeSeconds < $0 } ?? true
        )
    }

    func resetAllLeaderboards() {
        data = LeaderboardData()
        try? FileManager.default.removeItem(at: saveURL)
    }

    private func load() {
        guard
            let rawData = try? Data(contentsOf: saveURL),
            let decoded = try? JSONDecoder().decode(LeaderboardData.self, from: rawData)
        else { return }

        data.levelEntries = decoded.levelEntries.mapValues {
            Array($0.sorted(by: Self.isHigherRanked(_:_:)).prefix(10))
        }
    }

    private func save() {
        let directory = saveURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: saveURL, options: .atomic)
    }

    private static func isHigherRanked(_ lhs: LeaderboardEntry, _ rhs: LeaderboardEntry) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.timeSeconds != rhs.timeSeconds {
            return lhs.timeSeconds < rhs.timeSeconds
        }
        if lhs.achievedAt != rhs.achievedAt {
            return lhs.achievedAt < rhs.achievedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
