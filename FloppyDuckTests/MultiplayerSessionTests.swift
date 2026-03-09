import XCTest
@testable import FloppyDuck

final class MultiplayerSessionTests: XCTestCase {
    func testQueueForMatchReturnsAssignmentAndUsesQueueTicket() async throws {
        let expected = MultiplayerMatchAssignment(
            matchId: "match-1",
            seed: 42,
            opponentName: "DuckBot",
            mode: .quickPlay,
            isRanked: false,
            roomCode: nil
        )

        let client = MockMultiplayerBackendClient(queueAssignment: expected)
        let session = MultiplayerSession(client: client)

        let assignment = try await session.queueForMatch(mode: .quickPlay, timeout: 2)

        XCTAssertEqual(assignment, expected)
        let snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.lastCheckQueueTicketId, "queue-ticket")
        XCTAssertEqual(snapshot.lastCheckQueueMode, .quickPlay)
    }

    func testJoinPrivateRoomNormalizesCodeToUppercase() async throws {
        let client = MockMultiplayerBackendClient()
        let session = MultiplayerSession(client: client)

        try await session.joinPrivateRoom(code: "aBcDe")

        let snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.lastJoinRoomCode, "ABCDE")
    }

    func testJoinPrivateRoomRejectsInvalidLength() async {
        let client = MockMultiplayerBackendClient()
        let session = MultiplayerSession(client: client)

        do {
            try await session.joinPrivateRoom(code: "AB")
            XCTFail("Expected invalidRoomCode error")
        } catch {
            guard case MultiplayerSessionError.invalidRoomCode = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCancelAfterCreateRoomLeavesRoom() async throws {
        let client = MockMultiplayerBackendClient()
        let session = MultiplayerSession(client: client)

        let roomCode = try await session.createPrivateRoom()
        XCTAssertEqual(roomCode, "DUCKY")

        await session.cancelMatchmaking()

        let snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.leftRoomCodes, ["DUCKY"])
        XCTAssertEqual(snapshot.leftQueueTicketIds.count, 0)
    }

    func testCancelAfterQueueLeavesQueue() async throws {
        let expected = MultiplayerMatchAssignment(
            matchId: "match-2",
            seed: 777,
            opponentName: "Opponent",
            mode: .ranked,
            isRanked: true,
            roomCode: nil
        )

        let client = MockMultiplayerBackendClient(queueAssignment: expected)
        let session = MultiplayerSession(client: client)

        _ = try await session.queueForMatch(mode: .ranked, timeout: 2)
        await session.cancelMatchmaking()

        let snapshot = await client.snapshot()
        XCTAssertEqual(snapshot.leftQueueTicketIds, ["queue-ticket"])
        XCTAssertEqual(snapshot.leftRoomCodes.count, 0)
    }
}

private actor MockMultiplayerBackendClient: MultiplayerBackendClient {
    struct Snapshot {
        var lastCheckQueueTicketId: String?
        var lastCheckQueueMode: MatchmakingMode?
        var lastJoinRoomCode: String?
        var leftRoomCodes: [String]
        var leftQueueTicketIds: [String?]
    }

    private let queueAssignment: MultiplayerMatchAssignment?
    private let roomAssignment: MultiplayerMatchAssignment?

    private var lastCheckQueueTicketId: String?
    private var lastCheckQueueMode: MatchmakingMode?
    private var lastJoinRoomCode: String?
    private var leftRoomCodes: [String] = []
    private var leftQueueTicketIds: [String?] = []

    init(queueAssignment: MultiplayerMatchAssignment? = nil,
         roomAssignment: MultiplayerMatchAssignment? = nil) {
        self.queueAssignment = queueAssignment
        self.roomAssignment = roomAssignment
    }

    func snapshot() -> Snapshot {
        Snapshot(
            lastCheckQueueTicketId: lastCheckQueueTicketId,
            lastCheckQueueMode: lastCheckQueueMode,
            lastJoinRoomCode: lastJoinRoomCode,
            leftRoomCodes: leftRoomCodes,
            leftQueueTicketIds: leftQueueTicketIds
        )
    }

    func setAuthContext(deviceId: String, sessionToken: String?) async {
        // Not needed for these tests.
    }

    func bootstrapGuest(deviceId: String, localStats: LocalStatsSnapshot?) async throws -> AuthBootstrapResponse {
        AuthBootstrapResponse(
            profile: RemotePlayerProfile(
                userId: "user-guest",
                username: "Guest",
                provider: .guest,
                stats: PlayerStats()
            ),
            didMergeStats: false
        )
    }

    func linkApple(identityToken: String,
                   nonce: String,
                   deviceId: String,
                   displayName: String?) async throws -> AuthLinkResponse {
        AuthLinkResponse(
            profile: RemotePlayerProfile(
                userId: "user-apple",
                username: displayName ?? "Player",
                provider: .apple,
                stats: PlayerStats()
            ),
            sessionToken: "session",
            sessionExpiresAt: nil,
            appleUserId: "apple-user",
            didMergeStats: false
        )
    }

    func getProfile() async throws -> RemotePlayerProfile {
        RemotePlayerProfile(
            userId: "user-guest",
            username: "Guest",
            provider: .guest,
            stats: PlayerStats()
        )
    }

    func signOutSession() async throws {
        // Not needed for these tests.
    }

    func joinMatchmakingQueue(mode: MatchmakingMode) async throws -> QueueTicket {
        QueueTicket(ticketId: "queue-ticket", mode: mode, roomCode: nil)
    }

    func leaveMatchmakingQueue(ticketId: String?) async throws {
        leftQueueTicketIds.append(ticketId)
    }

    func checkQueue(ticketId: String?, mode: MatchmakingMode?) async throws -> MultiplayerMatchAssignment? {
        lastCheckQueueTicketId = ticketId
        lastCheckQueueMode = mode
        return queueAssignment
    }

    func createRoom() async throws -> QueueTicket {
        QueueTicket(ticketId: "room-ticket", mode: .privateRoom, roomCode: "DUCKY")
    }

    func joinRoom(code: String) async throws -> QueueTicket {
        lastJoinRoomCode = code
        return QueueTicket(ticketId: "joined-room-ticket", mode: .privateRoom, roomCode: code)
    }

    func leaveRoom(code: String) async throws {
        leftRoomCodes.append(code)
    }

    func checkRoom(code: String) async throws -> MultiplayerMatchAssignment? {
        roomAssignment
    }

    func reportScore(matchId: String, score: Int) async throws {
        // Not needed for these tests.
    }

    func getMatchState(matchId: String) async throws -> MultiplayerMatchState {
        MultiplayerMatchState(matchId: matchId, localScore: 0, opponentScore: 0, isFinished: false, opponentName: nil)
    }

    func finishMatch(matchId: String,
                     score: Int,
                     mode: MatchmakingMode,
                     fallbackOpponentScore: Int,
                     opponentName: String?) async throws -> MultiplayerMatchResult {
        MultiplayerMatchResult(
            matchId: matchId,
            mode: mode,
            opponentName: opponentName ?? "OPPONENT",
            localScore: score,
            opponentScore: fallbackOpponentScore,
            didWin: score > fallbackOpponentScore,
            didDraw: score == fallbackOpponentScore,
            ratingDelta: nil,
            newRating: nil,
            isRanked: mode.isRanked
        )
    }

    func getLeaderboard(limit: Int) async throws -> [LeaderboardEntry] {
        []
    }
}
