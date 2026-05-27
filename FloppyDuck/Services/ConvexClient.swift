import Foundation
import QuartzCore

/// Abstraction used by multiplayer/session/auth logic so tests can inject a mock backend.
protocol MultiplayerBackendClient: Sendable {
    func setAuthContext(deviceId: String, sessionToken: String?) async

    func bootstrapGuest(deviceId: String,
                        localStats: LocalStatsSnapshot?) async throws -> AuthBootstrapResponse

    func linkApple(identityToken: String,
                   nonce: String,
                   deviceId: String,
                   displayName: String?) async throws -> AuthLinkResponse

    func linkGameCenter(playerId: String,
                        alias: String,
                        deviceId: String) async throws -> AuthLinkResponse

    func getProfile() async throws -> RemotePlayerProfile
    func signOutSession() async throws
    func deleteAccount() async throws

    func joinMatchmakingQueue(mode: MatchmakingMode) async throws -> QueueTicket
    func leaveMatchmakingQueue(ticketId: String?) async throws
    func heartbeatQueue(ticketId: String) async throws -> Bool
    func checkQueue(ticketId: String?, mode: MatchmakingMode?) async throws -> MultiplayerMatchAssignment?

    func createRoom() async throws -> QueueTicket
    func joinRoom(code: String) async throws -> QueueTicket
    func leaveRoom(code: String) async throws
    func checkRoom(code: String) async throws -> MultiplayerMatchAssignment?

    func reportScore(matchId: String, score: Int) async throws
    func getMatchState(matchId: String) async throws -> MultiplayerMatchState

    func finishMatch(matchId: String,
                     score: Int,
                     mode: MatchmakingMode,
                     fallbackOpponentScore: Int,
                     opponentName: String?) async throws -> MultiplayerMatchResult

    func abandonMatch(matchId: String) async throws

    func markReady(matchId: String) async throws
    func scheduleStart(matchId: String, startAtMs: Double) async throws
    func getReadyState(matchId: String) async throws -> ReadyState

    func recordDiagnosticEvent(_ event: MultiplayerDiagnosticEvent) async throws

    func joinBattleRoyaleLobby() async throws -> BattleRoyaleAssignment
    func leaveBattleRoyaleLobby(lobbyId: String) async throws -> Int?
    func startBattleRoyaleIfReady(lobbyId: String) async throws -> BattleRoyaleState
    func getBattleRoyaleState(lobbyId: String) async throws -> BattleRoyaleState
    func reportBattleRoyaleState(lobbyId: String,
                                  score: Int,
                                  y: Double,
                                  rotation: Double,
                                  wingPhase: Int) async throws
    func finishBattleRoyaleRun(lobbyId: String, score: Int) async throws -> BattleRoyaleState

    func getLeaderboard(limit: Int) async throws -> [LeaderboardEntry]
    func getHighScoreLeaderboard(limit: Int) async throws -> [HighScoreEntry]

    /// Sync beaten bot IDs to the backend immediately (XAN-9).
    func syncBeatenBots(_ botIds: [String]) async throws

    /// Sync bread spent in the shop to the backend so it doesn't desync.
    func spendBread(_ amount: Int) async throws -> Int

    /// Update the player's username (enforced unique server-side).
    func updateUsername(_ name: String) async throws -> String

    // MARK: - Friends & Social

    func getPublicProfile(userId: String) async throws -> PublicPlayerProfile
    func searchUsers(query: String) async throws -> [PublicPlayerProfile]
    func sendFriendRequest(toUserId: String) async throws
    func acceptFriendRequest(fromUserId: String) async throws
    func removeFriend(otherUserId: String) async throws
    func blockUser(toUserId: String) async throws
    func getFriends() async throws -> [PublicPlayerProfile]
    func getPendingFriendRequests() async throws -> [PublicPlayerProfile]
}

extension MultiplayerBackendClient {
    /// Default no-op — mocks and tests don't need bread sync.
    func spendBread(_ amount: Int) async throws -> Int { 0 }
    func updateUsername(_ name: String) async throws -> String { name }
    func linkGameCenter(playerId: String,
                        alias: String,
                        deviceId: String) async throws -> AuthLinkResponse { throw ConvexError.requestFailed }
    func joinBattleRoyaleLobby() async throws -> BattleRoyaleAssignment { throw ConvexError.requestFailed }
    func leaveBattleRoyaleLobby(lobbyId: String) async throws -> Int? { nil }
    func startBattleRoyaleIfReady(lobbyId: String) async throws -> BattleRoyaleState { throw ConvexError.requestFailed }
    func getBattleRoyaleState(lobbyId: String) async throws -> BattleRoyaleState { throw ConvexError.requestFailed }
    func reportBattleRoyaleState(lobbyId: String,
                                  score: Int,
                                  y: Double,
                                  rotation: Double,
                                  wingPhase: Int) async throws {}
    func finishBattleRoyaleRun(lobbyId: String, score: Int) async throws -> BattleRoyaleState { throw ConvexError.requestFailed }
    func getHighScoreLeaderboard(limit: Int) async throws -> [HighScoreEntry] { [] }
    func abandonMatch(matchId: String) async throws {}
    func markReady(matchId: String) async throws {}
    func scheduleStart(matchId: String, startAtMs: Double) async throws {}
    func getReadyState(matchId: String) async throws -> ReadyState { ReadyState(p1Ready: nil, p2Ready: nil, startAtMs: nil, status: "active") }
    func recordDiagnosticEvent(_ event: MultiplayerDiagnosticEvent) async throws {}
    func getPublicProfile(userId: String) async throws -> PublicPlayerProfile { throw ConvexError.requestFailed }
    func searchUsers(query: String) async throws -> [PublicPlayerProfile] { [] }
    func sendFriendRequest(toUserId: String) async throws { throw ConvexError.requestFailed }
    func acceptFriendRequest(fromUserId: String) async throws { throw ConvexError.requestFailed }
    func removeFriend(otherUserId: String) async throws { throw ConvexError.requestFailed }
    func blockUser(toUserId: String) async throws { throw ConvexError.requestFailed }
    func getFriends() async throws -> [PublicPlayerProfile] { [] }
    func getPendingFriendRequests() async throws -> [PublicPlayerProfile] { [] }
}

struct MultiplayerDiagnosticEvent: Sendable {
    let category: String
    let event: String
    let level: String
    let message: String?
    let matchId: String?
    let sessionCode: String?
    let playerGroup: Int?
    let mode: String?
    let metadata: [String: String]

