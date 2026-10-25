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
    /// `manual` turns the robot driver off, so the test drives with real touches (easy controls, the default).
    private func launch(frozen: Bool = false, manual: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-EchoUITest", "-EchoReset"] + (frozen ? ["-EchoFastForward", "0"] : [])
            + (manual ? ["-EchoManual", "-EchoFastForward", "2"] : [])
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
        // Three intro cards: why you race, the twist, how to use it.
        let next = app.buttons["introNext"]
        waitFor(next)
        XCTAssertTrue(app.staticTexts["ECHO LAP"].exists)
        XCTAssertTrue(app.staticTexts["Beat the gold car"].exists)
        XCTAssertTrue(app.links["Privacy"].exists || app.buttons["Privacy"].exists, "privacy link on the first screen")
        XCTAssertTrue(app.buttons["introSkip"].exists)
        snapshot("01-intro")
        next.tap()
        waitFor(app.staticTexts["Every lap stays on the track"])
        app.buttons["introNext"].tap()
        waitFor(app.staticTexts["Use your echoes"])
        let start = app.buttons["startRacing"]
        waitFor(start)
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
        let skip = app.buttons["introSkip"]
        waitFor(skip)
        skip.tap()

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
        waitFor(app.buttons["introSkip"])
        app.buttons["introSkip"].tap()
        let boost = app.buttons["boost"]
        waitFor(boost, 30)
        XCTAssertGreaterThanOrEqual(boost.frame.width, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["pause"].frame.width, 44)
        XCTAssertFalse((boost.value as? String ?? "").isEmpty)
    }

    /// The first race teaches easy controls by doing: each lesson waits until the player has done it.
    func testTutorialTeachesEasyControlsByDoing() {
        launch(manual: true)
        let skip = app.buttons["introSkip"]
        waitFor(skip)
        skip.tap()

        let card = app.descendants(matching: .any)["tutorialCard"]
        waitFor(card, 30)
        XCTAssertTrue(card.label.contains("RIGHT"), "first lesson: hold the right side (\(card.label))")
        snapshot("11-tutorial-right")
        let screen = app.windows.firstMatch
        screen.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.55)).press(forDuration: 4)
        XCTAssertTrue(waitForLabel(card, containing: "LEFT", seconds: 10), "second lesson: hold the left side (\(card.label))")
        snapshot("12-tutorial-left")
        screen.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.55)).press(forDuration: 4)
        XCTAssertTrue(waitForDisappearance(card, seconds: 10), "the steering lessons finish once both sides were held")

        // On lap 2 the boost lesson stops the race until the player boosts.
        XCTAssertTrue(waitForLabel(card, containing: "swipe up", seconds: 120), "boost lesson appears on lap 2")
        snapshot("13-tutorial-boost")
        app.buttons["boost"].tap()
        XCTAssertTrue(waitForDisappearance(card, seconds: 10), "boosting finishes the lesson")
        waitFor(app.buttons["resultsPrimary"], 180)
        snapshot("14-tutorial-results")
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if element.exists && element.label.localizedCaseInsensitiveContains(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func waitForDisappearance(_ element: XCUIElement, seconds: TimeInterval) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: element)], timeout: seconds) == .completed
    }
}
