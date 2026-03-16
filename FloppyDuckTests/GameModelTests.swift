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
