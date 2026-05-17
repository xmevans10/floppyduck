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
