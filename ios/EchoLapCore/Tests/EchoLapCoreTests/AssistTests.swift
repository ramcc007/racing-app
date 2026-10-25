import XCTest
@testable import EchoLapCore

/// Easy controls: the assist must finish every track on its own, keep the car on the road, follow the player across
/// the road and into the bay and shortcut, and leave gold for players who use the echo tools.
final class AssistTests: XCTestCase {
    typealias Policy = (Race, AssistDriver) -> (steer: Double, boost: Bool)

    /// Hands off: no steering, no boosts.
    static let handsOff: Policy = { _, _ in (0, false) }

    /// A good easy-mode player: boosts on straights, visits the bay and takes the shortcut when it pays.
    static func goodPlayer(plan: RobotPlan) -> Policy {
        var parked = 0.0
        return { race, assist in
            let track = race.track
            let car = race.car
            if car.docked {
                parked += Physics.dt
                if parked >= max(1, plan.padHold) { parked = 0; return (0, true) }
                return (0, false)
            }
            let lap = race.crossedStart ? race.lapsDone : 0
            let i = race.location.index
            func ahead(_ t: Int) -> Double { Double(((t - i) % track.count + track.count) % track.count) * track.step }
            var steer = 0.0
            if let bay = track.bays.first, let side = assist.baySide, plan.bayLaps.contains(lap), ahead(bay.index) < 320 {
                steer = -side   // side +1 is left; steering left is negative
            } else if let sc = track.shortcut, let side = assist.shortcutSide, plan.shortcutLaps.contains(lap),
                      ahead(sc.entryIndex) < 320 {
                steer = -side
            }
            let straight = assist.lineRadii[(i + Int(150 / track.step)) % track.count] > 900
            let boost = race.boostCharge >= Race.boostCost && straight && car.forwardSpeed > 0.8 * race.spec.topSpeed
            return (steer, boost)
        }
    }

    static func drive(_ built: BuiltTrack, pace: Double = AssistDriver.defaultCornerPace, cruise: Double = AssistDriver.defaultCruise,
                      policy: Policy) -> RaceResult? {
        let track = built.track
        let race = Race(track: track, spec: Cars.pip)
        let assist = AssistDriver(track: track, cornerPace: pace, cruise: cruise)
        let limit = Double(race.laps) * (track.length / 90 + 15) + 6
        var ticks = 0
        while !race.isFinished {
            let p = policy(race, assist)
            race.tick(assist.input(for: race, steer: p.steer, boost: p.boost))
            race.events.removeAll(keepingCapacity: true)
            ticks += 1
            if race.time > limit || ticks > Int(limit * 120) + 4000 { return nil }
        }
        return race.result()
    }

    func testAssistFinishesEveryCareerTrackHandsOff() {
        var stars = [0, 0, 0, 0]
        for def in Catalog.career {
            let built = TrackLibrary.shared.build(def)
            guard let result = Self.drive(built, policy: Self.handsOff) else { return XCTFail("\(def.id): hands-off assist didn't finish") }
            XCTAssertTrue(result.finished, def.id)
            stars[built.targets.stars(for: result.totalTime)] += 1
        }
        // Easy, but not free: hands-off gold only where the gold time is generous (the early worlds); later, gold needs
        // the echo tools.
        XCTAssertLessThanOrEqual(stars[3], 75, "hands-off gold on too many tracks: \(stars)")
        XCTAssertGreaterThanOrEqual(stars[2] + stars[3], 90, "hands-off should still earn silver on most tracks: \(stars)")
    }

    func testGoodEasyPlayerCanEarnGold() {
        var stars = [0, 0, 0, 0]
        for def in Catalog.career {
            let built = TrackLibrary.shared.build(def)
            guard let result = Self.drive(built, policy: Self.goodPlayer(plan: built.targets.plan)) else {
                return XCTFail("\(def.id): good easy player didn't finish")
            }
            stars[built.targets.stars(for: result.totalTime)] += 1
        }
        XCTAssertGreaterThanOrEqual(stars[2] + stars[3], 100, "too few silver+ runs for a good easy player: \(stars)")
    }

