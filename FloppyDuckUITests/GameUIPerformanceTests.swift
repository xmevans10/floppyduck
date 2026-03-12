import XCTest

final class GameUIPerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGameplayMetrics() throws {
        let app = XCUIApplication()
        
        // Measure CPU, Memory, and Clock time over 5 iterations
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric(), XCTClockMetric()], options: options) {
            app.launch()
            
            // Wait for Splash screen to finish (~5 seconds) and tap "CLASSIC"
            let classicButton = app.buttons["CLASSIC"]
            XCTAssertTrue(classicButton.waitForExistence(timeout: 8.0), "Classic button should appear after splash screen")
            classicButton.tap()
            
            // Wait a moment for the 'GET READY' countdown to clear (~3 seconds)
            Thread.sleep(forTimeInterval: 3.5)
            
            // Simulate 5 flaps with a 0.5s pause to engage the physics and generation loops
            for _ in 0..<5 {
                app.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Terminate the app so the next measure block iteration has a clean slate
            app.terminate()
        }
    }
}
