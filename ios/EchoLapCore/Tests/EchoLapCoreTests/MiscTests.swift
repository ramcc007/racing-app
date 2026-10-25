import XCTest
@testable import EchoLapCore

final class MathTests: XCTestCase {
    func testVectors() {
        let a = Vec2(3, 4)
        XCTAssertEqual(a.length, 5)
        XCTAssertEqual(a.normalized.length, 1, accuracy: 1e-12)
        XCTAssertEqual(a.perp, Vec2(-4, 3))
        XCTAssertEqual(a.dot(Vec2(1, 0)), 3)
        XCTAssertEqual(Vec2(1, 0).cross(Vec2(0, 1)), 1)
        XCTAssertEqual(wrapAngle(3 * .pi), .pi, accuracy: 1e-12)
        XCTAssertEqual(wrapAngle(-3 * .pi / 2), .pi / 2, accuracy: 1e-12)
    }

    func testSeededRandomIsRepeatableAndInRange() {
        var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42), c = SeededRandom(seed: 43)
        let xs = (0..<1000).map { _ in a.unit() }
        XCTAssertEqual(xs, (0..<1000).map { _ in b.unit() })
        XCTAssertNotEqual(xs, (0..<1000).map { _ in c.unit() })
        XCTAssertTrue(xs.allSatisfy { $0 >= 0 && $0 < 1 })
        XCTAssertEqual(xs.reduce(0, +) / 1000, 0.5, accuracy: 0.05)
        var d = SeededRandom(seed: 7)
        XCTAssertTrue((0..<500).allSatisfy { _ in (0..<6).contains(d.int(6)) })
    }

    func testStableHashNeverChanges() {
        // The daily track for every player depends on this value: it must be identical on every device and version.
        XCTAssertEqual(stableHash(""), 0xCBF2_9CE4_8422_2325)
        XCTAssertEqual(stableHash("a"), 0xAF63_DC4C_8601_EC8C)
        XCTAssertEqual(stableHash("echolap.career.1-1"), stableHash("echolap.career.1-1"))
    }
}

final class CalendarTests: XCTestCase {
    func testOrdinalRoundTrip() {
        var day = DayKey(year: 1999, month: 12, day: 25)
        for _ in 0..<(366 * 120) {
            XCTAssertEqual(DayKey(ordinal: day.ordinal), day)
            let next = day.adding(days: 1)
            XCTAssertEqual(next.ordinal, day.ordinal + 1)
            day = next
        }
    }

    func testCalendarEdges() {
        XCTAssertEqual(DayKey(year: 2028, month: 2, day: 28).adding(days: 1), DayKey(year: 2028, month: 2, day: 29), "leap year")
        XCTAssertEqual(DayKey(year: 2027, month: 2, day: 28).adding(days: 1), DayKey(year: 2027, month: 3, day: 1))
        XCTAssertEqual(DayKey(year: 2026, month: 12, day: 31).adding(days: 1), DayKey(year: 2027, month: 1, day: 1))
        XCTAssertEqual(DayKey(year: 2000, month: 1, day: 1).ordinal, 0)
        XCTAssertEqual(DayKey("2026-10-25"), DayKey(year: 2026, month: 10, day: 25))
        XCTAssertNil(DayKey("2026-13-01"))
        XCTAssertNil(DayKey("hello"))
        XCTAssertEqual(DayKey(year: 2026, month: 10, day: 5).string, "2026-10-05")
        XCTAssertEqual(DayKey(year: 2026, month: 10, day: 25).shortLabel, "25 Oct")
    }

    func testWeeksStartOnMonday() {
        let monday = DayKey(year: 2026, month: 10, day: 19)   // a Monday
        let sunday = DayKey(year: 2026, month: 10, day: 25)
        XCTAssertEqual(monday.week, sunday.week)
        XCTAssertNotEqual(sunday.week, sunday.adding(days: 1).week)
        XCTAssertEqual(sunday.week.monday, monday)
    }

    func testDateConversionUsesTheGivenCalendar() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let date = Date(timeIntervalSince1970: 1_792_929_600)   // 2026-10-25 12:00 UTC
        XCTAssertEqual(DayKey(date: date, calendar: cal), DayKey(year: 2026, month: 10, day: 26), "local midnight, not UTC")
    }
}

final class FormatTests: XCTestCase {
    func testTimes() {
        XCTAssertEqual(TimeFormat.race(72.48), "1:12.48")
        XCTAssertEqual(TimeFormat.race(48.2), "48.20")
        XCTAssertEqual(TimeFormat.race(59.999), "1:00.00")
        XCTAssertEqual(TimeFormat.race(0), "0.00")
        XCTAssertEqual(TimeFormat.race(.infinity), "–:––.––")
        XCTAssertEqual(TimeFormat.delta(-0.42), "\u{2212}0.42")
        XCTAssertEqual(TimeFormat.delta(1.5), "+1.50")
        XCTAssertEqual(TimeFormat.spoken(72.48), "1 minute 12.48 seconds")
        XCTAssertEqual(TimeFormat.spoken(9.5), "9.50 seconds")
    }
}

final class SavedRunTests: XCTestCase {
    func testSavedRunRoundTripsAndKeepsTheBestFive() throws {
        let frames: [Float] = (0..<400).map { Float($0) * 0.5 }
        let run = SavedRun(trackID: "1-1", carID: "pip", totalTime: 31.25, frames: frames)
        XCTAssertEqual(run.frameCount, 100)
        XCTAssertEqual(run.floats(), frames)
        let data = try JSONEncoder().encode(run)
        let back = try JSONDecoder().decode(SavedRun.self, from: data)
        XCTAssertEqual(back, run)
        XCTAssertEqual(back.echo(rung: 2).lap, 2)
        XCTAssertEqual(back.echo(rung: 2).frameCount, 100)
        var runs: [SavedRun] = []
        for t in [40.0, 35, 50, 30, 45, 33, 60] {
            runs = SavedRun.keepBest(runs, adding: SavedRun(trackID: "1-1", carID: "pip", totalTime: t, frames: frames))
        }
        XCTAssertEqual(runs.map(\.totalTime), [30, 33, 35, 40, 45])
        XCTAssertEqual(SavedRun.ladder(runs, count: 2).map(\.lap), [1, 2])
        XCTAssertEqual(SavedRun.ladder(runs, count: 9).count, 5)
    }
}

final class TargetsTests: XCTestCase {
    func testStarsAndPace() {
        let t = Targets(robotTime: 100, gold: 110, silver: 120, robotLapTimes: [50, 50], plan: .plain,
                        paceTime: [0, 50, 100], paceProgress: [0, 2000, 4000])
        XCTAssertEqual(t.stars(for: 109.99), 3)
        XCTAssertEqual(t.stars(for: 110), 3, "exactly gold counts as gold")
        XCTAssertEqual(t.stars(for: 115), 2)
        XCTAssertEqual(t.stars(for: 120), 2)
        XCTAssertEqual(t.stars(for: 140), 1)
        XCTAssertEqual(t.goldPaceTime(atProgress: 1000, goldSlack: 0.1)!, 27.5, accuracy: 1e-9)
        XCTAssertEqual(t.goldPaceTime(atProgress: 9999, goldSlack: 0.1)!, 110, accuracy: 1e-9)
        XCTAssertNil(t.goldPaceTime(atProgress: -10, goldSlack: 0.1))
    }
}
