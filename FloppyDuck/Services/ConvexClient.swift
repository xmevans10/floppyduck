import Foundation

/// Abstraction used by multiplayer/session/auth logic so tests can inject a mock backend.
protocol MultiplayerBackendClient: Sendable {
    func setAuthContext(deviceId: String, sessionToken: String?) async

    func bootstrapGuest(deviceId: String,
                        localStats: LocalStatsSnapshot?) async throws -> AuthBootstrapResponse

    func linkApple(identityToken: String,
                   nonce: String,
                   deviceId: String,
                   displayName: String?) async throws -> AuthLinkResponse

    func getProfile() async throws -> RemotePlayerProfile
    func signOutSession() async throws
    func deleteAccount() async throws

    func joinMatchmakingQueue(mode: MatchmakingMode) async throws -> QueueTicket
    func leaveMatchmakingQueue(ticketId: String?) async throws
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

    func getLeaderboard(limit: Int) async throws -> [LeaderboardEntry]
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

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ConvexError.requestFailed
        }

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
            print("[ConvexClient] \(functionName) error: \(msg)")
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

            return MultiplayerMatchState(
                matchId: matchId,
                localScore: local,
                opponentScore: opponent,
                isFinished: finished,
                opponentName: opponentName,
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
            opponentName: nil
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

    // MARK: - Leaderboard

    func getLeaderboard(limit: Int = 20) async throws -> [LeaderboardEntry] {
        let value = try await queryRaw("ratings:leaderboard", args: ["limit": limit])
        guard let items = value as? [Any] else { return [] }

        return items.enumerated().compactMap { i, item in
            guard let dict = item as? [String: Any],
                  let userId = string(in: dict, keys: ["userId", "user_id", "id", "_id"]),
                  let rating = int(in: dict, keys: ["rating", "elo"]) else {
                return nil
            }

            return LeaderboardEntry(
                id: userId,
                username: string(in: dict, keys: ["username", "name", "displayName"]) ?? "Player",
                rating: rating,
                rank: i + 1
            )
        }
    }

    // MARK: - Parsing Helpers

    private func parseProfile(_ value: Any?) -> RemotePlayerProfile? {
        guard let source = dictionary(from: value) else { return nil }

        guard let userId = string(in: source, keys: ["userId", "user_id", "id", "_id"]) else {
            return nil
        }

        let provider = parseProvider(from: string(in: source, keys: ["provider", "authProvider", "auth_provider"])) ?? .guest
        let username = string(in: source, keys: ["username", "name", "displayName", "display_name"]) ?? "Player"

        let statsSource = dictionary(in: source, keys: ["stats", "playerStats", "player_stats"]) ?? source
        let stats = parseStats(from: statsSource)

        return RemotePlayerProfile(
            userId: userId,
            username: username,
            provider: provider,
            stats: stats
        )
    }

    private func parseStats(from source: [String: Any]) -> PlayerStats {
        PlayerStats(
            gamesPlayed: int(in: source, keys: ["gamesPlayed", "games_played"]) ?? 0,
            wins: int(in: source, keys: ["wins"]) ?? 0,
            losses: int(in: source, keys: ["losses"]) ?? 0,
            bestScore: int(in: source, keys: ["bestScore", "best_score"]) ?? 0,
            totalScore: int(in: source, keys: ["totalScore", "total_score"]) ?? 0,
            elo: int(in: source, keys: ["elo", "rating"]) ?? 1200,
            bread: int(in: source, keys: ["bread"]) ?? 0,
            totalBreadCollected: int(in: source, keys: ["totalBreadCollected", "total_bread_collected"]) ?? 0,
            recentScores: intArray(in: source, keys: ["recentScores", "recent_scores"]),
            beatenBots: stringArray(in: source, keys: ["beatenBots", "beaten_bots"])
        )
    }

    private func parseAssignment(_ value: Any?,
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

            return MultiplayerMatchAssignment(
                matchId: matchId,
                seed: seed,
                opponentName: string(in: source, keys: ["opponentName", "opponent", "enemyName", "name"]) ?? "OPPONENT",
                mode: parsedMode,
                isRanked: ranked,
                roomCode: roomCode
            )
        }

        if let matchId = string(from: value), let fallbackMode {
            return MultiplayerMatchAssignment(
                matchId: matchId,
                seed: Int.random(in: 1...999999),
                opponentName: "OPPONENT",
                mode: fallbackMode,
                isRanked: fallbackMode.isRanked,
                roomCode: fallbackRoomCode
            )
        }

        return nil
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
        default:
            return nil
        }
    }

    private func parseProvider(from raw: String?) -> AuthProvider? {
        guard let raw else { return nil }
        switch raw.lowercased() {
        case "apple", "siwa":
            return .apple
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

private extension LocalStatsSnapshot {
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
