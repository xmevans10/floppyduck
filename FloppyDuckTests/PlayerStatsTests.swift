import XCTest
@testable import FloppyDuck

final class PlayerStatsTests: XCTestCase {

    // MARK: - Existing Tests

    func testLegacyPlayerStatsDecodeDefaultsPeakAndStreakFields() throws {
        let stats = try decodePlayerStats("""
        {
          "gamesPlayed": 8,
          "wins": 5,
          "losses": 3,
          "bestScore": 27,
          "totalScore": 90,
          "elo": 1342,
          "bread": 44,
          "totalBreadCollected": 61,
          "recentScores": [12, 9],
          "beatenBots": ["quackers"]
        }
        """)

        XCTAssertEqual(stats.gamesPlayed, 8)
        XCTAssertEqual(stats.peakElo, 1342)
        XCTAssertEqual(stats.winStreak, 0)
        XCTAssertEqual(stats.bestWinStreak, 0)
    }

    func testLegacyPlayerStatsDecodeKeepsCurrentWinStreakAsBestWhenMissing() throws {
        let stats = try decodePlayerStats("""
        {
          "gamesPlayed": 4,
          "wins": 3,
          "losses": 1,
          "bestScore": 14,
          "totalScore": 39,
          "elo": 1280,
          "bread": 20,
          "totalBreadCollected": 20,
          "recentScores": [14, 11, 8, 6],
          "beatenBots": [],
          "winStreak": 3
        }
        """)

        XCTAssertEqual(stats.winStreak, 3)
        XCTAssertEqual(stats.bestWinStreak, 3)
        XCTAssertEqual(stats.peakElo, 1280)
    }

    func testLegacyLocalStatsSnapshotDecodeDefaultsNewFields() throws {
        let snapshot = try decodeLocalStatsSnapshot("""
        {
          "username": "Legacy Duck",
          "gamesPlayed": 6,
          "wins": 4,
          "losses": 2,
          "bestScore": 19,
          "totalScore": 56,
          "elo": 1391,
          "bread": 18,
          "totalBreadCollected": 25,
          "recentScores": [7, 9, 11],
          "beatenBots": ["quackers", "waddles"]
        }
        """)

        XCTAssertEqual(snapshot.username, "Legacy Duck")
        XCTAssertEqual(snapshot.peakElo, 1391)
        XCTAssertEqual(snapshot.winStreak, 0)
        XCTAssertEqual(snapshot.bestWinStreak, 0)
        XCTAssertEqual(snapshot.asPlayerStats.peakElo, 1391)
    }

    func testLocalStatsSnapshotDictionaryIncludesPeakAndStreakFields() {
        let snapshot = LocalStatsSnapshot(
            username: "CloudDuck",
            stats: PlayerStats(elo: 1320, peakElo: 1455, winStreak: 2, bestWinStreak: 4)
        )

        XCTAssertEqual(snapshot.asDictionary["peakElo"] as? Int, 1455)
        XCTAssertEqual(snapshot.asDictionary["winStreak"] as? Int, 2)
        XCTAssertEqual(snapshot.asDictionary["bestWinStreak"] as? Int, 4)
    }

    func testRemoteStatsParserReadsNewFields() {
        let stats = ConvexClient.parsePlayerStats(from: [
            "games_played": 11,
            "wins": 7,
            "losses": 4,
            "best_score": 33,
            "total_score": 123,
            "rating": 1410,
            "bread": 28,
            "total_bread_collected": 74,
            "recent_scores": [6, 8, 12],
            "beaten_bots": ["quackers", "waddles"],
            "peak_elo": 1502,
            "win_streak": 3,
            "best_win_streak": 7
        ])

        XCTAssertEqual(stats.elo, 1410)
        XCTAssertEqual(stats.peakElo, 1502)
        XCTAssertEqual(stats.winStreak, 3)
        XCTAssertEqual(stats.bestWinStreak, 7)
        XCTAssertEqual(stats.beatenBots, ["quackers", "waddles"])
    }

    func testRemoteStatsParserDefaultsMissingNewFieldsSafely() {
        let stats = ConvexClient.parsePlayerStats(from: [
            "gamesPlayed": 5,
            "wins": 3,
            "losses": 2,
            "bestScore": 18,
            "totalScore": 50,
            "elo": 1333,
            "winStreak": 2
        ])

        XCTAssertEqual(stats.peakElo, 1333)
        XCTAssertEqual(stats.winStreak, 2)
        XCTAssertEqual(stats.bestWinStreak, 2)
    }

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
        XCTAssertEqual(stats.peakElo, 1242)
        XCTAssertEqual(stats.winStreak, 1)
        XCTAssertEqual(stats.bestWinStreak, 1)
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

