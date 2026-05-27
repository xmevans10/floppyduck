import XCTest
@testable import FloppyDuck

final class GameModelTests: XCTestCase {

    // MARK: - GameModeConfig

    func testGameModeConfigDefaultSeed() {
        let config1 = GameModeConfig(mode: .classic)
        let config2 = GameModeConfig(mode: .classic)

        // Seeds are random in 1...999999
        XCTAssertTrue((1...999999).contains(config1.seed),
            "Seed should be in range 1–999999")
        XCTAssertTrue((1...999999).contains(config2.seed),
            "Seed should be in range 1–999999")
    }

    func testGameModeConfigEquality() {
        let config1 = GameModeConfig(mode: .classic, seed: 42)
        let config2 = GameModeConfig(mode: .classic, seed: 42)

        // Equality is based on UUID, so two configs with identical fields differ
        XCTAssertNotEqual(config1, config2,
            "Equality should use UUID, not field comparison")

        // Same value must be equal to itself
        XCTAssertEqual(config1, config1)
    }

    // MARK: - MatchmakingMode

    func testMatchmakingModeQueueTimeout() {
        XCTAssertEqual(MatchmakingMode.quickPlay.queueTimeout, 30)
        XCTAssertEqual(MatchmakingMode.ranked.queueTimeout, 30)
        XCTAssertEqual(MatchmakingMode.privateRoom.queueTimeout, 120)
    }

    func testMultiplayerMatchAssignmentDefaultsRealtimeMetadata() {
        let assignment = MultiplayerMatchAssignment(
            matchId: "match-1",
            seed: 42,
            opponentName: "Rival",
            mode: .quickPlay,
            isRanked: false,
            roomCode: nil
        )

        XCTAssertNil(assignment.opponentSkinId)
        XCTAssertNil(assignment.gameKitSessionCode)
        XCTAssertFalse(assignment.isGameKitHost)
    }

    func testConvexAssignmentParsesRealtimeMetadataAndHostRole() async {
        let client = ConvexClient()
        let value: [String: Any] = [
            "found": true,
            "assignment": [
                "matchId": "match-42",
                "seed": 8675309,
                "opponentName": "Rival",
                "opponentSkinId": "robot",
                "gameKitSessionCode": "123456",
                "mode": "ranked",
                "isRanked": true,
                "localPlayerSlot": "p1",
                "isGameKitHost": true,
            ] as [String: Any],
        ]

        let assignment = await client.parseAssignment(
            value,
            fallbackMode: .quickPlay,
            fallbackRoomCode: nil
        )

        XCTAssertEqual(assignment?.matchId, "match-42")
        XCTAssertEqual(assignment?.seed, 8675309)
        XCTAssertEqual(assignment?.opponentSkinId, "robot")
        XCTAssertEqual(assignment?.gameKitSessionCode, "123456")
        XCTAssertEqual(assignment?.mode, .ranked)
        XCTAssertTrue(assignment?.isRanked == true)
        XCTAssertTrue(assignment?.isGameKitHost == true)
    }

    @MainActor
    func testStartHeadToHeadBuildsPowerUpConfig() {
        let manager = GameManager(initialStats: PlayerStats())
        let assignment = MultiplayerMatchAssignment(
            matchId: "match-host",
            seed: 12345,
            opponentName: "Rival",
            opponentSkinId: "robot",
            gameKitSessionCode: "654321",
            mode: .quickPlay,
            isRanked: false,
            roomCode: nil,
            isGameKitHost: true
        )

        manager.startHeadToHead(matchAssignment: assignment)

        let config = manager.activeGameConfig
        XCTAssertEqual(config?.mode, .headToHead)
        XCTAssertEqual(config?.seed, 12345)
        XCTAssertTrue(config?.powerUpsEnabled == true)
        XCTAssertEqual(config?.gameKitSessionCode, "654321")
        XCTAssertTrue(config?.isGameKitHost == true)
        XCTAssertEqual(config?.matchId, "match-host")
        XCTAssertEqual(config?.opponentName, "Rival")
        XCTAssertEqual(config?.opponentSkinId, "robot")
    }

    func testMultiplayerMatchStateDefaultsOpponentSkin() {
        let state = MultiplayerMatchState(
            matchId: "match-1",
            localScore: 3,
            opponentScore: 2,
            isFinished: false,
            opponentName: "Rival"
        )

        XCTAssertNil(state.opponentSkinId)
    }

    func testGameKitPlayerGroupUsesNumericSessionCode() {
        XCTAssertEqual(GameKitSession.playerGroup(for: "123456"), 123456)
    }

    func testGameKitPlayerGroupIsStableForRoomCode() {
        let first = GameKitSession.playerGroup(for: "DUCKY")
        let second = GameKitSession.playerGroup(for: "DUCKY")

        XCTAssertEqual(first, second)
        XCTAssertTrue((0...Int(Int32.max)).contains(first))
    }

