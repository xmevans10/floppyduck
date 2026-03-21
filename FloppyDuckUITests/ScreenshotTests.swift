import XCTest

/// Automated screenshot flow — launches the app, navigates through key screens,
/// and captures screenshots at each step. Screenshots are saved to
/// `SCREENSHOT_DIR` (set by CI) or a temp directory.
///
/// Run with:
///   xcodebuild test -scheme FloppyDuck -target FloppyDuckUITests \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
///     -resultBundlePath TestResults
///
/// Screenshots end up in the xcresult bundle and are extracted by CI.
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
        // 1. Splash screen — capture immediately on launch
        //    The splash is ~1.9s, so just wait briefly and capture
        Thread.sleep(forTimeInterval: 0.5)
        capture("01_splash")

        // 2. On a clean simulator we may land in auth onboarding before Home.
        let guestButton = app.buttons["CONTINUE AS GUEST"]
        if guestButton.waitForExistence(timeout: 5) {
            capture("02_auth_onboarding")
            tapCentered(guestButton)
            waitForAnimation(duration: 0.8)
        }

        // 3. Wait for splash / onboarding to finish → home screen.
        //    Button labels are ALL-CAPS in the UI (e.g. "SHOP"), so match exactly.
        let shopButton = app.buttons["SHOP"]
        XCTAssertTrue(shopButton.waitForExistence(timeout: 10), "Home screen did not appear in time")
        capture("03_home")

        // 4. Shop — tap shop button
        if shopButton.exists {
            shopButton.tap()
            waitForAnimation()
            capture("04_shop_ducks")

            // Tap BACKGROUNDS tab if visible
            let bgTab = app.buttons["BACKGROUNDS"]
            if bgTab.waitForExistence(timeout: 2) {
                bgTab.tap()
                waitForAnimation()
                capture("05_shop_backgrounds")
            }

            goBackToPreviousScreen()
        }

        // 5. Collection (skins + backgrounds closet)
        let collectionButton = app.buttons["COLLECTION"]
        if collectionButton.waitForExistence(timeout: 2) {
            collectionButton.tap()
            waitForAnimation()
            capture("06_collection_skins")

            // Tap BACKGROUNDS tab
            let bgTab = app.buttons["BACKGROUNDS"]
            if bgTab.waitForExistence(timeout: 2) {
                bgTab.tap()
                waitForAnimation()
                capture("07_collection_backgrounds")
            }

            goBackToPreviousScreen()
        }

        // 6. Stats
        let statsButton = app.buttons["STATS"]
        if statsButton.waitForExistence(timeout: 2) {
            statsButton.tap()
            waitForAnimation()
            capture("08_stats")

            let leaderboardButton = app.buttons["LEADERBOARD"]
            if leaderboardButton.waitForExistence(timeout: 2) {
                leaderboardButton.tap()
                waitForAnimation(duration: 1.0)
                capture("09_leaderboard")
                goBackToPreviousScreen()
            }

            goBackToPreviousScreen()
        }

        // 7. Settings
        let settingsButton = app.buttons["SETTINGS"]
        if settingsButton.waitForExistence(timeout: 2) {
            settingsButton.tap()
            waitForAnimation()
            capture("10_settings")

            goBackToPreviousScreen()
        }

        // 8. Start Classic game → gameplay.
        //    The play-mode button label is "Classic, Solo Run" (from accessibilityLabel).
        let classicButton = app.buttons["Classic, Solo Run"]
        if classicButton.waitForExistence(timeout: 2) {
            classicButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
            capture("11_gameplay_ready")

            // Tap to start playing
            app.tap()
            waitForAnimation()
            capture("12_gameplay_playing")

            // Wait for death (don't tap, duck will fall into ground)
            Thread.sleep(forTimeInterval: 4.0)
            capture("13_game_over")
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

    private func tapCentered(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func goBackToPreviousScreen() {
        let backButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'back' OR label CONTAINS[c] 'home'")).firstMatch
        if backButton.waitForExistence(timeout: 2) {
            backButton.tap()
            waitForAnimation(duration: 0.3)
        }
    }
}