    func testHoldingASideMovesAcrossTheRoadAndStaysOnIt() {
        let built = TrackLibrary.shared.build(Catalog.track(id: "1-2")!)
        let race = Race(track: built.track, spec: Cars.pip)
        let assist = AssistDriver(track: built.track)
        var minLateral = Double.infinity, maxLateral = -Double.infinity
        var ticks = 0
        while race.time < 8 && ticks < 120 * 20 {
            // Right for two seconds, then left for two seconds, then hands off.
            let t = race.time
            let steer: Double = t < 2 ? 1 : (t < 4 ? -1 : 0)
            race.tick(assist.input(for: race, steer: steer))
            race.events.removeAll()
            ticks += 1
            if race.crossedStart && race.time > 0.5 {
                minLateral = min(minLateral, race.location.lateral)
                maxLateral = max(maxLateral, race.location.lateral)
            }
        }
        let hw = built.track.halfWidth
        XCTAssertLessThan(minLateral, -hw * 0.4, "holding right moved the car right")
        XCTAssertGreaterThan(maxLateral, hw * 0.4, "holding left moved the car left")
        XCTAssertLessThan(max(-minLateral, maxLateral), hw, "the car stayed on the road")
        XCTAssertEqual(race.stats.offroadSeconds, 0, accuracy: 0.05)
    }

    func testSteeringTowardsThePadParksAndBoostLeaves() throws {
        let def = try XCTUnwrap(Catalog.tracks(in: .neon).first { TrackLibrary.shared.build($0).track.pad != nil })
        let built = TrackLibrary.shared.build(def)
        let plan = RobotPlan(bayLaps: [0], padHold: 1, shortcutLaps: [])
        let race = Race(track: built.track, spec: Cars.pip)
        let assist = AssistDriver(track: built.track)
        let policy = Self.goodPlayer(plan: plan)
        var docked = false, undocked = false
        var ticks = 0
        while !race.isFinished && ticks < 120 * 120 {
            let p = policy(race, assist)
            race.tick(assist.input(for: race, steer: p.steer, boost: p.boost))
            for e in race.events {
                if e == .dock { docked = true }
                if e == .undock { undocked = true }
            }
            race.events.removeAll()
            ticks += 1
            if undocked { break }
        }
        XCTAssertTrue(docked, "steering towards the bay parked the car")
        XCTAssertTrue(undocked, "boost left the bay")
    }

    func testOpenShortcutIsTakenWhenSteeredTowards() throws {
        let def = try XCTUnwrap(Catalog.tracks(in: .foundry).first { TrackLibrary.shared.build($0).track.sensor != nil })
        let built = TrackLibrary.shared.build(def)
        let all = Set(0..<def.laps)
        let result = try XCTUnwrap(Self.drive(built, policy: Self.goodPlayer(plan: RobotPlan(bayLaps: all, shortcutLaps: all))))
        XCTAssertTrue(result.finished)
        XCTAssertGreaterThan(result.stats.gatePasses, 0, "drove through the sensor bay, then the open bridge")
        XCTAssertEqual(result.stats.gateHits, 0, "never drove into a closed bridge")
    }

    /// Calibration table (run with ECHOLAP_DIAG=1): stars for hands-off and good easy play at several corner paces.
    func testDiagnosePace() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ECHOLAP_DIAG"] != nil)
        for cruise in [0.84, 0.87, 0.90, 0.93] {
            let pace = AssistDriver.defaultCornerPace
            var off = [0, 0, 0, 0], good = [0, 0, 0, 0]
            var offRatio = 0.0
            for def in Catalog.career {
                let built = TrackLibrary.shared.build(def)
                if let r = Self.drive(built, pace: pace, cruise: cruise, policy: Self.handsOff) {
                    off[built.targets.stars(for: r.totalTime)] += 1
                    offRatio += r.totalTime / built.targets.gold
                }
                if let r = Self.drive(built, pace: pace, cruise: cruise, policy: Self.goodPlayer(plan: built.targets.plan)) {
                    good[built.targets.stars(for: r.totalTime)] += 1
                }
            }
            print("cruise \(cruise): hands-off stars 1/2/3 = \(off[1])/\(off[2])/\(off[3])  (time/gold avg \(String(format: "%.3f", offRatio / 120)))  good player 1/2/3 = \(good[1])/\(good[2])/\(good[3])")
        }
    }
}
