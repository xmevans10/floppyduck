import XCTest
@testable import FloppyDuck

/// End-to-end multiplayer flow tests using mock backend.
/// Validates the full matchmaking → play → report → finish pipeline
/// that normally requires 2 devices.
final class MultiplayerFlowTests: XCTestCase {

    // MARK: - Quick Play full flow

    func testQuickPlayFullFlowQueueToFinish() async throws {
        let assignment = MultiplayerMatchAssignment(
            matchId: "qp-match-1",
            seed: 12345,
            opponentName: "DuckFoe",
            mode: .quickPlay,
            isRanked: false,
            roomCode: nil
        )

        let mock = TwoPlayerMock(queueAssignment: assignment)
        let session = MultiplayerSession(client: mock)

        // Player queues for quick play
        let match = try await session.queueForMatch(mode: .quickPlay, timeout: 3)
        XCTAssertEqual(match.matchId, "qp-match-1")
        XCTAssertEqual(match.opponentName, "DuckFoe")
        XCTAssertFalse(match.isRanked)

        // Player reports score during game
        await session.reportScore(matchId: "qp-match-1", score: 7)
        let snap = await mock.snapshot()
        XCTAssertEqual(snap.reportedScores, [("qp-match-1", 7)])

        // Player finishes match
        let result = try await session.finishMatch(
            matchId: "qp-match-1",
            score: 7,
            mode: .quickPlay,
            fallbackOpponentScore: 5,
            opponentName: "DuckFoe"
        )
        XCTAssertTrue(result.didWin)
        XCTAssertEqual(result.localScore, 7)
        XCTAssertEqual(result.opponentScore, 5)
    }

    // MARK: - Ranked match flow

    func testRankedFlowReturnsRatingDelta() async throws {
        let assignment = MultiplayerMatchAssignment(
            matchId: "ranked-1",
            seed: 999,
            opponentName: "ProDuck",
            mode: .ranked,
            isRanked: true,
            roomCode: nil
        )

        let mock = TwoPlayerMock(queueAssignment: assignment, ratingDelta: 25, newRating: 1225)
        let session = MultiplayerSession(client: mock)

        let match = try await session.queueForMatch(mode: .ranked, timeout: 3)
        XCTAssertTrue(match.isRanked)

        let result = try await session.finishMatch(
            matchId: "ranked-1",
            score: 12,
            mode: .ranked,
            fallbackOpponentScore: 8,
            opponentName: "ProDuck"
        )
        XCTAssertTrue(result.didWin)
        XCTAssertTrue(result.isRanked)
        XCTAssertEqual(result.ratingDelta, 25)
        XCTAssertEqual(result.newRating, 1225)
    }

    // MARK: - Private Room full flow

    func testPrivateRoomCreateJoinAndPlay() async throws {
        let roomAssignment = MultiplayerMatchAssignment(
            matchId: "room-match-1",
            seed: 42,
            opponentName: "Friend",
            mode: .privateRoom,
            isRanked: false,
            roomCode: "ABCDE"
        )

        let mock = TwoPlayerMock(roomAssignment: roomAssignment)
        let player1 = MultiplayerSession(client: mock)
        let player2 = MultiplayerSession(client: mock)

        // Player 1 creates room
        let code = try await player1.createPrivateRoom()
        XCTAssertEqual(code.count, GK.roomCodeLength)

        // Player 2 joins room
        try await player2.joinPrivateRoom(code: code)
        let snap = await mock.snapshot()
        XCTAssertEqual(snap.lastJoinedRoomCode, code.uppercased())

        // Wait for match from room
        let match = try await player1.waitForPrivateRoomMatch(timeout: 3)
        XCTAssertEqual(match.matchId, "room-match-1")
        XCTAssertEqual(match.opponentName, "Friend")

        // Both players finish
        let result = try await player1.finishMatch(
            matchId: "room-match-1",
            score: 10,
            mode: .privateRoom,
            fallbackOpponentScore: 6,
            opponentName: "Friend"
        )
        XCTAssertTrue(result.didWin)
        XCTAssertFalse(result.isRanked)
    }

    // MARK: - Edge cases

