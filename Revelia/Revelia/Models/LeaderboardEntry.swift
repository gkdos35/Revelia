// Revelia/Models/LeaderboardEntry.swift

import Foundation

struct LeaderboardEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let score: Int
    let timeSeconds: Double
    let stars: Int?
    let achievedAt: Date

    init(
        id: UUID = UUID(),
        score: Int,
        timeSeconds: Double,
        stars: Int? = nil,
        achievedAt: Date = Date()
    ) {
        self.id = id
        self.score = score
        self.timeSeconds = timeSeconds
        self.stars = stars
        self.achievedAt = achievedAt
    }
}

struct LeaderboardRecordResult: Equatable {
    let bestEntry: LeaderboardEntry
    let insertedRank: Int?
    let isNewNumberOne: Bool
    let isFirstRecordedWin: Bool
    let isNewBestTime: Bool
}

enum LeaderboardFormatting {
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let scoreFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSize = 3
        return formatter
    }()

    static func formattedScore(_ score: Int) -> String {
        scoreFormatter.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    static func formattedRunTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    static func formattedTimestamp(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }
}
