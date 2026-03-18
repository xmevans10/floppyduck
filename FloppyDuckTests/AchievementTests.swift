import XCTest
@testable import FloppyDuck

final class AchievementTests: XCTestCase {

    // MARK: - Score Milestone Unlocks

    func testScoreMilestones() {
        var progress = AchievementProgress()
        let stats = PlayerStats(gamesPlayed: 1)

        // Score 1 → firstFlight
        let result1 = progress.check(event: .gameEnded(score: 1), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result1.contains(.firstFlight))
        XCTAssertFalse(result1.contains(.gettingStarted))

        // Score 10 → gettingStarted (and firstFlight already unlocked)
        let result10 = progress.check(event: .gameEnded(score: 10), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result10.contains(.gettingStarted))
        XCTAssertFalse(result10.contains(.firstFlight),
            "firstFlight should not appear again — already unlocked")

        // Score 25 → pipeHero
        let result25 = progress.check(event: .gameEnded(score: 25), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result25.contains(.pipeHero))

        // Score 50 → skyMaster
        let result50 = progress.check(event: .gameEnded(score: 50), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result50.contains(.skyMaster))

        // Score 100 → legendary
        let result100 = progress.check(event: .gameEnded(score: 100), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result100.contains(.legendary))
    }

    // MARK: - Already Unlocked Not Returned Again

    func testAlreadyUnlockedNotReturnedAgain() {
        var progress = AchievementProgress()
        let stats = PlayerStats(gamesPlayed: 1)

        // First time scoring 1 → unlocks firstFlight
        let first = progress.check(event: .gameEnded(score: 1), stats: stats, skinsOwned: 1)
        XCTAssertTrue(first.contains(.firstFlight))

        // Second time scoring 1 → firstFlight should NOT appear again
        let second = progress.check(event: .gameEnded(score: 1), stats: stats, skinsOwned: 1)
        XCTAssertFalse(second.contains(.firstFlight),
            "Already-unlocked achievements should not be returned again")
    }

    // MARK: - Cumulative Achievements

    func testBreadCollectionAchievements() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        // Collect 99 bread → no unlock
        let result99 = progress.check(event: .breadCollected(total: 99), stats: stats, skinsOwned: 1)
        XCTAssertFalse(result99.contains(.breadWinner))

        // Collect 100 bread → breadWinner
        let result100 = progress.check(event: .breadCollected(total: 100), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result100.contains(.breadWinner))

