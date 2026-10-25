import XCTest

/// End-to-end checks on a fresh install. `-EchoUITest` makes a robot drive at 6× speed, so races finish quickly
/// and the same way every run; `-EchoReset` wipes saved progress first.
final class EchoLapUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    /// `frozen` stops the race clock (it stays on the countdown), so menus can be tested without the race ending
    /// underneath them and without the app animating between every query.
    private func launch(frozen: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-EchoUITest", "-EchoReset"] + (frozen ? ["-EchoFastForward", "0"] : [])
        app.launch()
    }

    /// Taps the HUD pause button until the pause menu shows (the first tap can land while the scene is settling).
    private func openPauseMenu(file: StaticString = #filePath, line: UInt = #line) {
        let pause = app.buttons["pause"]
        waitFor(pause, 30, file: file, line: line)
        for _ in 0..<3 {
            pause.tap()
            if app.buttons["resume"].waitForExistence(timeout: 5) { return }
        }
        XCTFail("The pause menu did not open", file: file, line: line)
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitFor(_ element: XCUIElement, _ seconds: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: seconds), "\(element) did not appear", file: file, line: line)
    }

    /// Intro → first race → results → home, then every menu screen opens and closes.
    func testFirstLaunchJourney() {
        launch()
        let start = app.buttons["startRacing"]
        waitFor(start)
        XCTAssertTrue(app.staticTexts["ECHO LAP"].exists)
        XCTAssertTrue(app.links["Privacy"].exists || app.buttons["Privacy"].exists, "privacy link on the first screen")
        snapshot("01-intro")
        start.tap()

        waitFor(app.buttons["pause"], 30)
        snapshot("02-race")
        let continueButton = app.buttons["resultsPrimary"]
        waitFor(continueButton, 150)
        snapshot("03-results")
        XCTAssertTrue(app.staticTexts["Nice driving!"].exists)
        continueButton.tap()

        let race = app.buttons["continueRace"]
        waitFor(race)
        snapshot("04-home")

        app.buttons["dailyCard"].tap()
        waitFor(app.buttons["raceDaily"])
        snapshot("05-daily")
        app.buttons["closeSheet"].tap()

        app.buttons["garage"].tap()
        waitFor(app.descendants(matching: .any)["car-pip"])
        snapshot("06-garage")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["trophies"].tap()
        waitFor(app.navigationBars["Trophies"])
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["settings"].tap()
        waitFor(app.navigationBars["Settings"])
        snapshot("07-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let world = app.descendants(matching: .any)["world1"]
        if !world.isHittable { app.swipeUp() }
        world.tap()
        let track = app.descendants(matching: .any)["track1-2"]
        waitFor(track)
        snapshot("08-world")
        track.tap()
        waitFor(app.buttons["raceTrack"])
        snapshot("09-track")
        app.buttons["closeDetail"].tap()
    }

    /// Pause, resume, restart and quit all work during a race, and the quit asks first.
    func testPauseMenu() {
        launch(frozen: true)
        let start = app.buttons["startRacing"]
        waitFor(start)
        start.tap()

        openPauseMenu()
        snapshot("10-paused")
        XCTAssertTrue(app.buttons["restart"].exists)
        XCTAssertTrue(app.buttons["quit"].exists)
        app.buttons["resume"].tap()
        XCTAssertFalse(app.buttons["resume"].waitForExistence(timeout: 2))

        openPauseMenu()
        app.buttons["restart"].tap()
        XCTAssertFalse(app.buttons["resume"].waitForExistence(timeout: 2), "restart starts a fresh race")

        openPauseMenu()
        app.buttons["quit"].tap()
        let confirm = app.buttons["Quit to menu"]
        waitFor(confirm)
        confirm.tap()
        waitFor(app.buttons["continueRace"])
    }

    /// The boost button is a real control with a value VoiceOver can read.
    func testRaceControlsAreAccessible() {
        launch(frozen: true)
        waitFor(app.buttons["startRacing"])
        app.buttons["startRacing"].tap()
        let boost = app.buttons["boost"]
        waitFor(boost, 30)
        XCTAssertGreaterThanOrEqual(boost.frame.width, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["pause"].frame.width, 44)
        XCTAssertFalse((boost.value as? String ?? "").isEmpty)
    }
}
