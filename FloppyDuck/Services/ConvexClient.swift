import Foundation

/// Abstraction used by multiplayer session logic so tests can inject a mock backend.
protocol MultiplayerBackendClient: Sendable {
    func joinMatchmakingQueue(mode: MatchmakingMode, rating: Int) async throws -> QueueTicket
    func leaveMatchmakingQueue(ticketId: String?) async throws
    func checkQueue(ticketId: String?, mode: MatchmakingMode?) async throws -> MultiplayerMatchAssignment?

    func createRoom(rating: Int) async throws -> QueueTicket
    func joinRoom(code: String, rating: Int) async throws -> QueueTicket
    func leaveRoom(code: String) async throws
    func checkRoom(code: String) async throws -> MultiplayerMatchAssignment?

    func reportScore(matchId: String, score: Int) async throws
    func getMatchState(matchId: String) async throws -> MultiplayerMatchState

    func finishMatch(matchId: String,
                     score: Int,
                     mode: MatchmakingMode,
                     fallbackOpponentScore: Int,
                     opponentName: String?) async throws -> MultiplayerMatchResult
}

/// REST client for the Convex backend.
/// Handles matchmaking, private rooms, score sync, and match results.
actor ConvexClient: MultiplayerBackendClient {
    static let shared = ConvexClient()

    // MARK: - Configuration

    private static let baseURLInfoKey = "CONVEX_BASE_URL"
    private static let fallbackBaseURL = "https://zany-ram-588.convex.cloud"

    private let baseURL: String

    private let session: URLSession

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
        return fallbackBaseURL
    }

    // MARK: - Raw Requests

    private func queryRaw(_ functionName: String, args: [String: Any] = [:]) async throws -> Any? {
        try await requestRaw(endpoint: "query", functionName: functionName, args: args)
    }

    private func mutationRaw(_ functionName: String, args: [String: Any] = [:]) async throws -> Any? {
        try await requestRaw(endpoint: "mutation", functionName: functionName, args: args)
    }

    private func requestRaw(endpoint: String,
                            functionName: String,
                            args: [String: Any]) async throws -> Any? {
        guard let url = URL(string: "\(baseURL)/api/\(endpoint)") else {
            throw ConvexError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "path": functionName,
            "args": args,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ConvexError.requestFailed
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = object as? [String: Any] else {
            throw ConvexError.invalidResponse
        }

        if let error = string(in: root, keys: ["error", "message"]) {
            throw ConvexError.server(error)
        }

        return root["value"]
    }

    // MARK: - Matchmaking

    func joinMatchmakingQueue(mode: MatchmakingMode, rating: Int) async throws -> QueueTicket {
        let value = try await mutationRaw("matchmaking:joinQueue", args: [
            "mode": mode.queueValue,
            "rating": rating,
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

    func createRoom(rating: Int) async throws -> QueueTicket {
        let value = try await mutationRaw("matchmaking:createRoom", args: ["rating": rating])
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

    func joinRoom(code: String, rating: Int) async throws -> QueueTicket {
        let normalized = String(code.prefix(GK.roomCodeLength)).uppercased()

        let value = try await mutationRaw("matchmaking:joinRoom", args: [
            "code": normalized,
            "rating": rating,
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
                opponentName: opponentName
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
            isRanked: isRanked
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

// MARK: - Errors

enum ConvexError: Error, LocalizedError {
    case requestFailed
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Network request failed"
        case .invalidResponse:
            return "Invalid response format"
        case .server(let message):
            return message
        }
    }
}