        // Collect 1000 bread → breadBaron
        let result1000 = progress.check(event: .breadCollected(total: 1000), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result1000.contains(.breadBaron))
    }

    func testGamesPlayedAchievements() {
        var progress = AchievementProgress()

        // 50 games → marathon
        let stats50 = PlayerStats(gamesPlayed: 50)
        let result50 = progress.check(event: .gameEnded(score: 0), stats: stats50, skinsOwned: 1)
        XCTAssertTrue(result50.contains(.marathon))

        // 100 games → dedicated
        let stats100 = PlayerStats(gamesPlayed: 100)
        let result100 = progress.check(event: .gameEnded(score: 0), stats: stats100, skinsOwned: 1)
        XCTAssertTrue(result100.contains(.dedicated))

        // 500 games → veteran
        let stats500 = PlayerStats(gamesPlayed: 500)
        let result500 = progress.check(event: .gameEnded(score: 0), stats: stats500, skinsOwned: 1)
        XCTAssertTrue(result500.contains(.veteran))
    }

    // MARK: - Bot Ladder Achievements

    func testBotLadderAchievements() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        let result1 = progress.check(event: .botBeaten(totalBeaten: 1), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result1.contains(.botSlayer))

        let result4 = progress.check(event: .botBeaten(totalBeaten: 4), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result4.contains(.ladderClimber))

        let result8 = progress.check(event: .botBeaten(totalBeaten: 8), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result8.contains(.topDuck))
    }

    // MARK: - Power-Up Achievements

    func testShieldBreakerAchievement() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        // Use 9 shields — not enough
        for _ in 1...9 {
            let result = progress.check(event: .shieldUsed, stats: stats, skinsOwned: 1)
            XCTAssertFalse(result.contains(.shieldBreaker))
        }

        // 10th shield → shieldBreaker
        let result = progress.check(event: .shieldUsed, stats: stats, skinsOwned: 1)
        XCTAssertTrue(result.contains(.shieldBreaker))
    }

    func testGhostRiderAchievement() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        // Phase through 4 pipes — not enough
        for _ in 1...4 {
            let result = progress.check(event: .ghostPipePhased, stats: stats, skinsOwned: 1)
            XCTAssertFalse(result.contains(.ghostRider))
        }

        // 5th pipe → ghostRider
        let result = progress.check(event: .ghostPipePhased, stats: stats, skinsOwned: 1)
        XCTAssertTrue(result.contains(.ghostRider))
    }

    func testMagnetMogulAchievement() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        // Collect 40 bread with magnet — not enough
        let result40 = progress.check(event: .magnetBreadCollected(count: 40), stats: stats, skinsOwned: 1)
        XCTAssertFalse(result40.contains(.magnetMogul))

        // Collect 10 more → total 50 → magnetMogul
        let result50 = progress.check(event: .magnetBreadCollected(count: 10), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result50.contains(.magnetMogul))
    }

    // MARK: - Streak Achievements

    func testStreakAchievements() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        let result3 = progress.check(event: .streakUpdated(days: 3), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result3.contains(.streakStarter))

        let result7 = progress.check(event: .streakUpdated(days: 7), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result7.contains(.committed))

        let result30 = progress.check(event: .streakUpdated(days: 30), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result30.contains(.obsessed))
    }

    // MARK: - Special Achievements

    func testSurvivalistAchievement() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        // Score 4 extra after debuff — not enough
        let result4 = progress.check(event: .debuffSurvivedWithScore(extraPoints: 4), stats: stats, skinsOwned: 1)
        XCTAssertFalse(result4.contains(.survivalist))

        // Score 5 extra → survivalist
        let result5 = progress.check(event: .debuffSurvivedWithScore(extraPoints: 5), stats: stats, skinsOwned: 1)
        XCTAssertTrue(result5.contains(.survivalist))
    }

    func testSkinCollectionAchievements() {
        var progress = AchievementProgress()
        let stats = PlayerStats()

        // Own 4 skins — not enough for collector
        let result4 = progress.check(event: .skinPurchased(totalOwned: 4), stats: stats, skinsOwned: 4)
        XCTAssertFalse(result4.contains(.collector))

        // Own 5 skins → collector
        let result5 = progress.check(event: .skinPurchased(totalOwned: 5), stats: stats, skinsOwned: 5)
        XCTAssertTrue(result5.contains(.collector))
    }

    // MARK: - Secret Achievements

    func testSecretAchievementFlags() {
        let secretAchievements: Set<AchievementId> = [.legendary, .topDuck, .obsessed, .fashionista]

        for achievement in AchievementId.allCases {
            if secretAchievements.contains(achievement) {
                XCTAssertTrue(achievement.isSecret,
                    "\(achievement.rawValue) should be marked as secret")
            } else {
                XCTAssertFalse(achievement.isSecret,
                    "\(achievement.rawValue) should NOT be marked as secret")
            }
        }
    }

    // MARK: - Bread Rewards

    func testBreadRewardsArePositive() {
        for achievement in AchievementId.allCases {
            XCTAssertGreaterThan(achievement.breadReward, 0,
                "\(achievement.rawValue) should have a positive bread reward")
        }
    }

    func testBreadRewardsScale() {
        // Easy achievements should have lower rewards than hard ones
        XCTAssertLessThan(AchievementId.firstFlight.breadReward,
                          AchievementId.legendary.breadReward)
        XCTAssertLessThan(AchievementId.breadWinner.breadReward,
                          AchievementId.breadBaron.breadReward)
        XCTAssertLessThan(AchievementId.botSlayer.breadReward,
                          AchievementId.topDuck.breadReward)
    }

    // MARK: - Display Properties

    func testAllAchievementsHaveDisplayProperties() {
        for achievement in AchievementId.allCases {
            XCTAssertFalse(achievement.title.isEmpty,
                "\(achievement.rawValue) should have a title")
            XCTAssertFalse(achievement.description.isEmpty,
                "\(achievement.rawValue) should have a description")
            // Verify pixelIcon is accessible (would crash if missing)
            _ = achievement.pixelIcon
        }
    }

    // MARK: - Total Bread From Achievements

    func testTotalBreadFromAchievements() {
        var progress = AchievementProgress()
        XCTAssertEqual(progress.totalBreadFromAchievements, 0)

        // Manually unlock firstFlight (reward: 10) and gettingStarted (reward: 25)
        progress.unlocked.insert(.firstFlight)
        progress.unlocked.insert(.gettingStarted)
        XCTAssertEqual(progress.totalBreadFromAchievements, 35)
    }

    func testProgressPersistsWhenCounterChangesWithoutUnlock() {
        let defaults = makeIsolatedDefaults()
        let manager = AchievementManager(userDefaults: defaults, storageKey: "achievementProgress")

        _ = manager.process(event: .shieldUsed, stats: PlayerStats(), skinsOwned: 1)

        let reloaded = AchievementManager(userDefaults: defaults, storageKey: "achievementProgress")
        XCTAssertEqual(reloaded.progress.shieldsUsed, 1)
        XCTAssertFalse(reloaded.progress.unlocked.contains(.shieldBreaker))
    }

    func testSkinAchievementRewardPersistsWithoutGameManager() throws {
        let defaults = makeIsolatedDefaults()
        let initialStats = PlayerStats(bread: 10)
        let initialData = try XCTUnwrap(try? JSONEncoder().encode(initialStats))
        defaults.set(initialData, forKey: "playerStats")

        let manager = AchievementManager(userDefaults: defaults, storageKey: "achievementProgress")
        let unlocked = manager.process(event: .skinPurchased(totalOwned: 5), stats: PlayerStats(), skinsOwned: 5)

        XCTAssertEqual(unlocked, [.collector])

        let storedData = try XCTUnwrap(defaults.data(forKey: "playerStats"))
        let storedStats = try JSONDecoder().decode(PlayerStats.self, from: storedData)
        XCTAssertEqual(storedStats.bread, 10 + AchievementId.collector.breadReward)
    }
}

private func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "AchievementTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
