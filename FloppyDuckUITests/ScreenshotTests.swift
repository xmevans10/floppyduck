import XCTest

/// Automated screenshot flow — launches the app, navigates through key screens,
/// and captures screenshots at each step.
///
/// The app skips splash + onboarding when `-UITestMode` is set, so CI lands
/// directly on the home screen.  Screenshots are saved as XCTAttachments inside
/// the xcresult bundle and extracted by the CI workflow.
///
/// Every navigation step is wrapped in `tryScreen` — if a screen can't be
/// reached within its timeout the test logs a warning, captures a diagnostic
/// screenshot, and moves on to the next screen.  This ensures CI always
/// produces *some* output even when individual screens break.
///
/// Run locally:
///   xcodebuild test -scheme FloppyDuck \
///     -only-testing:FloppyDuckUITests/ScreenshotTests \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
///     -resultBundlePath TestResults
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!
    /// Tracks how many screens were captured vs attempted for the summary.
    private var captured = 0
    private var attempted = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "true"]
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
    }

    override func tearDownWithError() throws {
        print("📸 Screenshot summary: \(captured)/\(attempted) screens captured")
        app = nil
    }

    // MARK: - Full Flow Screenshots

    func testCaptureFullAppFlow() throws {
        // ── Home (required gate — if this fails, nothing else will work) ──
        let shopButton = app.buttons["SHOP"]
        guard shopButton.waitForExistence(timeout: 15) else {
            // Capture whatever is on screen for diagnosis
            capture("FAIL_no_home_screen")
            XCTFail("Home screen did not appear within 15 s — aborting")
            return
        }
        capture("01_home")

        // ── Shop ────────────────────────────────────────────────────
        tryScreen("02_shop") {
            guard shopButton.exists else { return }
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
        tryScreen("04_collection") {
            let btn = app.buttons["COLLECTION"]
            guard btn.waitForExistence(timeout: 5) else { return }
            btn.tap()
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

        // ── Stats + Leaderboard ─────────────────────────────────────
        tryScreen("06_stats") {
            let btn = app.buttons["STATS"]
            guard btn.waitForExistence(timeout: 5) else { return }
            btn.tap()
            waitForAnimation()
            capture("06_stats")

            let lb = app.buttons["LEADERBOARD"]
            if lb.waitForExistence(timeout: 3) {
                lb.tap()
                waitForAnimation(duration: 1.0)
                capture("07_leaderboard")
                goBackToPreviousScreen()
            }
            goBackToPreviousScreen()
        }

        // ── Settings ────────────────────────────────────────────────
        tryScreen("08_settings") {
            let btn = app.buttons["SETTINGS"]
            guard btn.waitForExistence(timeout: 5) else { return }
            btn.tap()
            waitForAnimation()
            capture("08_settings")
            goBackToPreviousScreen()
        }

        // ── Gameplay ────────────────────────────────────────────────
        tryScreen("09_gameplay") {
            let btn = app.buttons["Classic, Solo Run"]
            guard btn.waitForExistence(timeout: 5) else { return }
            btn.tap()
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

    /// Wraps a screen-capture block so that any failure (timeout, unexpected UI
    /// state, crash) is caught gracefully.  On failure it logs a warning and
    /// captures a diagnostic screenshot, then continues to the next screen.
    private func tryScreen(_ label: String, timeout: TimeInterval = 20, _ body: () -> Void) {
        attempted += 1
        let before = captured

        // Run the block — `continueAfterFailure` keeps us going on XCTAssert
        body()

        if captured > before {
            // At least one screenshot was captured inside the block.
            return
        }

        // Nothing was captured — grab a diagnostic shot so we can debug later.
        print("⚠️ Screen '\(label)' produced no screenshots — capturing diagnostic")
        capture("SKIP_\(label)")
    }

    private func capture(_ name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        captured += 1
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