    func testReadyStateCarriesScoreOnlyStartHandshake() {
        let state = ReadyState(
            p1Ready: 100,
            p2Ready: 200,
            startAtMs: 300,
            status: "active"
        )
        XCTAssertEqual(state.p1Ready, 100)
        XCTAssertEqual(state.p2Ready, 200)
        XCTAssertEqual(state.startAtMs, 300)
        XCTAssertEqual(state.status, "active")
    }

    func testBattleRoyaleModeMetadata() {
        XCTAssertEqual(GameMode.battleRoyale.shareDisplayName, "Battle Royale")
        XCTAssertEqual(MatchmakingMode.battleRoyale.queueValue, "battle_royale")
        XCTAssertFalse(MatchmakingMode.battleRoyale.isRanked)
        XCTAssertEqual(MatchmakingMode.battleRoyale.queueTimeout, 300)
    }

    func testBattleRoyaleGameConfigStoresLobbyMetadata() {
        let config = GameModeConfig(
            mode: .battleRoyale,
            seed: 99,
            matchmakingMode: .battleRoyale,
            battleRoyaleLobbyId: "lobby-1",
            battleRoyaleEntrantId: "entrant-1"
        )

        XCTAssertEqual(config.mode, .battleRoyale)
        XCTAssertEqual(config.battleRoyaleLobbyId, "lobby-1")
        XCTAssertEqual(config.battleRoyaleEntrantId, "entrant-1")
    }

    // MARK: - DuckSkin

    func testDuckSkinSpriteSize() {
        for skin in DuckSkin.allCases {
            let size = skin.spriteSize
            XCTAssertGreaterThan(size.width, 0,
                "\(skin.rawValue) sprite width should be positive")
            XCTAssertGreaterThan(size.height, 0,
                "\(skin.rawValue) sprite height should be positive")
        }
    }

    func testProductionSkinSpriteSizeKeepsMallardBodyScale() {
        let mallardBodyWidth = GK.duckRadius * 2.8

        let pirateScale = mallardBodyWidth / 253
        XCTAssertEqual(DuckSkin.pirate.spriteSize.width, CGFloat(333) * pirateScale, accuracy: 0.001)
        XCTAssertEqual(DuckSkin.pirate.spriteSize.height, CGFloat(281) * pirateScale, accuracy: 0.001)
    }

    func testDuckSkinBreadPrices() {
        // Only "normal" skins have a bread price
        let normalSkins = DuckSkin.allCases.filter { $0.isNormal }
        let otherSkins  = DuckSkin.allCases.filter { !$0.isNormal }

        for skin in normalSkins {
            XCTAssertNotNil(skin.breadPrice,
                "\(skin.rawValue) is a normal skin and should have a bread price")
            XCTAssertGreaterThan(skin.breadPrice ?? 0, 0)
        }

        for skin in otherSkins {
            XCTAssertNil(skin.breadPrice,
                "\(skin.rawValue) is not a normal skin and should not have a bread price")
        }
    }

    // MARK: - BackgroundTheme

    func testPlaceholderAppStoreIDDoesNotProduceShareURL() {
        XCTAssertNil(GK.makeAppStoreURL(appID: "000000000"))
        XCTAssertNil(GK.makeAppStoreURL(appID: ""))
        XCTAssertNil(GK.makeAppStoreURL(appID: "not-a-real-id"))
    }

    func testRealAppStoreIDProducesShareURL() {
        let url = GK.makeAppStoreURL(appID: "1234567890")
        XCTAssertEqual(url?.absoluteString, "https://apps.apple.com/app/floppy-duck/id1234567890")
    }

    func testBackgroundThemeGradients() {
        for theme in BackgroundTheme.allCases {
            XCTAssertGreaterThanOrEqual(theme.gradientColors.count, 2,
                "\(theme.rawValue) should have at least 2 gradient colors")
        }
    }

    func testBackgroundThemeStarVisibility() {
        // Dark themes show stars
        XCTAssertTrue(BackgroundTheme.night.showStars)
        XCTAssertTrue(BackgroundTheme.space.showStars)
        XCTAssertTrue(BackgroundTheme.neonCity.showStars)
        XCTAssertTrue(BackgroundTheme.pixelTokyo.showStars)

        // Bright/outdoor themes do not
        XCTAssertFalse(BackgroundTheme.day.showStars)
        XCTAssertFalse(BackgroundTheme.sunset.showStars)
        XCTAssertFalse(BackgroundTheme.underwater.showStars)
        XCTAssertFalse(BackgroundTheme.volcano.showStars)
        XCTAssertFalse(BackgroundTheme.arctic.showStars)
    }
}
