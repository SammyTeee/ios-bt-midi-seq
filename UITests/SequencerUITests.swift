import XCTest

final class SequencerUITests: XCTestCase {
    func testStepRecordRestsRotationAndPersistence() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["step-record"].waitForExistence(timeout: 15))
        app.buttons["step-record"].tap()
        XCTAssertEqual(app.buttons["step-record"].value as? String, "On")
        app.buttons["record-key-60"].tap()
        app.buttons["record-key-64"].tap()
        app.buttons["record-key-67"].tap()
        app.buttons["record-rest"].tap()
        XCTAssertTrue(app.staticTexts["entry-cursor"].label.hasPrefix("5 ·"))
        capture("Portrait step recording")

        XCUIDevice.shared.orientation = .landscapeLeft
        let wide = NSPredicate { _, _ in app.frame.width > app.frame.height }
        expectation(for: wide, evaluatedWith: nil)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["launch-H"].isHittable)
        XCTAssertTrue(app.buttons["record-rest"].isHittable)
        XCTAssertTrue(app.buttons["record-key-60"].isHittable)
        app.buttons["record-key-60"].tap()
        XCTAssertTrue(app.staticTexts["entry-cursor"].label.hasPrefix("6 ·"))
        capture("Landscape piano roll")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["entry-cursor"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["entry-cursor"].label, "1 · C4")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
