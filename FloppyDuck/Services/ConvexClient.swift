import Foundation

/// REST client for the Convex backend.
/// Handles all multiplayer state: matches, ratings, matchmaking queue.
actor ConvexClient {
    static let shared = ConvexClient()
    
    // MARK: - Configuration
    // Update this URL to your Convex deployment
    private let baseURL = "https://peaceful-partridge-81.convex.cloud"
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    // MARK: - Generic Request
    
    private func query<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        let url = URL(string: "\(baseURL)/api/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "path": functionName,
            "args": args
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ConvexError.requestFailed
        }
        
        let wrapper = try decoder.decode(ConvexResponse<T>.self, from: data)
        guard let value = wrapper.value else {
            throw ConvexError.noData
        }
        return value
    }
    
    private func mutation<T: Decodable>(_ functionName: String, args: [String: Any] = [:]) async throws -> T {
        let url = URL(string: "\(baseURL)/api/mutation")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "path": functionName,
            "args": args
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ConvexError.requestFailed
        }
        
        let wrapper = try decoder.decode(ConvexResponse<T>.self, from: data)
        guard let value = wrapper.value else {
            throw ConvexError.noData
        }
        return value
    }
    
    // MARK: - Match Operations
    
    func createSoloMatch() async throws -> String {
        let seed = Int.random(in: 1...999999)
        let result: ConvexId = try await mutation("matches:createSolo", args: ["seed": seed])
        return result.id
    }
    
    func joinMatchmakingQueue(mode: String, rating: Int) async throws {
        let _: ConvexId = try await mutation("matchmaking:joinQueue", args: [
            "mode": mode,
            "rating": rating
        ])
    }
    
    func leaveMatchmakingQueue() async throws {
        let _: ConvexEmpty = try await mutation("matchmaking:leaveQueue")
    }
    
    func checkQueue() async throws -> String? {
        let result: ConvexMatchCheck = try await query("matchmaking:checkQueue")
        return result.matchId
    }
    
    func finishMatch(matchId: String, score: Int) async throws {
        let _: ConvexEmpty = try await mutation("matches:finishMatch", args: [
            "matchId": matchId,
            "score": score
        ])
    }
    
    func getLeaderboard(limit: Int = 20) async throws -> [LeaderboardEntry] {
        let result: [ConvexLeaderboardEntry] = try await query("ratings:leaderboard", args: [
            "limit": limit
        ])
        return result.enumerated().map { i, entry in
            LeaderboardEntry(
                id: entry.userId,
                username: entry.username ?? "Player",
                rating: entry.rating,
                rank: i + 1
            )
        }
    }
}

// MARK: - Response Types

private struct ConvexResponse<T: Decodable>: Decodable {
    let value: T?
    let status: String?
}

private struct ConvexId: Decodable {
    let id: String
    
    init(from decoder: Decoder) throws {
        // Handle both string response and object with _id
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self.id = str
        } else {
            let dict = try container.decode([String: String].self)
            self.id = dict["_id"] ?? dict["id"] ?? ""
        }
    }
}

private struct ConvexEmpty: Decodable {}

private struct ConvexMatchCheck: Decodable {
    let matchId: String?
}

private struct ConvexLeaderboardEntry: Decodable {
    let userId: String
    let username: String?
    let rating: Int
}

// MARK: - Errors

enum ConvexError: Error, LocalizedError {
    case requestFailed
    case noData
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .requestFailed: return "Network request failed"
        case .noData: return "No data returned"
        case .invalidResponse: return "Invalid response format"
        }
    }
}