    init(category: String,
         event: String,
         level: String = "info",
         message: String? = nil,
         matchId: String? = nil,
         sessionCode: String? = nil,
         playerGroup: Int? = nil,
         mode: String? = nil,
         metadata: [String: String] = [:]) {
        self.category = category
        self.event = event
        self.level = level
        self.message = message
        self.matchId = matchId
        self.sessionCode = sessionCode
        self.playerGroup = playerGroup
        self.mode = mode
        self.metadata = metadata
    }
}

enum MultiplayerDiagnostics {
    static func record(category: String,
                       event: String,
                       level: String = "info",
                       message: String? = nil,
                       matchId: String? = nil,
                       sessionCode: String? = nil,
                       playerGroup: Int? = nil,
                       mode: String? = nil,
                       metadata: [String: String] = [:],
                       echo: Bool = false) {
        if echo {
            print("[Diagnostics] \(category).\(event) \(message ?? "")")
        }

        let diagnostic = MultiplayerDiagnosticEvent(
            category: category,
            event: event,
            level: level,
            message: message,
            matchId: matchId,
            sessionCode: sessionCode,
            playerGroup: playerGroup,
            mode: mode,
            metadata: metadata
        )

        Task.detached(priority: .utility) {
            do {
                try await ConvexClient.shared.recordDiagnosticEvent(diagnostic)
            } catch {
#if DEBUG
                print("[Diagnostics] Upload failed: \(error.localizedDescription)")
#endif
            }
        }
    }
}

struct ConvexAuthContext: Sendable {
    let deviceId: String?
    let sessionToken: String?

    static let none = ConvexAuthContext(deviceId: nil, sessionToken: nil)
}

