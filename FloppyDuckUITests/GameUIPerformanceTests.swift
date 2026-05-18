import XCTest

final class GameUIPerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 20–30 second classic gameplay loop with repeated taps.
    /// Collects CPU, memory, and clock metrics over 3 iterations.
    func testClassicGameplayLoop() throws {
        let app = XCUIApplication()

        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric(), XCTClockMetric()], options: options) {
            app.launch()

            // Wait for splash and tap CLASSIC
            let classicButton = app.buttons["CLASSIC, Solo Run"]
            XCTAssertTrue(classicButton.waitForExistence(timeout: 8.0), "Classic button should appear after splash screen")
            classicButton.tap()

            // Wait for countdown to finish (~3 seconds)
            Thread.sleep(forTimeInterval: 3.5)

            // Simulate rapid-flap gameplay for ~20 seconds
            let startTime = Date()
            while Date().timeIntervalSince(startTime) < 20.0 {
                app.tap()
                Thread.sleep(forTimeInterval: 0.25) // ~240 BPM tapping
            }

            app.terminate()
        }
    }
}
