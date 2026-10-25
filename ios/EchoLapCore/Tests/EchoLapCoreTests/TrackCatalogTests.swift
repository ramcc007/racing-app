import XCTest
@testable import EchoLapCore

/// Every career track, today's-style daily tracks, weekly and survival tracks: generated, validated and finished by the robot.
final class TrackCatalogTests: XCTestCase {
    /// Builds all 120 career tracks and checks every rule of the difficulty curve. Prints a table for the docs.
    func testAllCareerTracksBuildAndAreFinishable() throws {
        var rows: [String] = ["id\tattempt\tlaps\tlen\twidth\tminR\trobot\tlap avg\ttarget lap\tgold\tsilver\tplan\tfeatures"]
        var previousWidth = Double.infinity
        for def in Catalog.career {
            let built = TrackLibrary.make(def)
            let t = built.track
            let d = t.difficulty
            XCTAssertEqual(t.def, def, "generator kept the definition")
            XCTAssertGreaterThanOrEqual(t.radii.min()!, d.minRadius - 1e-6, "\(def.id): corner tighter than the curve allows")
            XCTAssertTrue(TrackGenerator.selfClearance(t.points, minDistance: d.roadWidth + 2 * TrackGenerator.kerb + 40,
                                                       skip: Int(t.halfWidth * 4 / t.step) + 6), "\(def.id): track overlaps itself")
            XCTAssertEqual(built.targets.robotLapTimes.count, def.laps, "\(def.id): robot finished every lap")
            XCTAssertLessThan(built.targets.gold, built.targets.silver, "\(def.id): gold is faster than silver")
            XCTAssertGreaterThan(built.targets.gold, built.targets.robotTime, "\(def.id): gold leaves a margin over the robot")
            // Features the definition asks for are really on the track.
            if def.features.contains(.sand) { XCTAssertTrue(t.patches.contains { $0.kind == .sand }, "\(def.id): sand") }
            if def.features.contains(.thinIce) { XCTAssertTrue(t.patches.contains { $0.kind == .ice }, "\(def.id): ice") }
            if def.features.contains(.pads) && !def.features.contains(.sensors) {
                XCTAssertEqual(t.shortcut?.trigger, .pad, "\(def.id): pad shortcut")
                XCTAssertNotNil(t.pad, "\(def.id): pad bay")
            }
            if def.features.contains(.sensors) { XCTAssertEqual(t.shortcut?.trigger, .sensor, "\(def.id): sensor shortcut") }
            if def.features.contains(.wind) { XCTAssertGreaterThanOrEqual(t.winds.count, 2, "\(def.id): wind") }
            if def.features.contains(.jumps) { XCTAssertGreaterThanOrEqual(t.jumps.count, 2, "\(def.id): jumps") }
            // Road narrows (or stays) along the career except for breathers.
            if def.kind == .normal {
                XCTAssertLessThanOrEqual(d.roadWidth, previousWidth + 1e-9, "\(def.id): road width only narrows")
                previousWidth = d.roadWidth
            }
            let laps = built.targets.robotLapTimes
            let avgLap = laps.dropFirst().isEmpty ? laps[0] : laps.dropFirst().reduce(0, +) / Double(laps.count - 1)
            let targetLap = d.lapLength / Difficulty.assumedLapSpeed
            rows.append(String(format: "%@\t%d\t%d\t%.0f\t%.1f\t%.0f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%@\t%@",
                               def.id, t.attempt, def.laps, t.length, d.roadWidth, t.radii.min()!, built.targets.robotTime, avgLap,
                               targetLap, built.targets.gold, built.targets.silver, describe(built.targets.plan),
                               def.features.map(\.rawValue).sorted().joined(separator: ",")))
        }
        let report = rows.joined(separator: "\n")
        print(report)
        if let out = ProcessInfo.processInfo.environment["ECHOLAP_TRACK_REPORT"] {
            try report.write(toFile: out, atomically: true, encoding: .utf8)
        }
    }

    /// The next 45 daily tracks, 6 weekly gauntlets and 10 survival tracks all build and the robot finishes them.
    func testDailyWeeklyAndSurvivalTracksBuild() {
        let today = DayKey(year: 2026, month: 10, day: 25)
        for k in 0..<45 {
            let def = Catalog.daily(today.adding(days: k))
            let built = TrackLibrary.make(def)
            XCTAssertEqual(built.targets.robotLapTimes.count, def.laps, def.id)
            XCTAssertEqual(built.track.def.features, def.features, "\(def.id): no fallback to a plain loop")
        }
        for k in 0..<6 {
            for def in Catalog.weekly(today.adding(days: 7 * k).week) {
                XCTAssertEqual(TrackLibrary.make(def).targets.robotLapTimes.count, def.laps, def.id)
            }
        }
        for k in 0..<10 {
            let def = Catalog.survival(today.adding(days: k))
            XCTAssertEqual(TrackLibrary.make(def).targets.robotLapTimes.count, 3, def.id)
        }
    }

    /// The same definition always gives exactly the same circuit and targets (the daily track must match for everyone).
    func testBuildsAreDeterministic() {
        for id in ["1-1", "3-7", "6-12", "8-15"] {
            let def = Catalog.track(id: id)!
            let a = TrackLibrary.make(def), b = TrackLibrary.make(def)
            XCTAssertEqual(a.track.points, b.track.points, id)
            XCTAssertEqual(a.track.patches, b.track.patches, id)
            XCTAssertEqual(a.track.shortcut, b.track.shortcut, id)
            XCTAssertEqual(a.targets, b.targets, id)
        }
    }

    private func describe(_ plan: RobotPlan) -> String {
        if plan.bayLaps.isEmpty && plan.shortcutLaps.isEmpty { return "plain" }
        return "bay\(plan.bayLaps.sorted())+hold\(String(format: "%.1f", plan.padHold))+short\(plan.shortcutLaps.sorted())"
    }
}