/// REST client for the Convex backend.
/// Handles identity/auth, matchmaking, private rooms, score sync, and match results.
actor ConvexClient: MultiplayerBackendClient {
    static let shared = ConvexClient()

    // MARK: - Configuration

    private static let baseURLInfoKey = "CONVEX_BASE_URL"

    private let baseURL: String
    private let session: URLSession

    private var authContext: ConvexAuthContext = .none

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
        self.baseURL = Self.resolveBaseURL()
    }

    private static func resolveBaseURL() -> String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: baseURLInfoKey) as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        assertionFailure("Missing CONVEX_BASE_URL in Info.plist.")
        return ""
    }

    // MARK: - Auth Context

    func setAuthContext(deviceId: String, sessionToken: String?) {
        authContext = ConvexAuthContext(deviceId: deviceId, sessionToken: sessionToken)
    }

    // MARK: - Raw Requests

    private func queryRaw(_ functionName: String, args: [String: Any] = [:]) async throws -> Any? {
        try await requestRaw(endpoint: "query", functionName: functionName, args: args)
    }

    private func mutationRaw(_ functionName: String, args: [String: Any] = [:]) async throws -> Any? {
        try await requestRaw(endpoint: "mutation", functionName: functionName, args: args)
    }

    private func actionRaw(_ functionName: String, args: [String: Any] = [:]) async throws -> Any? {
        try await requestRaw(endpoint: "action", functionName: functionName, args: args)
    }

    private func requestRaw(endpoint: String,
                            functionName: String,
                            args: [String: Any]) async throws -> Any? {
        // Item 3: Retry with exponential backoff (1s→2s→4s), skip retries for 401/403
        return try await withRetry(maxAttempts: 3) {
            try await self.performRequest(endpoint: endpoint, functionName: functionName, args: args)
        }
    }

    /// Performs a single network request (extracted for retry wrapper).
    private func performRequest(endpoint: String,
                                functionName: String,
                                args: [String: Any]) async throws -> Any? {
        guard let url = URL(string: "\(baseURL)/api/\(endpoint)") else {
            throw ConvexError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // XAN-10: Session token is passed via mergedArgsWithIdentity() in the
        // function args body — NOT as an HTTP Authorization header.
        // Convex REST API interprets Bearer tokens as native Convex auth
        // tokens, which causes 401 for custom session UUIDs.

        let payloadArgs = mergedArgsWithIdentity(args)
        let body: [String: Any] = [
            "path": functionName,
            "args": payloadArgs,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

#if DEBUG
        let start = CACurrentMediaTime()
#endif
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ConvexError.requestFailed
        }

#if DEBUG
        let elapsed = CACurrentMediaTime() - start
        let summary: String
        if http.statusCode == 200 {
            if let object = try? JSONSerialization.jsonObject(with: data, options: []),
               let root = object as? [String: Any],
               root["status"] as? String == "error" {
                summary = "❌ error"
            } else {
                summary = "✅ OK"
            }
        } else {
            summary = "❌ \(http.statusCode)"
        }
        print("[Convex] \(summary) \(functionName) \(String(format: "%.0f", elapsed*1000))ms")
#endif

        // Don't retry auth errors (401/403)
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ConvexError.authFailed(http.statusCode)
        }

        // Try to parse body even for non-200 — Convex may include error details.
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = object as? [String: Any] else {
            // Couldn't parse body — only then fall back to generic error.
            if http.statusCode != 200 {
                throw ConvexError.requestFailed
            }
            throw ConvexError.invalidResponse
        }

        // Convex REST API returns errors as HTTP 200 with:
        //   { "status": "error", "errorMessage": "...", "errorData": "..." }
        // `errorData` carries the clean ConvexError message; `errorMessage`
        // contains the full stack trace.  Also handle legacy / edge formats.
        let isError = string(from: root["status"])?.lowercased() == "error"
        if isError || http.statusCode != 200 {
            // Prefer clean errorData, then errorMessage, then legacy keys
            let msg = string(in: root, keys: ["errorData", "errorMessage", "error", "message"])
                ?? "Server error (\(functionName))"
#if DEBUG
            print("[ConvexClient] \(functionName) error: \(msg)")
#endif
            throw ConvexError.server(msg)
        }

        return root["value"]
    }

    /// Retries an async throwing closure with exponential backoff.
    /// Delays: 1s after first failure, 2s after second, 4s after third…
    /// Does NOT retry ConvexError.authFailed (401/403).
    private func withRetry<T>(maxAttempts: Int,
                              _ operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as ConvexError where error.isAuthError {
                // Never retry auth errors
                throw error
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000 // 1s, 2s, 4s…
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw lastError ?? ConvexError.requestFailed
    }

    private func mergedArgsWithIdentity(_ args: [String: Any]) -> [String: Any] {
        var merged = args
        if merged["deviceId"] == nil,
           let deviceId = authContext.deviceId,
           !deviceId.isEmpty {
            merged["deviceId"] = deviceId
        }

        if merged["sessionToken"] == nil,
           let sessionToken = authContext.sessionToken,
           !sessionToken.isEmpty {
            merged["sessionToken"] = sessionToken
        }

        return merged
    }

    // MARK: - Auth

    func bootstrapGuest(deviceId: String,
                        localStats: LocalStatsSnapshot?) async throws -> AuthBootstrapResponse {
        var args: [String: Any] = ["deviceId": deviceId]
        if let localStats {
            args["localStats"] = localStats.asDictionary
        }

        let value = try await mutationRaw("auth:bootstrapGuest", args: args)
        guard let payload = dictionary(from: value) else {
            throw ConvexError.invalidResponse
        }

        let profileSource = dictionary(in: payload, keys: ["profile", "user"]) ?? payload
        guard let profile = parseProfile(profileSource) else {
            throw ConvexError.invalidResponse
        }

        let didMergeStats = bool(in: payload, keys: ["didMergeStats", "did_merge_stats", "merged"]) ?? false
        return AuthBootstrapResponse(profile: profile, didMergeStats: didMergeStats)
    }

    func linkApple(identityToken: String,
                   nonce: String,
                   deviceId: String,
                   displayName: String?) async throws -> AuthLinkResponse {
        var args: [String: Any] = [
            "identityToken": identityToken,
            "nonce": nonce,
            "deviceId": deviceId,
        ]
        if let displayName, !displayName.isEmpty {
            args["displayName"] = displayName
        }

        // linkApple is a Convex action (not mutation) because Apple JWT verification
        // requires fetching Apple's JWKS via HTTP — only available in actions.
        let value = try await actionRaw("auth:linkApple", args: args)
        guard let payload = dictionary(from: value) else {
            throw ConvexError.invalidResponse
        }

        let profileSource = dictionary(in: payload, keys: ["profile", "user"]) ?? payload
        guard let profile = parseProfile(profileSource) else {
            throw ConvexError.invalidResponse
        }

        guard let sessionToken = string(in: payload, keys: ["sessionToken", "session_token", "token"]),
              !sessionToken.isEmpty else {
            throw ConvexError.invalidResponse
        }

        return AuthLinkResponse(
            profile: profile,
            sessionToken: sessionToken,
            sessionExpiresAt: date(in: payload, keys: ["sessionExpiresAt", "expiresAt", "expires_at"]),
            appleUserId: string(in: payload, keys: ["appleUserId", "apple_user_id"]),
            didMergeStats: bool(in: payload, keys: ["didMergeStats", "did_merge_stats", "merged"]) ?? false
        )
    }

    func linkGameCenter(playerId: String,
                        alias: String,
                        deviceId: String) async throws -> AuthLinkResponse {
        let value = try await mutationRaw("auth:linkGameCenter", args: [
            "gameCenterPlayerId": playerId,
            "alias": alias,
            "deviceId": deviceId,
        ])
        guard let payload = dictionary(from: value) else {
            throw ConvexError.invalidResponse
        }

        let profileSource = dictionary(in: payload, keys: ["profile", "user"]) ?? payload
        guard let profile = parseProfile(profileSource) else {
            throw ConvexError.invalidResponse
        }

        guard let sessionToken = string(in: payload, keys: ["sessionToken", "session_token", "token"]),
              !sessionToken.isEmpty else {
            throw ConvexError.invalidResponse
        }

        return AuthLinkResponse(
            profile: profile,
            sessionToken: sessionToken,
            sessionExpiresAt: date(in: payload, keys: ["sessionExpiresAt", "expiresAt", "expires_at"]),
            appleUserId: nil,
            didMergeStats: bool(in: payload, keys: ["didMergeStats", "did_merge_stats", "merged"]) ?? false
        )
    }

    func getProfile() async throws -> RemotePlayerProfile {
        let value = try await queryRaw("auth:getProfile")

        if let dict = dictionary(from: value),
           let nested = dictionary(in: dict, keys: ["profile", "user"]) {
            if let profile = parseProfile(nested) {
                return profile
            }
        }

        if let profile = parseProfile(value) {
            return profile
        }

        throw ConvexError.invalidResponse
    }

    func signOutSession() async throws {
        _ = try await mutationRaw("auth:signOutSession")
    }

    func deleteAccount() async throws {
        _ = try await mutationRaw("auth:deleteAccount")
    }

    func syncStats(_ snapshot: LocalStatsSnapshot) async throws {
        _ = try await mutationRaw("auth:syncStats", args: [
            "localStats": snapshot.asDictionary,
        ])
    }

    func fetchAnnouncements() async throws -> [Announcement] {
        let value = try await queryRaw("announcements:getActive")
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { item in
            guard let id = item["id"] as? String,
                  let title = item["title"] as? String,
                  let body = item["body"] as? [String] else { return nil }
            return Announcement(
                id: id,
                title: title,
                body: body,
                color: item["color"] as? String ?? "#4CAF50"
            )
        }
    }

    // MARK: - Matchmaking

    func joinMatchmakingQueue(mode: MatchmakingMode) async throws -> QueueTicket {
        let value = try await mutationRaw("matchmaking:joinQueue", args: [
            "mode": mode.queueValue,
        ])

        let ticketId: String
        if let dict = dictionary(from: value) {
            ticketId = string(in: dict, keys: ["ticketId", "ticket_id", "id", "_id"]) ?? UUID().uuidString
        } else if let id = string(from: value) {
            ticketId = id
        } else {
            ticketId = UUID().uuidString
        }

        return QueueTicket(ticketId: ticketId, mode: mode, roomCode: nil)
    }

    func leaveMatchmakingQueue(ticketId: String?) async throws {
        var args: [String: Any] = [:]
        if let ticketId {
            args["ticketId"] = ticketId
        }
        _ = try await mutationRaw("matchmaking:leaveQueue", args: args)
    }

    func heartbeatQueue(ticketId: String) async throws -> Bool {
        let value = try await mutationRaw("matchmaking:heartbeatQueue", args: ["ticketId": ticketId])
        if let dict = dictionary(from: value) {
            return bool(in: dict, keys: ["found", "ok"]) ?? false
        }
        return false
    }

    func checkQueue(ticketId: String?, mode: MatchmakingMode?) async throws -> MultiplayerMatchAssignment? {
        var args: [String: Any] = [:]
        if let ticketId {
            args["ticketId"] = ticketId
        }

        let value = try await queryRaw("matchmaking:checkQueue", args: args)
        return parseAssignment(value, fallbackMode: mode, fallbackRoomCode: nil)
    }

    // MARK: - Private Rooms

    func createRoom() async throws -> QueueTicket {
        let value = try await mutationRaw("matchmaking:createRoom")
        guard let dict = dictionary(from: value) else {
            throw ConvexError.invalidResponse
        }

        guard let rawCode = string(in: dict, keys: ["roomCode", "room_code", "code"]) else {
            throw ConvexError.invalidResponse
        }
        let roomCode = String(rawCode.prefix(GK.roomCodeLength)).uppercased()

        let ticketId = string(in: dict, keys: ["ticketId", "ticket_id", "id", "_id"]) ?? UUID().uuidString
        return QueueTicket(ticketId: ticketId, mode: .privateRoom, roomCode: roomCode)
    }

    func joinRoom(code: String) async throws -> QueueTicket {
        let normalized = String(code.prefix(GK.roomCodeLength)).uppercased()

        let value = try await mutationRaw("matchmaking:joinRoom", args: [
            "code": normalized,
        ])

        if let dict = dictionary(from: value) {
            let ticketId = string(in: dict, keys: ["ticketId", "ticket_id", "id", "_id"]) ?? UUID().uuidString
            return QueueTicket(ticketId: ticketId, mode: .privateRoom, roomCode: normalized)
        }

        if let id = string(from: value) {
            return QueueTicket(ticketId: id, mode: .privateRoom, roomCode: normalized)
        }

        return QueueTicket(ticketId: UUID().uuidString, mode: .privateRoom, roomCode: normalized)
    }

    func leaveRoom(code: String) async throws {
        _ = try await mutationRaw("matchmaking:leaveRoom", args: ["code": code])
    }

    func checkRoom(code: String) async throws -> MultiplayerMatchAssignment? {
        let value = try await queryRaw("matchmaking:checkRoom", args: ["code": code])
        return parseAssignment(value, fallbackMode: .privateRoom, fallbackRoomCode: code)
    }

    // MARK: - Match State

    func reportScore(matchId: String, score: Int) async throws {
        _ = try await mutationRaw("matches:reportScore", args: [
            "matchId": matchId,
            "score": score,
        ])
    }

    func getMatchState(matchId: String) async throws -> MultiplayerMatchState {
        let value = try await queryRaw("matches:getState", args: ["matchId": matchId])

        if let dict = dictionary(from: value) {
            let local = int(in: dict, keys: ["localScore", "playerScore", "score", "p1Score"]) ?? 0
            let opponent = int(in: dict, keys: ["opponentScore", "otherScore", "p2Score"]) ?? 0
            let finished = bool(in: dict, keys: ["isFinished", "finished", "done"]) ?? false
            let opponentName = string(in: dict, keys: ["opponentName", "opponent", "enemyName"])
            let opponentSkinId = string(in: dict, keys: ["opponentSkinId", "opponentSkin", "enemySkin", "skinId"])

            return MultiplayerMatchState(
                matchId: matchId,
                localScore: local,
                opponentScore: opponent,
                isFinished: finished,
                opponentName: opponentName,
                opponentSkinId: opponentSkinId,
                didWin: bool(in: dict, keys: ["didWin", "won", "isWinner"]),
                didDraw: bool(in: dict, keys: ["didDraw", "draw", "isDraw"]),
                ratingDelta: int(in: dict, keys: ["ratingDelta", "eloDelta", "delta"]),
                newRating: int(in: dict, keys: ["newRating", "elo", "rating"]),
                isRanked: bool(in: dict, keys: ["isRanked", "ranked"])
            )
        }

        return MultiplayerMatchState(
            matchId: matchId,
            localScore: 0,
            opponentScore: 0,
            isFinished: false,
            opponentName: nil,
            opponentSkinId: nil
        )
    }

    func finishMatch(matchId: String,
                     score: Int,
                     mode requestedMode: MatchmakingMode,
                     fallbackOpponentScore: Int,
                     opponentName: String?) async throws -> MultiplayerMatchResult {
        let value = try await mutationRaw("matches:finishMatch", args: [
            "matchId": matchId,
            "score": score,
        ])

        let payload = dictionary(from: value)
        let opponentScore = int(in: payload, keys: ["opponentScore", "otherScore", "p2Score"]) ?? fallbackOpponentScore
        let localScore = int(in: payload, keys: ["localScore", "playerScore", "score", "p1Score"]) ?? score

        let didDraw = bool(in: payload, keys: ["didDraw", "draw", "isDraw"]) ?? (localScore == opponentScore)
        let didWin = bool(in: payload, keys: ["didWin", "won", "isWinner"]) ?? (localScore > opponentScore)
        let isFinalized = bool(in: payload, keys: ["isFinalized", "isFinished", "finished"]) ?? true

        let reportedMode = parseMode(from: string(in: payload, keys: ["mode", "queueMode"])) ?? requestedMode
        let isRanked = bool(in: payload, keys: ["isRanked", "ranked"]) ?? reportedMode.isRanked

        let name = string(in: payload, keys: ["opponentName", "opponent", "enemyName"])
            ?? opponentName
            ?? "OPPONENT"

        return MultiplayerMatchResult(
            matchId: matchId,
            mode: reportedMode,
            opponentName: name,
            localScore: localScore,
            opponentScore: opponentScore,
            didWin: didWin,
            didDraw: didDraw,
            ratingDelta: int(in: payload, keys: ["ratingDelta", "eloDelta", "delta"]),
            newRating: int(in: payload, keys: ["newRating", "elo", "rating"]),
            isRanked: isRanked,
            isFinalized: isFinalized
        )
    }

    func abandonMatch(matchId: String) async throws {
        _ = try await mutationRaw("matches:abandonMatch", args: [
            "matchId": matchId,
        ])
    }

    func markReady(matchId: String) async throws {
        _ = try await mutationRaw("matches:markReady", args: [
            "matchId": matchId,
        ])
    }

    func scheduleStart(matchId: String, startAtMs: Double) async throws {
        _ = try await mutationRaw("matches:scheduleStart", args: [
            "matchId": matchId,
            "startAtMs": startAtMs,
        ])
    }

    func getReadyState(matchId: String) async throws -> ReadyState {
        let value = try await queryRaw("matches:getReadyState", args: ["matchId": matchId])
        guard let dict = dictionary(from: value) else {
            return ReadyState(p1Ready: nil, p2Ready: nil, startAtMs: nil, status: "active")
        }

        return ReadyState(
            p1Ready: double(in: dict, keys: ["p1Ready"]),
            p2Ready: double(in: dict, keys: ["p2Ready"]),
            startAtMs: double(in: dict, keys: ["startAtMs"]),
            status: string(in: dict, keys: ["status"]) ?? "active"
        )
    }

    func recordDiagnosticEvent(_ event: MultiplayerDiagnosticEvent) async throws {
        var args: [String: Any] = [
            "category": event.category,
            "event": event.event,
            "level": event.level,
        ]

        if let message = event.message {
            args["message"] = message
        }
        if let matchId = event.matchId {
            args["matchId"] = matchId
        }
        if let sessionCode = event.sessionCode {
            args["sessionCode"] = sessionCode
        }
        if let playerGroup = event.playerGroup {
            args["playerGroup"] = playerGroup
        }
        if let mode = event.mode {
            args["mode"] = mode
        }
        if !event.metadata.isEmpty {
            args["metadata"] = event.metadata
                .sorted { $0.key < $1.key }
                .map { ["key": $0.key, "value": $0.value] }
        }

        _ = try await mutationRaw("diagnostics:recordEvent", args: args)
    }

    // MARK: - Battle Royale

    func joinBattleRoyaleLobby() async throws -> BattleRoyaleAssignment {
        let value = try await mutationRaw("battleRoyale:joinLobby")
        return try parseBattleRoyaleAssignment(value)
    }

    func leaveBattleRoyaleLobby(lobbyId: String) async throws -> Int? {
        let value = try await mutationRaw("battleRoyale:leaveLobby", args: ["lobbyId": lobbyId])
        return int(in: dictionary(from: value), keys: ["bread"])
    }

    func startBattleRoyaleIfReady(lobbyId: String) async throws -> BattleRoyaleState {
        let value = try await mutationRaw("battleRoyale:startIfReady", args: ["lobbyId": lobbyId])
        return try parseBattleRoyaleState(value)
    }

    func getBattleRoyaleState(lobbyId: String) async throws -> BattleRoyaleState {
        let value = try await queryRaw("battleRoyale:getState", args: ["lobbyId": lobbyId])
        return try parseBattleRoyaleState(value)
    }

    func reportBattleRoyaleState(lobbyId: String,
                                  score: Int,
                                  y: Double,
                                  rotation: Double,
                                  wingPhase: Int) async throws {
        _ = try await mutationRaw("battleRoyale:reportState", args: [
            "lobbyId": lobbyId,
            "score": score,
            "y": y,
            "rotation": rotation,
            "wingPhase": wingPhase,
        ])
    }

    func finishBattleRoyaleRun(lobbyId: String, score: Int) async throws -> BattleRoyaleState {
        let value = try await mutationRaw("battleRoyale:finishRun", args: [
            "lobbyId": lobbyId,
            "score": score,
        ])
        return try parseBattleRoyaleState(value)
    }

    // MARK: - Leaderboard

    func getLeaderboard(limit: Int = 20) async throws -> [LeaderboardEntry] {
        let value = try await queryRaw("ratings:leaderboard", args: ["limit": limit])
        let items: [Any]
        let ownEntry: [String: Any]?

        if let payload = dictionary(from: value) {
            items = payload["entries"] as? [Any] ?? []
            ownEntry = dictionary(in: payload, keys: ["ownEntry", "own_entry"])
        } else {
            items = value as? [Any] ?? []
            ownEntry = nil
        }

        var entries = items.enumerated().compactMap { index, item in
            parseLeaderboardEntry(item, fallbackRank: index + 1)
        }

        if let own = parseLeaderboardEntry(ownEntry),
           !entries.contains(where: { $0.id == own.id }) {
            entries.append(own)
        }

        entries.sort { $0.rank < $1.rank }
        return entries
    }

    func getHighScoreLeaderboard(limit: Int = 20) async throws -> [HighScoreEntry] {
        let value = try await queryRaw("scores:leaderboard", args: ["limit": limit])
        let items: [Any]
        let ownEntry: [String: Any]?

        if let payload = dictionary(from: value) {
            items = payload["entries"] as? [Any] ?? []
            ownEntry = dictionary(in: payload, keys: ["ownEntry", "own_entry"])
        } else {
            items = value as? [Any] ?? []
            ownEntry = nil
        }

        var entries = items.enumerated().compactMap { index, item in
            parseHighScoreEntry(item, fallbackRank: index + 1)
        }

        if let own = parseHighScoreEntry(ownEntry),
           !entries.contains(where: { $0.id == own.id }) {
            entries.append(own)
        }

        entries.sort { $0.rank < $1.rank }

        print("[ConvexClient] getHighScoreLeaderboard rawValue type: \(type(of: value)), items count: \(items.count), parsed entries: \(entries.count)")
        if items.count > 0 && entries.isEmpty {
            print("[ConvexClient] WARNING: all items failed to parse. First item: \(items[0])")
        }

        return entries
    }

    private func parseLeaderboardEntry(_ value: Any?, fallbackRank: Int = 0) -> LeaderboardEntry? {
        guard let dict = dictionary(from: value),
              let userId = string(in: dict, keys: ["userId", "user_id", "id", "_id"]),
              let rating = int(in: dict, keys: ["rating", "elo"]) else {
            return nil
        }

        return LeaderboardEntry(
            id: userId,
            username: string(in: dict, keys: ["username", "name", "displayName"]) ?? "Player",
            rating: rating,
            rank: int(in: dict, keys: ["rank"]) ?? fallbackRank
        )
    }

    private func parseHighScoreEntry(_ value: Any?, fallbackRank: Int = 0) -> HighScoreEntry? {
        guard let dict = dictionary(from: value),
              let userId = string(in: dict, keys: ["userId", "user_id", "id", "_id"]),
              let bestScore = int(in: dict, keys: ["bestScore", "best_score", "score"]) else {
            return nil
        }

        return HighScoreEntry(
            id: userId,
            username: string(in: dict, keys: ["username", "name", "displayName"]) ?? "Player",
            bestScore: bestScore,
            rank: int(in: dict, keys: ["rank"]) ?? fallbackRank
        )
    }

    // MARK: - Bot Sync (XAN-9)

    func syncBeatenBots(_ botIds: [String]) async throws {
        guard !botIds.isEmpty else { return }
        _ = try await mutationRaw("auth:syncBeatenBots", args: [
            "beatenBots": botIds
        ])
    }

    func spendBread(_ amount: Int) async throws -> Int {
        guard amount > 0 else { throw ConvexError.requestFailed }
        let result = try await mutationRaw("auth:spendBread", args: [
            "amount": amount,
        ])
        guard let dict = result as? [String: Any],
              let bread = dict["bread"] as? Int else {
            throw ConvexError.invalidResponse
        }
        return bread
    }

    func syncSkin(_ skinId: String) async throws {
        _ = try await mutationRaw("auth:syncSkin", args: [
            "skinId": skinId,
        ])
    }

    func updateUsername(_ name: String) async throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { throw ConvexError.requestFailed }
        let result = try await mutationRaw("auth:updateUsername", args: [
            "username": trimmed,
        ])
        guard let dict = result as? [String: Any],
              let username = dict["username"] as? String else {
            throw ConvexError.invalidResponse
        }
        return username
    }

    // MARK: - Friends & Social

    func getPublicProfile(userId: String) async throws -> PublicPlayerProfile {
        let value = try await queryRaw("friends:getPublicProfile", args: ["userId": userId])
        guard let dict = dictionary(from: value) else {
            throw ConvexError.invalidResponse
        }
        return parsePublicProfile(dict)
    }

    func searchUsers(query: String) async throws -> [PublicPlayerProfile] {
        let value = try await queryRaw("friends:searchUsers", args: ["query": query])
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { try? parsePublicProfile($0) }
    }

    func sendFriendRequest(toUserId: String) async throws {
        _ = try await mutationRaw("friends:sendRequest", args: ["toUserId": toUserId])
    }

    func acceptFriendRequest(fromUserId: String) async throws {
        _ = try await mutationRaw("friends:acceptRequest", args: ["fromUserId": fromUserId])
    }

    func removeFriend(otherUserId: String) async throws {
        _ = try await mutationRaw("friends:removeFriendship", args: ["otherUserId": otherUserId])
    }

    func blockUser(toUserId: String) async throws {
        _ = try await mutationRaw("friends:blockUser", args: ["toUserId": toUserId])
    }

    func getFriends() async throws -> [PublicPlayerProfile] {
        let value = try await queryRaw("friends:getFriends")
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { try? parsePublicProfile($0) }
    }

    func getPendingFriendRequests() async throws -> [PublicPlayerProfile] {
        let value = try await queryRaw("friends:getPendingRequests")
        guard let list = value as? [[String: Any]] else { return [] }
        return list.compactMap { try? parsePublicProfile($0) }
    }

    // MARK: - Parsing Helpers

    private func parsePublicProfile(_ dict: [String: Any]) -> PublicPlayerProfile {
        let userId = string(in: dict, keys: ["userId", "user_id", "id", "_id"]) ?? ""
        let username = string(in: dict, keys: ["username", "name"]) ?? "Player"
        let provider = parseProvider(from: string(in: dict, keys: ["provider"])) ?? .guest

        let statsSource = dictionary(in: dict, keys: ["stats", "playerStats", "player_stats"]) ?? dict
        let stats = parsePublicPlayerStats(from: statsSource)

        return PublicPlayerProfile(
            userId: userId,
            username: username,
            provider: provider,
            stats: stats
        )
    }

    private func parsePublicPlayerStats(from source: [String: Any]) -> PublicPlayerStats {
        func intValue(_ keys: [String]) -> Int {
            for key in keys {
                if let value = source[key] as? Int {
                    return value
                }
                if let value = source[key] as? Double {
                    return Int(value)
                }
                if let value = source[key] as? NSNumber {
                    return value.intValue
                }
                if let value = source[key] as? String, let int = Int(value) {
                    return int
                }
            }
            return 0
        }

        func intArrayValue(_ keys: [String]) -> [Int] {
            for key in keys {
                if let values = source[key] as? [Int] {
                    return values
                }
                if let values = source[key] as? [Any] {
                    return values.compactMap {
                        if let int = $0 as? Int { return int }
                        if let double = $0 as? Double { return Int(double) }
                        if let number = $0 as? NSNumber { return number.intValue }
                        if let string = $0 as? String { return Int(string) }
                        return nil
                    }
                }
            }
            return []
        }

        return PublicPlayerStats(
            gamesPlayed: intValue(["gamesPlayed", "games_played"]),
            wins: intValue(["wins"]),
            losses: intValue(["losses"]),
            bestScore: intValue(["bestScore", "best_score"]),
            totalScore: intValue(["totalScore", "total_score"]),
            elo: intValue(["elo", "rating"]),
            peakElo: intValue(["peakElo", "peak_elo"]),
            winStreak: intValue(["winStreak", "win_streak"]),
            bestWinStreak: intValue(["bestWinStreak", "best_win_streak"]),
            beatenBotsCount: intValue(["beatenBotsCount", "beaten_bots_count"]),
            recentScores: intArrayValue(["recentScores", "recent_scores"]),
            selectedSkin: string(in: source, keys: ["selectedSkin", "selected_skin", "skin"])
        )
    }

    private func parseProfile(_ value: Any?) -> RemotePlayerProfile? {
        guard let source = dictionary(from: value) else { return nil }

        guard let userId = string(in: source, keys: ["userId", "user_id", "id", "_id"]) else {
            return nil
        }

        let provider = parseProvider(from: string(in: source, keys: ["provider", "authProvider", "auth_provider"])) ?? .guest
        let username = string(in: source, keys: ["username", "name", "displayName", "display_name"]) ?? "Player"

        let statsSource = dictionary(in: source, keys: ["stats", "playerStats", "player_stats"]) ?? source
        let stats = Self.parsePlayerStats(from: statsSource)

        return RemotePlayerProfile(
            userId: userId,
            username: username,
            provider: provider,
            stats: stats
        )
    }

    static func parsePlayerStats(from source: [String: Any]) -> PlayerStats {
        func intValue(_ keys: [String]) -> Int? {
            for key in keys {
                if let value = source[key] as? Int {
                    return value
                }
                if let value = source[key] as? Double {
                    return Int(value)
                }
                if let value = source[key] as? NSNumber {
                    return value.intValue
                }
                if let value = source[key] as? String, let int = Int(value) {
                    return int
                }
            }
            return nil
        }

        func intArrayValue(_ keys: [String]) -> [Int] {
            for key in keys {
                if let values = source[key] as? [Int] {
                    return values
                }
                if let values = source[key] as? [Any] {
                    return values.compactMap {
                        if let int = $0 as? Int { return int }
                        if let double = $0 as? Double { return Int(double) }
                        if let number = $0 as? NSNumber { return number.intValue }
                        if let string = $0 as? String { return Int(string) }
                        return nil
                    }
                }
            }
            return []
        }

        func stringArrayValue(_ keys: [String]) -> [String] {
            for key in keys {
                if let values = source[key] as? [String] {
                    return values
                }
                if let values = source[key] as? [Any] {
                    return values.compactMap {
                        if let string = $0 as? String { return string }
                        if let number = $0 as? NSNumber { return number.stringValue }
                        return nil
                    }
                }
            }
            return []
        }

        let elo = intValue(["elo", "rating"]) ?? 1200
        let winStreak = intValue(["winStreak", "win_streak"]) ?? 0

        return PlayerStats(
            gamesPlayed: intValue(["gamesPlayed", "games_played"]) ?? 0,
            wins: intValue(["wins"]) ?? 0,
            losses: intValue(["losses"]) ?? 0,
            bestScore: intValue(["bestScore", "best_score"]) ?? 0,
            totalScore: intValue(["totalScore", "total_score"]) ?? 0,
            elo: elo,
            bread: intValue(["bread"]) ?? 0,
            totalBreadCollected: intValue(["totalBreadCollected", "total_bread_collected"]) ?? 0,
            recentScores: intArrayValue(["recentScores", "recent_scores"]),
            beatenBots: stringArrayValue(["beatenBots", "beaten_bots"]),
            peakElo: PlayerStats.normalizedPeakElo(
                elo: elo,
                peakElo: intValue(["peakElo", "peak_elo"])
            ),
            winStreak: winStreak,
            bestWinStreak: PlayerStats.normalizedBestWinStreak(
                winStreak: winStreak,
                bestWinStreak: intValue(["bestWinStreak", "best_win_streak"])
            )
        )
    }

    func parseAssignment(_ value: Any?,
                         fallbackMode: MatchmakingMode?,
                         fallbackRoomCode: String?) -> MultiplayerMatchAssignment? {
        if let dict = dictionary(from: value) {
            if let found = bool(in: dict, keys: ["found", "hasMatch"]), !found {
                return nil
            }

            let source: [String: Any]
            if let nested = dictionary(in: dict, keys: ["assignment", "match", "value"]) {
                source = nested
            } else {
                source = dict
            }

            guard let matchId = string(in: source, keys: ["matchId", "match_id", "id", "_id"]) else {
                return nil
            }

            let seed = int(in: source, keys: ["seed", "mapSeed", "worldSeed"]) ?? Int.random(in: 1...999999)
            let parsedMode = parseMode(from: string(in: source, keys: ["mode", "queueMode"])) ?? fallbackMode ?? .quickPlay
            let ranked = bool(in: source, keys: ["isRanked", "ranked"]) ?? parsedMode.isRanked
            let roomCode = string(in: source, keys: ["roomCode", "room_code", "code"]) ?? fallbackRoomCode
            let gameKitCode = string(in: source, keys: ["gameKitSessionCode", "sessionCode", "gameKitCode"])
            let localSlot = string(in: source, keys: ["localPlayerSlot", "playerSlot", "slot", "side"])?.lowercased()
            let isHost = bool(in: source, keys: ["isGameKitHost", "gameKitHost", "isHost"])
                ?? (localSlot == "p1" || localSlot == "host")

            return MultiplayerMatchAssignment(
                matchId: matchId,
                seed: seed,
                opponentName: string(in: source, keys: ["opponentName", "opponent", "enemyName", "name"]) ?? "OPPONENT",
                opponentSkinId: string(in: source, keys: ["opponentSkinId", "opponentSkin", "enemySkin"]),
                gameKitSessionCode: gameKitCode,
                mode: parsedMode,
                isRanked: ranked,
                roomCode: roomCode,
                isGameKitHost: isHost
            )
        }

        if let matchId = string(from: value), let fallbackMode {
            return MultiplayerMatchAssignment(
                matchId: matchId,
                seed: Int.random(in: 1...999999),
                opponentName: "OPPONENT",
                opponentSkinId: nil,
                gameKitSessionCode: nil,
                mode: fallbackMode,
                isRanked: fallbackMode.isRanked,
                roomCode: fallbackRoomCode,
                isGameKitHost: false
            )
        }

        return nil
    }

    private func parseBattleRoyaleAssignment(_ value: Any?) throws -> BattleRoyaleAssignment {
        guard let dict = dictionary(from: value) else {
            throw ConvexError.invalidResponse
        }

        guard let lobbyId = string(in: dict, keys: ["lobbyId", "lobby_id", "id", "_id"]),
              let entrantId = string(in: dict, keys: ["entrantId", "entrant_id"]) else {
            throw ConvexError.invalidResponse
        }

        return BattleRoyaleAssignment(
            lobbyId: lobbyId,
            entrantId: entrantId,
            seed: int(in: dict, keys: ["seed"]) ?? 1,
            status: parseBattleRoyaleStatus(from: string(in: dict, keys: ["status"])) ?? .open,
            playerCount: int(in: dict, keys: ["playerCount", "players"]) ?? 1,
            aliveCount: int(in: dict, keys: ["aliveCount", "alive"]) ?? 1,
            buyIn: int(in: dict, keys: ["buyIn", "buy_in"]) ?? 25,
            maxPlayers: int(in: dict, keys: ["maxPlayers", "max_players"]) ?? 100,
            bread: int(in: dict, keys: ["bread"]) ?? 0
        )
    }

    private func parseBattleRoyaleState(_ value: Any?) throws -> BattleRoyaleState {
        guard let dict = dictionary(from: value),
              let lobbyId = string(in: dict, keys: ["lobbyId", "lobby_id", "id", "_id"]),
              let entrantId = string(in: dict, keys: ["entrantId", "entrant_id"]),
              let localDict = dictionary(in: dict, keys: ["local", "entrant"]),
              let local = parseBattleRoyaleEntrant(localDict) else {
            throw ConvexError.invalidResponse
        }

        let leaderboard = dictionaryArray(in: dict, keys: ["leaderboard", "leaders"])
            .compactMap(parseBattleRoyaleEntrant)
        let ghosts = dictionaryArray(in: dict, keys: ["ghosts", "snapshots"])
            .compactMap(parseBattleRoyaleGhost)

        return BattleRoyaleState(
            lobbyId: lobbyId,
            entrantId: entrantId,
            seed: int(in: dict, keys: ["seed"]) ?? 1,
            status: parseBattleRoyaleStatus(from: string(in: dict, keys: ["status"])) ?? .open,
            buyIn: int(in: dict, keys: ["buyIn", "buy_in"]) ?? 25,
            maxPlayers: int(in: dict, keys: ["maxPlayers", "max_players"]) ?? 100,
            playerCount: int(in: dict, keys: ["playerCount", "players"]) ?? leaderboard.count,
            aliveCount: int(in: dict, keys: ["aliveCount", "alive"]) ?? leaderboard.filter(\.alive).count,
            local: local,
            leaderboard: leaderboard,
            ghosts: ghosts
        )
    }

    private func parseBattleRoyaleEntrant(_ dict: [String: Any]) -> BattleRoyaleEntrant? {
        guard let playerId = string(in: dict, keys: ["playerId", "userId", "id", "_id"]) else {
            return nil
        }

        return BattleRoyaleEntrant(
            playerId: playerId,
            username: string(in: dict, keys: ["username", "name"]) ?? "PLAYER",
            skinId: string(in: dict, keys: ["skinId", "skin"]),
            score: int(in: dict, keys: ["score"]) ?? 0,
            alive: bool(in: dict, keys: ["alive"]) ?? true,
            placement: int(in: dict, keys: ["placement", "place"]),
            prize: int(in: dict, keys: ["prize", "amount"]) ?? 0
        )
    }

    private func parseBattleRoyaleGhost(_ dict: [String: Any]) -> BattleRoyaleGhost? {
        guard let playerId = string(in: dict, keys: ["playerId", "userId", "id", "_id"]) else {
            return nil
        }

        return BattleRoyaleGhost(
            playerId: playerId,
            username: string(in: dict, keys: ["username", "name"]) ?? "PLAYER",
            skinId: string(in: dict, keys: ["skinId", "skin"]),
            score: int(in: dict, keys: ["score"]) ?? 0,
            y: double(in: dict, keys: ["y"]) ?? 0,
            rotation: double(in: dict, keys: ["rotation"]) ?? 0,
            wingPhase: int(in: dict, keys: ["wingPhase", "wing"]) ?? 1
        )
    }

    private func parseBattleRoyaleStatus(from raw: String?) -> BattleRoyaleStatus? {
        guard let raw else { return nil }
        return BattleRoyaleStatus(rawValue: raw.lowercased())
    }

    private func parseMode(from raw: String?) -> MatchmakingMode? {
        guard let raw else { return nil }
        switch raw.lowercased() {
        case "quick", "quickplay", "quick_play":
            return .quickPlay
        case "ranked", "elo":
            return .ranked
        case "private", "room", "private_room":
            return .privateRoom
        case "battle_royale", "battleroyale", "battle":
            return .battleRoyale
        default:
            return nil
        }
    }

    private func parseProvider(from raw: String?) -> AuthProvider? {
        guard let raw else { return nil }
        switch raw.lowercased() {
        case "apple", "siwa":
            return .apple
        case "gamecenter", "game_center", "gc":
            return .gameCenter
        case "guest", "anonymous":
            return .guest
        default:
            return nil
        }
    }

    private func dictionary(from value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private func dictionary(in dict: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = dict[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private func dictionaryArray(in dict: [String: Any], keys: [String]) -> [[String: Any]] {
        for key in keys {
            if let values = dict[key] as? [[String: Any]] {
                return values
            }
            if let values = dict[key] as? [Any] {
                return values.compactMap { $0 as? [String: Any] }
            }
        }
        return []
    }

    private func stringArray(in dict: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = dict[key] as? [String] {
                return values
            }
            if let values = dict[key] as? [Any] {
                return values.compactMap { string(from: $0) }
            }
        }
        return []
    }

    private func intArray(in dict: [String: Any], keys: [String]) -> [Int] {
        for key in keys {
            if let values = dict[key] as? [Int] {
                return values
            }
            if let values = dict[key] as? [Any] {
                return values.compactMap { int(from: $0) }
            }
        }
        return []
    }

    private func string(in dict: [String: Any]?, keys: [String]) -> String? {
        guard let dict else { return nil }
        for key in keys {
            if let value = string(from: dict[key]) {
                return value
            }
        }
        return nil
    }

    private func int(in dict: [String: Any]?, keys: [String]) -> Int? {
        guard let dict else { return nil }
        for key in keys {
            if let value = int(from: dict[key]) {
                return value
            }
        }
        return nil
    }

    private func bool(in dict: [String: Any]?, keys: [String]) -> Bool? {
        guard let dict else { return nil }
        for key in keys {
            if let value = bool(from: dict[key]) {
                return value
            }
        }
        return nil
    }

    private func double(in dict: [String: Any]?, keys: [String]) -> Double? {
        guard let dict else { return nil }
        for key in keys {
            if let value = double(from: dict[key]) {
                return value
            }
        }
        return nil
    }

    private func date(in dict: [String: Any]?, keys: [String]) -> Date? {
        guard let dict else { return nil }

        for key in keys {
            if let value = dict[key] {
                if let seconds = int(from: value) {
                    return Date(timeIntervalSince1970: TimeInterval(seconds))
                }
                if let stringValue = string(from: value) {
                    if let seconds = TimeInterval(stringValue) {
                        return Date(timeIntervalSince1970: seconds)
                    }
                    if let parsed = ISO8601DateFormatter().date(from: stringValue) {
                        return parsed
                    }
                }
            }
        }

        return nil
    }

    private func string(from value: Any?) -> String? {
        if let value = value as? String {
            return value
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private func int(from value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double {
            return Int(value)
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    private func double(from value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? CGFloat {
            return Double(value)
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        if let value = value as? String {
            return Double(value)
        }
        return nil
    }

    private func bool(from value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        if let value = value as? String {
            switch value.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }
}

extension LocalStatsSnapshot {
    var asDictionary: [String: Any] {
        [
            "username": username,
            "gamesPlayed": gamesPlayed,
            "wins": wins,
            "losses": losses,
            "bestScore": bestScore,
            "totalScore": totalScore,
            "elo": elo,
            "bread": bread,
            "totalBreadCollected": totalBreadCollected,
            "recentScores": recentScores,
            "beatenBots": beatenBots,
            "peakElo": peakElo,
            "winStreak": winStreak,
            "bestWinStreak": bestWinStreak,
        ]
    }
}

// MARK: - Errors

enum ConvexError: Error, LocalizedError {
    case requestFailed
    case invalidResponse
    case server(String)
    case authFailed(Int)  // 401 or 403 — never retry these

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Network request failed"
        case .invalidResponse:
            return "Invalid response format"
        case .server(let message):
            return message
        case .authFailed(let code):
            return "Authentication failed (\(code))"
        }
    }

    var isAuthError: Bool {
        if case .authFailed = self { return true }
        return false
    }
}
