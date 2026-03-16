import XCTest
@testable import FloppyDuck

final class PlayerStatsTests: XCTestCase {

    // MARK: - Existing Tests

    func testApplyRankedResultPrefersNewRatingOverDelta() {
        var stats = PlayerStats()
        stats.elo = 1200

        let result = MultiplayerMatchResult(
            matchId: "m1",
            mode: .ranked,
            opponentName: "Opponent",
            localScore: 15,
            opponentScore: 11,
            didWin: true,
            didDraw: false,
            ratingDelta: 20,
            newRating: 1242,
            isRanked: true
        )

        stats.applyMatchResult(result)

        XCTAssertEqual(stats.elo, 1242)
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.losses, 0)
        XCTAssertEqual(stats.gamesPlayed, 1)
    }

    func testApplyDrawDoesNotAffectWinsOrLosses() {
        var stats = PlayerStats()

        let result = MultiplayerMatchResult(
            matchId: "m2",
            mode: .quickPlay,
            opponentName: "Opponent",
            localScore: 9,
            opponentScore: 9,
            didWin: false,
            didDraw: true,
            ratingDelta: nil,
            newRating: nil,
            isRanked: false
        )

        stats.applyMatchResult(result)

        XCTAssertEqual(stats.gamesPlayed, 1)
        XCTAssertEqual(stats.wins, 0)
        XCTAssertEqual(stats.losses, 0)
        XCTAssertEqual(stats.bestScore, 9)
    }

    // MARK: - recordGame Field Updates

    func testRecordGameUpdatesAllFields() {
        var stats = PlayerStats()
        stats.recordGame(score: 12, won: true)

        XCTAssertEqual(stats.gamesPlayed, 1)
        XCTAssertEqual(stats.totalScore, 12)
        XCTAssertEqual(stats.bestScore, 12)
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.recentScores, [12])
        XCTAssertGreaterThan(stats.bread, 0)
    }

    func testBestScoreOnlyIncrease() {
        var stats = PlayerStats()

        stats.recordGame(score: 20)
        XCTAssertEqual(stats.bestScore, 20)

        stats.recordGame(score: 10)
        XCTAssertEqual(stats.bestScore, 20, "bestScore should not decrease")

        stats.recordGame(score: 25)
        XCTAssertEqual(stats.bestScore, 25)
    }

    func testRecentScoresCappedAt20() {
        var stats = PlayerStats()
        for i in 1...25 {
            stats.recordGame(score: i)
        }

        XCTAssertEqual(stats.recentScores.count, 20)
        // First 5 scores (1–5) should have been evicted
        XCTAssertEqual(stats.recentScores.first, 6)
        XCTAssertEqual(stats.recentScores.last, 25)
    }

    // MARK: - Computed Properties

    func testWinRateCalculation() {
        var stats = PlayerStats()
        XCTAssertEqual(stats.winRate, 0)

        stats.recordGame(score: 10, won: true)
        stats.recordGame(score: 5, won: false)
        stats.recordGame(score: 8, won: true)
        stats.recordGame(score: 3, won: false)

        // 2 wins / 4 games = 0.5
        XCTAssertEqual(stats.winRate, 0.5, accuracy: 0.001)
    }

    func testAverageScoreCalculation() {
        var stats = PlayerStats()
        XCTAssertEqual(stats.averageScore, 0)

        stats.recordGame(score: 10)
        stats.recordGame(score: 20)
        stats.recordGame(score: 30)

        // (10 + 20 + 30) / 3 = 20
        XCTAssertEqual(stats.averageScore, 20.0, accuracy: 0.001)
    }

    // MARK: - beatBot Idempotency

    func testBeatBotIdempotent() {
        var stats = PlayerStats()
        stats.beatBot("quackers")
        stats.beatBot("quackers")

        XCTAssertEqual(stats.beatenBots.count, 1)
        XCTAssertEqual(stats.beatenBots.first, "quackers")
    }

    // MARK: - Bread Awards

    func testRecordGameWithWinAwardsBread() {
        // bread = max(3, score)
        var stats = PlayerStats()
        stats.recordGame(score: 10, won: true)
        XCTAssertEqual(stats.bread, 10, "Won with score 10 → max(3, 10) = 10 bread")

        // Low score still awards minimum 3 bread on win
        var stats2 = PlayerStats()
        stats2.recordGame(score: 1, won: true)
        XCTAssertEqual(stats2.bread, 3, "Won with score 1 → max(3, 1) = 3 bread")
    }

    func testRecordGameWithLossAwardsBread() {
        // bread = max(1, score / 2)
        var stats = PlayerStats()
        stats.recordGame(score: 10, won: false)
        XCTAssertEqual(stats.bread, 5, "Lost with score 10 → max(1, 10/2) = 5 bread")

        // Zero score still awards minimum 1 bread on loss
        var stats2 = PlayerStats()
        stats2.recordGame(score: 0, won: false)
        XCTAssertEqual(stats2.bread, 1, "Lost with score 0 → max(1, 0) = 1 bread")
    }

    func testRecordGameClassicAwardsBread() {
        // won == nil → bread = max(1, score)
        var stats = PlayerStats()
        stats.recordGame(score: 7)
        XCTAssertEqual(stats.bread, 7, "Classic score 7 → max(1, 7) = 7 bread")

        // Zero score still awards minimum 1 bread
        var stats2 = PlayerStats()
        stats2.recordGame(score: 0)
        XCTAssertEqual(stats2.bread, 1, "Classic score 0 → max(1, 0) = 1 bread")
    }

    // MARK: - ELO / Match Results

    func testApplyRankedResultWithDeltaOnly() {
        var stats = PlayerStats()
        stats.elo = 1200

        let result = MultiplayerMatchResult(
            matchId: "m3",
            mode: .ranked,
            opponentName: "Opponent",
            localScore: 12,
            opponentScore: 8,
            didWin: true,
            didDraw: false,
            ratingDelta: 25,
            newRating: nil,     // no absolute rating → fall back to delta
            isRanked: true
        )

        stats.applyMatchResult(result)

        XCTAssertEqual(stats.elo, 1225, "Should apply ratingDelta when newRating is nil")
    }

    func testApplyUnrankedResultDoesNotChangeELO() {
        var stats = PlayerStats()
        stats.elo = 1200

        let result = MultiplayerMatchResult(
            matchId: "m4",
            mode: .quickPlay,
            opponentName: "Opponent",
            localScore: 15,
            opponentScore: 10,
            didWin: true,
            didDraw: false,
            ratingDelta: 30,
            newRating: 1300,
            isRanked: false     // unranked → ELO untouched
        )

        stats.applyMatchResult(result)

        XCTAssertEqual(stats.elo, 1200, "ELO should not change for unranked matches")
    }
}
