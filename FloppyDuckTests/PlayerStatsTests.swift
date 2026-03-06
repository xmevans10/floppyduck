import XCTest
@testable import FloppyDuck

final class PlayerStatsTests: XCTestCase {
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
}
