import XCTest

/// End-to-end checks on a fresh install. `-EchoUITest` makes a robot drive at 6× speed, so sprints finish quickly
/// and the same way every run; `-EchoReset` wipes saved progress first.
final class EchoLapUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    /// `frozen` stops the race clock (it stays on the countdown), so menus can be tested without the race ending
    /// underneath them and without the app animating between every query.
    /// `manual` turns the robot driver off, so the test drives with real touches.
    private func launch(frozen: Bool = false, manual: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-EchoUITest", "-EchoReset"] + (frozen ? ["-EchoFastForward", "0"] : [])
            + (manual ? ["-EchoManual", "-EchoFastForward", "1"] : [])
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

    /// Intro → first sprint → results → GO AGAIN → results → home, then every menu screen opens and closes.
    func testFirstLaunchJourney() {
        launch()
        // Three intro cards: the controls, the rival, the echoes.
        let next = app.buttons["introNext"]
        waitFor(next)
        XCTAssertTrue(app.staticTexts["ECHO LAP"].exists)
        XCTAssertTrue(app.staticTexts["Hold the turn. Drift. Let go."].exists)
        XCTAssertTrue(app.links["Privacy"].exists || app.buttons["Privacy"].exists, "privacy link on the first screen")
        XCTAssertTrue(app.buttons["introSkip"].exists)
        snapshot("01-intro")
        next.tap()
        waitFor(app.staticTexts["Beat the rival"])
        app.buttons["introNext"].tap()
        waitFor(app.staticTexts["Your runs come back"])
        let start = app.buttons["startRacing"]
        waitFor(start)
        start.tap()

        waitFor(app.buttons["pause"], 30)
        waitFor(app.buttons["goAgain"], 10)
        snapshot("02-race")
        let again = app.buttons["resultsAgain"]
        waitFor(again, 150)
        snapshot("03-results")
        XCTAssertTrue(app.staticTexts["Nice driving!"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["ladder"].exists, "the echo ladder shows after a finish")
        again.tap()

        // GO AGAIN: the sprint restarts at once (short countdown) with the first run on the road as an echo.
        waitFor(app.buttons["pause"], 30)
        waitFor(app.buttons["resultsAgain"], 150)
        snapshot("03b-results-again")
        app.buttons["resultsMenu"].tap()

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

    /// Pause, resume, go again and quit all work during a race, and the quit asks first.
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
        XCTAssertFalse(app.buttons["resume"].waitForExistence(timeout: 2), "go again starts a fresh race")

        openPauseMenu()
        app.buttons["quit"].tap()
        let confirm = app.buttons["Quit to menu"]
        waitFor(confirm)
        confirm.tap()
        waitFor(app.buttons["continueRace"])
    }

    /// The nitro button and the drift meter are real controls with values VoiceOver can read.
    func testRaceControlsAreAccessible() {
        launch(frozen: true)
        waitFor(app.buttons["introSkip"])
        app.buttons["introSkip"].tap()
        let boost = app.buttons["boost"]
        waitFor(boost, 30)
        XCTAssertGreaterThanOrEqual(boost.frame.width, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["pause"].frame.width, 44)
        XCTAssertGreaterThanOrEqual(app.buttons["goAgain"].frame.width, 44)
        XCTAssertFalse((boost.value as? String ?? "").isEmpty)
        XCTAssertTrue(app.descendants(matching: .any)["driftMeter"].exists)
    }

    /// The first race teaches by doing: steer, hold the turn to drift, let go for the boost, then fire the nitro.
    func testTutorialTeachesDriftByDoing() {
        launch(manual: true)
        let skip = app.buttons["introSkip"]
        waitFor(skip)
        skip.tap()

        XCTAssertTrue(lessonCard(containing: "STEER").waitForExistence(timeout: 40), "first lesson: steer")
        snapshot("11-tutorial-steer")
        // Let the car get up to speed, then drag the thumb to the right and keep it there: a steer, then a drift.
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        let scene = app.descendants(matching: .any)["raceScene"]
        let from = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        let to = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.55))
        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .fast, thenHoldForDuration: 2.5)
        snapshot("12-tutorial-drift")
        let afterDrag = currentLesson()
        // Letting go ended the drift with a boost, so the lesson moved on to the nitro.
        let nitroLesson = lessonCard(containing: "swipe up")
        let shown = nitroLesson.waitForExistence(timeout: 30)
        snapshot("13-tutorial-nitro")
        XCTAssertTrue(shown, "after a drift and release the nitro lesson shows; right after the drag: \(afterDrag); now: \(currentLesson())")
        app.buttons["boost"].tap()
        XCTAssertTrue(waitForDisappearance(app.descendants(matching: .any)["tutorialCard"], seconds: 40), "firing the nitro finishes the lessons")

        // Back to the menu: through the results if the sprint has finished by now, else through the pause menu.
        if app.buttons["resultsMenu"].waitForExistence(timeout: 3) {
            app.buttons["resultsMenu"].tap()
        } else {
            openPauseMenu()
            app.buttons["quit"].tap()
            let confirm = app.buttons["Quit to menu"]
            waitFor(confirm)
            confirm.tap()
        }
        waitFor(app.buttons["continueRace"])
    }

    /// The lesson card only when its text contains `text` (a query, so it never dereferences a card that just vanished).
    private func lessonCard(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'tutorialCard' AND label CONTAINS[c] %@", text)).firstMatch
    }

    private func currentLesson() -> String {
        let card = app.descendants(matching: .any).matching(identifier: "tutorialCard").firstMatch
        return card.exists ? "\(card.label) [\(card.value as? String ?? "")]" : "(no card)"
    }

    private func waitForDisappearance(_ element: XCUIElement, seconds: TimeInterval) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: element)], timeout: seconds) == .completed
    }
}
