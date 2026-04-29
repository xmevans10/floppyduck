import XCTest

/// Automated screenshot flow — launches the app, navigates through key screens,
/// and captures screenshots at each step.
///
/// The app skips splash + onboarding when `-UITestMode` is set, so CI lands
/// directly on the home screen.  Screenshots are saved as XCTAttachments inside
/// the xcresult bundle and extracted by the CI workflow.
///
/// Run locally:
///   xcodebuild test -scheme FloppyDuck \
///     -only-testing:FloppyDuckUITests/ScreenshotTests \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
///     -resultBundlePath TestResults
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "true"]
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Full Flow Screenshots

    func testCaptureFullAppFlow() throws {
        // UITestMode skips splash + onboarding → lands on home screen.
        let shopButton = app.buttons["SHOP"]
        XCTAssertTrue(shopButton.waitForExistence(timeout: 15),
                       "Home screen did not appear in time")
        capture("01_home")

        // ── Shop ────────────────────────────────────────────────────
        if shopButton.exists {
            shopButton.tap()
            waitForAnimation()
            capture("02_shop_ducks")

            let bgTab = app.buttons["BACKGROUNDS"]
            if bgTab.waitForExistence(timeout: 3) {
                bgTab.tap()
                waitForAnimation()
                capture("03_shop_backgrounds")
            }
            goBackToPreviousScreen()
        }

        // ── Collection ──────────────────────────────────────────────
        let collectionButton = app.buttons["COLLECTION"]
        if collectionButton.waitForExistence(timeout: 3) {
            collectionButton.tap()
            waitForAnimation()
            capture("04_collection_skins")

            let bgTab = app.buttons["BACKGROUNDS"]
            if bgTab.waitForExistence(timeout: 3) {
                bgTab.tap()
                waitForAnimation()
                capture("05_collection_backgrounds")
            }
            goBackToPreviousScreen()
        }

        // ── Stats ───────────────────────────────────────────────────
        let statsButton = app.buttons["STATS"]
        if statsButton.waitForExistence(timeout: 3) {
            statsButton.tap()
            waitForAnimation()
            capture("06_stats")

            let leaderboardButton = app.buttons["LEADERBOARD"]
            if leaderboardButton.waitForExistence(timeout: 3) {
                leaderboardButton.tap()
                waitForAnimation(duration: 1.0)
                capture("07_leaderboard")
                goBackToPreviousScreen()
            }
            goBackToPreviousScreen()
        }

        // ── Settings ────────────────────────────────────────────────
        let settingsButton = app.buttons["SETTINGS"]
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            waitForAnimation()
            capture("08_settings")
            goBackToPreviousScreen()
        }

        // ── Gameplay ────────────────────────────────────────────────
        let classicButton = app.buttons["Classic, Solo Run"]
        if classicButton.waitForExistence(timeout: 3) {
            classicButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
            capture("09_gameplay_ready")

            app.tap()
            waitForAnimation()
            capture("10_gameplay_playing")

            // Wait for death (duck falls)
            Thread.sleep(forTimeInterval: 4.0)
            capture("11_game_over")
        }
    }

    // MARK: - Helpers

    private func capture(_ name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForAnimation(duration: TimeInterval = 0.4) {
        Thread.sleep(forTimeInterval: duration)
    }

    private func goBackToPreviousScreen() {
        let backButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'back' OR label CONTAINS[c] 'home'")
        ).firstMatch
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            waitForAnimation(duration: 0.3)
        }
    }
}