    func testQueueTimeoutThrowsError() async {
        // No assignment → will poll until timeout
        let mock = TwoPlayerMock(queueAssignment: nil)
        let session = MultiplayerSession(client: mock)

        do {
            _ = try await session.queueForMatch(mode: .quickPlay, timeout: 1.5)
            XCTFail("Expected timeout error")
        } catch {
            guard case MultiplayerSessionError.timeout = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testQueueingForPrivateRoomThrowsInvalidMode() async {
        let mock = TwoPlayerMock()
        let session = MultiplayerSession(client: mock)

        do {
            _ = try await session.queueForMatch(mode: .privateRoom, timeout: 2)
            XCTFail("Expected invalidMode error")
        } catch {
            guard case MultiplayerSessionError.invalidMode = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testWaitForPrivateRoomWithoutCreateThrowsInvalidMode() async {
        let mock = TwoPlayerMock()
        let session = MultiplayerSession(client: mock)

        do {
            _ = try await session.waitForPrivateRoomMatch(timeout: 2)
            XCTFail("Expected invalidMode error")
        } catch {
            guard case MultiplayerSessionError.invalidMode = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testScoreReportingIsNonFatalOnError() async {
        let mock = TwoPlayerMock(shouldFailScoreReport: true)
        let session = MultiplayerSession(client: mock)

        // Should not throw — score reporting failures are swallowed
        await session.reportScore(matchId: "match-1", score: 99)
        let snap = await mock.snapshot()
        // Report was attempted even though it failed
        XCTAssertTrue(snap.scoreReportAttempted)
    }

    func testConcurrentSessionsAreIndependent() async throws {
        let assignment1 = MultiplayerMatchAssignment(
            matchId: "m1", seed: 1, opponentName: "P2",
            mode: .quickPlay, isRanked: false, roomCode: nil
        )
        let assignment2 = MultiplayerMatchAssignment(
            matchId: "m2", seed: 2, opponentName: "P3",
            mode: .quickPlay, isRanked: false, roomCode: nil
        )

        let mock1 = TwoPlayerMock(queueAssignment: assignment1)
        let mock2 = TwoPlayerMock(queueAssignment: assignment2)
        let session1 = MultiplayerSession(client: mock1)
        let session2 = MultiplayerSession(client: mock2)

        // Both queue concurrently
        async let match1 = session1.queueForMatch(mode: .quickPlay, timeout: 3)
        async let match2 = session2.queueForMatch(mode: .quickPlay, timeout: 3)

        let (r1, r2) = try await (match1, match2)
        XCTAssertEqual(r1.matchId, "m1")
        XCTAssertEqual(r2.matchId, "m2")
    }

    func testDrawResultHasCorrectFlags() async throws {
        let assignment = MultiplayerMatchAssignment(
            matchId: "draw-1", seed: 1, opponentName: "Rival",
            mode: .quickPlay, isRanked: false, roomCode: nil
        )
        let mock = TwoPlayerMock(queueAssignment: assignment, forceDraw: true)
        let session = MultiplayerSession(client: mock)

        _ = try await session.queueForMatch(mode: .quickPlay, timeout: 3)
        let result = try await session.finishMatch(
            matchId: "draw-1",
            score: 10,
            mode: .quickPlay,
            fallbackOpponentScore: 10,
            opponentName: "Rival"
        )
        XCTAssertTrue(result.didDraw)
        XCTAssertFalse(result.didWin)
    }

    func testMatchStateFetchReturnsCurrentScores() async throws {
        let mock = TwoPlayerMock(opponentLiveScore: 8)
        let assignment = MultiplayerMatchAssignment(
            matchId: "live-1", seed: 1, opponentName: "Live",
            mode: .quickPlay, isRanked: false, roomCode: nil
        )
        let mock2 = TwoPlayerMock(queueAssignment: assignment, opponentLiveScore: 8)
        let session = MultiplayerSession(client: mock2)

        _ = try await session.queueForMatch(mode: .quickPlay, timeout: 3)
        let state = try await session.fetchMatchState(matchId: "live-1")
        XCTAssertEqual(state.matchId, "live-1")
        XCTAssertEqual(state.opponentScore, 8)
        XCTAssertFalse(state.isFinished)
    }

    func testLeaderboardReturnsSortedEntries() async throws {
        let mock = TwoPlayerMock(leaderboardEntries: [
            LeaderboardEntry(id: "u1", username: "TopDuck", rating: 1500, rank: 1),
            LeaderboardEntry(id: "u2", username: "MidDuck", rating: 1300, rank: 2),
            LeaderboardEntry(id: "u3", username: "NewDuck", rating: 1100, rank: 3),
        ])

        let entries = try await mock.getLeaderboard(limit: 10)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.first?.username, "TopDuck")
        XCTAssertEqual(entries.first?.rating, 1500)
        XCTAssertEqual(entries.last?.rank, 3)
    }
}

// MARK: - Two-Player Mock Backend

/// Mock that simulates both sides of a multiplayer backend interaction.
private actor TwoPlayerMock: MultiplayerBackendClient {
    struct Snapshot {
        var reportedScores: [(String, Int)]
        var lastJoinedRoomCode: String?
        var scoreReportAttempted: Bool
    }

    private let queueAssignment: MultiplayerMatchAssignment?
    private let roomAssignment: MultiplayerMatchAssignment?
    private let ratingDelta: Int?
    private let newRating: Int?
    private let forceDraw: Bool
    private let shouldFailScoreReport: Bool
    private let opponentLiveScore: Int
    private let leaderboardEntries: [LeaderboardEntry]

    private var reportedScores: [(String, Int)] = []
    private var lastJoinedRoomCode: String?
    private var scoreReportAttempted = false

    init(queueAssignment: MultiplayerMatchAssignment? = nil,
         roomAssignment: MultiplayerMatchAssignment? = nil,
         ratingDelta: Int? = nil,
         newRating: Int? = nil,
         forceDraw: Bool = false,
         shouldFailScoreReport: Bool = false,
         opponentLiveScore: Int = 0,
         leaderboardEntries: [LeaderboardEntry] = []) {
        self.queueAssignment = queueAssignment
        self.roomAssignment = roomAssignment
        self.ratingDelta = ratingDelta
        self.newRating = newRating
        self.forceDraw = forceDraw
        self.shouldFailScoreReport = shouldFailScoreReport
        self.opponentLiveScore = opponentLiveScore
        self.leaderboardEntries = leaderboardEntries
    }

    func snapshot() -> Snapshot {
        Snapshot(
            reportedScores: reportedScores,
            lastJoinedRoomCode: lastJoinedRoomCode,
            scoreReportAttempted: scoreReportAttempted
        )
    }

    func setAuthContext(deviceId: String, sessionToken: String?) async {}

    func bootstrapGuest(deviceId: String, localStats: LocalStatsSnapshot?) async throws -> AuthBootstrapResponse {
        AuthBootstrapResponse(
            profile: RemotePlayerProfile(userId: "u1", username: "Guest", provider: .guest, stats: PlayerStats()),
            didMergeStats: false
        )
    }

    func linkApple(identityToken: String, nonce: String, deviceId: String, displayName: String?) async throws -> AuthLinkResponse {
        AuthLinkResponse(
            profile: RemotePlayerProfile(userId: "u-apple", username: displayName ?? "Player", provider: .apple, stats: PlayerStats()),
            sessionToken: "tok",
            sessionExpiresAt: nil,
            appleUserId: "apple-u",
            didMergeStats: false
        )
    }

    func getProfile() async throws -> RemotePlayerProfile {
        RemotePlayerProfile(userId: "u1", username: "Guest", provider: .guest, stats: PlayerStats())
    }

    func signOutSession() async throws {}

    func joinMatchmakingQueue(mode: MatchmakingMode) async throws -> QueueTicket {
        QueueTicket(ticketId: "tick-\(mode.rawValue)", mode: mode, roomCode: nil)
    }

    func leaveMatchmakingQueue(ticketId: String?) async throws {}

    func checkQueue(ticketId: String?, mode: MatchmakingMode?) async throws -> MultiplayerMatchAssignment? {
        queueAssignment
    }

    func createRoom() async throws -> QueueTicket {
        QueueTicket(ticketId: "room-tick", mode: .privateRoom, roomCode: "DUCKY")
    }

    func joinRoom(code: String) async throws -> QueueTicket {
        lastJoinedRoomCode = code
        return QueueTicket(ticketId: "join-tick", mode: .privateRoom, roomCode: code)
    }

    func leaveRoom(code: String) async throws {}

    func checkRoom(code: String) async throws -> MultiplayerMatchAssignment? {
        roomAssignment
    }

    func reportScore(matchId: String, score: Int) async throws {
        scoreReportAttempted = true
        if shouldFailScoreReport {
            throw ConvexError.requestFailed
        }
        reportedScores.append((matchId, score))
    }

    func getMatchState(matchId: String) async throws -> MultiplayerMatchState {
        MultiplayerMatchState(
            matchId: matchId,
            localScore: 0,
            opponentScore: opponentLiveScore,
            isFinished: false,
            opponentName: "Opponent"
        )
    }

    func finishMatch(matchId: String,
                     score: Int,
                     mode: MatchmakingMode,
                     fallbackOpponentScore: Int,
                     opponentName: String?) async throws -> MultiplayerMatchResult {
        let isDraw = forceDraw || score == fallbackOpponentScore
        return MultiplayerMatchResult(
            matchId: matchId,
            mode: mode,
            opponentName: opponentName ?? "OPPONENT",
            localScore: score,
            opponentScore: fallbackOpponentScore,
            didWin: !isDraw && score > fallbackOpponentScore,
            didDraw: isDraw,
            ratingDelta: ratingDelta,
            newRating: newRating,
            isRanked: mode.isRanked
        )
    }

    func getLeaderboard(limit: Int) async throws -> [LeaderboardEntry] {
        Array(leaderboardEntries.prefix(limit))
    }
}