    func testApplyPendingMatchResultDoesNotChangeStats() {
        var stats = PlayerStats(gamesPlayed: 3, wins: 2, losses: 1, bestScore: 12, totalScore: 30, elo: 1210, bread: 20)

        let pending = MultiplayerMatchResult(
            matchId: "pending-match",
            mode: .ranked,
            opponentName: "Opponent",
            localScore: 14,
            opponentScore: 9,
            didWin: true,
            didDraw: false,
            ratingDelta: 18,
            newRating: 1228,
            isRanked: true,
            isFinalized: false
        )

        stats.applyMatchResult(pending)

        XCTAssertEqual(stats.gamesPlayed, 3)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.losses, 1)
        XCTAssertEqual(stats.bestScore, 12)
        XCTAssertEqual(stats.totalScore, 30)
        XCTAssertEqual(stats.elo, 1210)
        XCTAssertEqual(stats.bread, 20)
    }

    @MainActor
    func testRemoteProfilePreservesHigherLocalTotalBreadCollected() {
        let localStats = PlayerStats(totalBreadCollected: 125)
        let manager = GameManager(initialStats: localStats)
        let remoteProfile = RemotePlayerProfile(
            userId: "remote-user",
            username: "CloudDuck",
            provider: .guest,
            stats: PlayerStats(totalBreadCollected: 0)
        )

        manager.applyRemoteProfile(remoteProfile)

        XCTAssertEqual(manager.stats.totalBreadCollected, 125)
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

    func testRecordGameAddsCollectedBreadToSpendableBalance() {
        var stats = PlayerStats()

        stats.recordGame(score: 7, collectedBread: 4)

        XCTAssertEqual(stats.bread, 11)
        XCTAssertEqual(stats.totalBreadCollected, 11)
    }

    func testBreadEconomyUsesSameScoreRewardFormula() {
        XCTAssertEqual(BreadEconomy.scoreReward(score: 10, won: true), 10)
        XCTAssertEqual(BreadEconomy.scoreReward(score: 10, won: false), 5)
        XCTAssertEqual(BreadEconomy.scoreReward(score: 0, won: nil), 1)
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
        XCTAssertEqual(stats.peakElo, 1225)
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

    func testWinStreakAndBestWinStreakAcrossMatchFlows() {
        var stats = PlayerStats()

        stats.recordGame(score: 5, won: true)
        XCTAssertEqual(stats.winStreak, 1)
        XCTAssertEqual(stats.bestWinStreak, 1)

        let draw = MultiplayerMatchResult(
            matchId: "draw",
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
        stats.applyMatchResult(draw)
        XCTAssertEqual(stats.winStreak, 1)
        XCTAssertEqual(stats.bestWinStreak, 1)

        let rankedWin = MultiplayerMatchResult(
            matchId: "ranked-win",
            mode: .ranked,
            opponentName: "Opponent",
            localScore: 12,
            opponentScore: 8,
            didWin: true,
            didDraw: false,
            ratingDelta: 24,
            newRating: 1244,
            isRanked: true
        )
        stats.applyMatchResult(rankedWin)
        XCTAssertEqual(stats.winStreak, 2)
        XCTAssertEqual(stats.bestWinStreak, 2)
        XCTAssertEqual(stats.peakElo, 1244)

        let rankedLoss = MultiplayerMatchResult(
            matchId: "ranked-loss",
            mode: .ranked,
            opponentName: "Opponent",
            localScore: 7,
            opponentScore: 10,
            didWin: false,
            didDraw: false,
            ratingDelta: -30,
            newRating: 1214,
            isRanked: true
        )
        stats.applyMatchResult(rankedLoss)
        XCTAssertEqual(stats.winStreak, 0)
        XCTAssertEqual(stats.bestWinStreak, 2)
        XCTAssertEqual(stats.peakElo, 1244)

        stats.recordGame(score: 6, won: true)
        stats.recordGame(score: 8, won: true)
        XCTAssertEqual(stats.winStreak, 2)
        XCTAssertEqual(stats.bestWinStreak, 2)

        stats.recordGame(score: 10, won: true)
        XCTAssertEqual(stats.winStreak, 3)
        XCTAssertEqual(stats.bestWinStreak, 3)
    }
}

private func decodePlayerStats(_ json: String) throws -> PlayerStats {
    try JSONDecoder().decode(PlayerStats.self, from: Data(json.utf8))
}

private func decodeLocalStatsSnapshot(_ json: String) throws -> LocalStatsSnapshot {
    try JSONDecoder().decode(LocalStatsSnapshot.self, from: Data(json.utf8))
}
