//
//  ReveliaTests.swift
//  ReveliaTests
//
//  Created by Greg on 3/3/26.
//

import XCTest
@testable import Revelia

final class ReveliaTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLeaderboardRanksByScoreThenTimeAndKeepsDuplicates() throws {
        let store = LeaderboardStore()
        store.resetAllLeaderboards()

        _ = store.recordWinningRun(levelId: "L1", score: 100_000, timeSeconds: 90)
        _ = store.recordWinningRun(levelId: "L1", score: 120_000, timeSeconds: 95)
        _ = store.recordWinningRun(levelId: "L1", score: 120_000, timeSeconds: 80)
        _ = store.recordWinningRun(levelId: "L1", score: 120_000, timeSeconds: 80)

        let entries = store.entries(for: "L1")

        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].score, 120_000)
        XCTAssertEqual(entries[0].timeSeconds, 80)
        XCTAssertEqual(entries[1].score, 120_000)
        XCTAssertEqual(entries[1].timeSeconds, 80)
        XCTAssertEqual(entries[2].score, 120_000)
        XCTAssertEqual(entries[2].timeSeconds, 95)
        XCTAssertEqual(entries[3].score, 100_000)
    }

    @MainActor
    func testLeaderboardKeepsOnlyTopTenVisibleEntries() throws {
        let store = LeaderboardStore()
        store.resetAllLeaderboards()

        for index in 0..<12 {
            _ = store.recordWinningRun(
                levelId: "L2",
                score: 200_000 - (index * 1_000),
                timeSeconds: Double(index + 30)
            )
        }

        let entries = store.entries(for: "L2")

        XCTAssertEqual(entries.count, 10)
        XCTAssertEqual(entries.first?.score, 200_000)
        XCTAssertEqual(entries.last?.score, 191_000)
    }

}
