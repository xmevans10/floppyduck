import XCTest

/// Automated screenshot flow — launches the app, navigates through key screens,
/// and captures screenshots at each step. Screenshots are saved as XCTAttachments
/// inside the xcresult bundle and extracted by CI.
///
/// **Dynamic filtering:**  CI sets `SCREENSHOT_SCREENS` (comma-separated list of
/// screen group names, e.g. `"home,shop,gameplay"`) to capture only the screens
/// affected by the current changeset.  When the variable is empty or unset, *all*
/// screens are captured (full run).
///
/// Run locally:
///   xcodebuild test -scheme FloppyDuck \
///     -only-testing:FloppyDuckUITests/ScreenshotTests \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
///     -resultBundlePath TestResults
///
/// Run with selective screens:
///   SCREENSHOT_SCREENS=home,shop xcodebuild test ...
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    /// Screen groups to capture. Empty = capture all.
    private var activeScreens: Set<String> = []

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "true"]
        app.launchEnvironment["UITEST_MODE"] = "1"

        // Read CI-provided screen filter
        if let raw = ProcessInfo.processInfo.environment["SCREENSHOT_SCREENS"],
           !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            activeScreens = Set(
                raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            )
            print("📸 Selective mode — capturing: \(activeScreens.sorted().joined(separator: ", "))")
        } else {
            print("📸 Full mode — capturing all screens")
        }

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Returns `true` when the given screen group should be captured.
    private func shouldCapture(_ screen: String) -> Bool {
        activeScreens.isEmpty || activeScreens.contains(screen)
    }

    // MARK: - Full Flow Screenshots

    func testCaptureFullAppFlow() throws {
        // ── 1. Splash ────────────────────────────────────────────────
        if shouldCapture("splash") {
            Thread.sleep(forTimeInterval: 0.5)
            capture("01_splash")
        }

        // ── 2. Auth onboarding (only on clean simulator) ─────────────
        let guestButton = app.buttons["CONTINUE AS GUEST"]
        if guestButton.waitForExistence(timeout: 5) {
            if shouldCapture("auth") {
                capture("02_auth_onboarding")
            }
            tapCentered(guestButton)
            waitForAnimation(duration: 0.8)
        }

        // ── 3. Home ──────────────────────────────────────────────────
        let shopButton = app.buttons["SHOP"]
        XCTAssertTrue(shopButton.waitForExistence(timeout: 10), "Home screen did not appear in time")
        if shouldCapture("home") {
            capture("03_home")
        }

        // ── 4. Shop ─────────────────────────────────────────────────
        if shouldCapture("shop") {
            if shopButton.exists {
                shopButton.tap()
                waitForAnimation()
                capture("04_shop_ducks")

                let bgTab = app.buttons["BACKGROUNDS"]
                if bgTab.waitForExistence(timeout: 2) {
                    bgTab.tap()
                    waitForAnimation()
                    capture("05_shop_backgrounds")
                }
                goBackToPreviousScreen()
            }
        }

        // ── 5. Collection ───────────────────────────────────────────
        if shouldCapture("collection") {
            let collectionButton = app.buttons["COLLECTION"]
            if collectionButton.waitForExistence(timeout: 2) {
                collectionButton.tap()
                waitForAnimation()
                capture("06_collection_skins")

                let bgTab = app.buttons["BACKGROUNDS"]
                if bgTab.waitForExistence(timeout: 2) {
                    bgTab.tap()
                    waitForAnimation()
                    capture("07_collection_backgrounds")
                }
                goBackToPreviousScreen()
            }
        }

        // ── 6. Stats ────────────────────────────────────────────────
        if shouldCapture("stats") {
            let statsButton = app.buttons["STATS"]
            if statsButton.waitForExistence(timeout: 2) {
                statsButton.tap()
                waitForAnimation()
                capture("08_stats")
                goBackToPreviousScreen()
            }
        }

        // ── 7. Leaderboard (navigated from Stats) ───────────────────
        if shouldCapture("leaderboard") {
            let statsButton = app.buttons["STATS"]
            if statsButton.waitForExistence(timeout: 2) {
                statsButton.tap()
                waitForAnimation()

                let leaderboardButton = app.buttons["LEADERBOARD"]
                if leaderboardButton.waitForExistence(timeout: 2) {
                    leaderboardButton.tap()
                    waitForAnimation(duration: 1.0)
                    capture("09_leaderboard")
                    goBackToPreviousScreen()
                }
                goBackToPreviousScreen()
            }
        }

        // ── 8. Settings ─────────────────────────────────────────────
        if shouldCapture("settings") {
            let settingsButton = app.buttons["SETTINGS"]
            if settingsButton.waitForExistence(timeout: 2) {
                settingsButton.tap()
                waitForAnimation()
                capture("10_settings")
                goBackToPreviousScreen()
            }
        }

        // ── 9. Gameplay ─────────────────────────────────────────────
        if shouldCapture("gameplay") {
            let classicButton = app.buttons["Classic, Solo Run"]
            if classicButton.waitForExistence(timeout: 2) {
                classicButton.tap()
                Thread.sleep(forTimeInterval: 1.0)
                capture("11_gameplay_ready")

                app.tap()
                waitForAnimation()
                capture("12_gameplay_playing")

                Thread.sleep(forTimeInterval: 4.0)
                capture("13_game_over")
            }
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
        let backButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'back' OR label CONTAINS[c] 'home'")
        ).firstMatch
        if backButton.waitForExistence(timeout: 2) {
            backButton.tap()
            waitForAnimation(duration: 0.3)
        }
    }
}
