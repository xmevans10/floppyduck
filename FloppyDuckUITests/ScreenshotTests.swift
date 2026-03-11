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

        // 2. Wait for splash to finish → home screen
        let shopButton = app.buttons["Shop"]
        let homeAppeared = shopButton.waitForExistence(timeout: 5)
        if homeAppeared {
            capture("02_home")
        }

        // 3. Shop — tap shop button
        if shopButton.exists {
            shopButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            capture("03_shop_ducks")

            // Tap BACKGROUNDS tab if visible
            let bgTab = app.buttons["BACKGROUNDS"]
            if bgTab.waitForExistence(timeout: 2) {
                bgTab.tap()
                Thread.sleep(forTimeInterval: 0.3)
                capture("04_shop_backgrounds")
            }

            // Go back
            let backButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'back' OR label CONTAINS 'Back' OR label CONTAINS 'Home'")).firstMatch
            if backButton.exists { backButton.tap() }
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 4. Closet
        let closetButton = app.buttons["Closet"]
        if closetButton.waitForExistence(timeout: 2) {
            closetButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            capture("05_closet_skins")

            // Tap BACKGROUNDS tab
            let bgTab = app.buttons["BACKGROUNDS"]
            if bgTab.waitForExistence(timeout: 2) {
                bgTab.tap()
                Thread.sleep(forTimeInterval: 0.3)
                capture("06_closet_backgrounds")
            }

            let backButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'back' OR label CONTAINS 'Back' OR label CONTAINS 'Home'")).firstMatch
            if backButton.exists { backButton.tap() }
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 5. Stats
        let statsButton = app.buttons["Stats"]
        if statsButton.waitForExistence(timeout: 2) {
            statsButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            capture("07_stats")

            let backButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'back' OR label CONTAINS 'Back' OR label CONTAINS 'Home'")).firstMatch
            if backButton.exists { backButton.tap() }
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 6. Settings
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 2) {
            settingsButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            capture("08_settings")

            let backButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'back' OR label CONTAINS 'Back' OR label CONTAINS 'Home'")).firstMatch
            if backButton.exists { backButton.tap() }
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 7. Start Classic game → gameplay
        let classicButton = app.buttons["Classic"]
        if classicButton.waitForExistence(timeout: 2) {
            classicButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
            capture("09_gameplay_ready")

            // Tap to start playing
            app.tap()
            Thread.sleep(forTimeInterval: 0.5)
            capture("10_gameplay_playing")

            // Wait for death (don't tap, duck will fall into ground)
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
}
