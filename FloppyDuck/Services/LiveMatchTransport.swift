import Foundation
import CoreGraphics

@MainActor final class LiveMatchTransport {
    private let client: MultiplayerBackendClient
    private let matchId: String
    private weak var scene: GameScene?

    private var upsertTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var isRunning = false

    private let tickInterval: UInt64 = 100_000_000 // 10 Hz = 100 ms

    init(client: MultiplayerBackendClient, matchId: String) {
        self.client = client
        self.matchId = matchId
    }

    func attach(scene: GameScene) {
        self.scene = scene
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let client = self.client
        let matchId = self.matchId

        upsertTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { break }
                await self.upsertCurrentPosition(client: client, matchId: matchId)
                try? await Task.sleep(nanoseconds: tickInterval)
            }
        }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { break }
                await self.pollOpponentPosition(client: client, matchId: matchId)
                try? await Task.sleep(nanoseconds: tickInterval)
            }
        }
    }

    func stop() {
        isRunning = false
        upsertTask?.cancel()
        pollTask?.cancel()
        upsertTask = nil
        pollTask = nil
    }

    private func upsertCurrentPosition(client: MultiplayerBackendClient, matchId: String) async {
        guard scene?.phase == .playing, let snapshot = scene?.liveMatchSnapshot() else { return }

        do {
            try await client.upsertLivePosition(
                matchId: matchId,
                x: Double(snapshot.x),
                y: Double(snapshot.y),
                velY: Double(snapshot.velY),
                rotation: Double(snapshot.rotation),
                wingPhase: Int(snapshot.wingPhase),
                score: snapshot.score
            )
        } catch {
            // Transient upsert failures are non-fatal — we'll retry next tick.
        }
    }

    private func pollOpponentPosition(client: MultiplayerBackendClient, matchId: String) async {
        do {
            guard let pos = try await client.getOpponentPosition(matchId: matchId) else {
                return
            }

            scene?.setGhostPosition(
                x: CGFloat(pos.x),
                y: CGFloat(pos.y),
                velY: CGFloat(pos.velY),
                rotation: CGFloat(pos.rotation),
                wingPhase: pos.wingPhase
            )
            scene?.setOpponentScore(pos.score)
        } catch {
            // Transient poll failures are non-fatal — we'll retry next tick.
        }
    }
}
