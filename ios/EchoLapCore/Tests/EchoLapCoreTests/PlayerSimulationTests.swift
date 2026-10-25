import XCTest
@testable import EchoLapCore

/// Plays every career track with simple player policies on top of the robot's line, to keep the star targets honest:
/// a player who drifts and fires the nitro must reach gold on nearly every track, and a timid player who never
/// drifts must still finish everything and earn silver on plenty.
final class PlayerSimulationTests: XCTestCase {
    private static let built: [BuiltTrack] = Catalog.career.map { TrackLibrary.shared.build($0) }

    /// Drives one sprint with a policy that turns the robot's input into the player's.
    private func drive(_ built: BuiltTrack, policy: (Race, ControlInput) -> ControlInput) -> (time: Double, stats: RaceStats, finished: Bool) {
        let race = Race(track: built.track, spec: Cars.pip, countdown: 0.1)
        let robot = RobotDriver(track: built.track, plan: built.targets.plan)
        var ticks = 0
        while !race.isFinished && ticks < 120 * 240 {
            race.tick(policy(race, robot.input(for: race)))
            race.events.removeAll(keepingCapacity: true)
            ticks += 1
        }
        return (race.time, race.stats, race.isFinished)
    }

    /// Nitro whenever it is charged; otherwise the robot's drifting line.
    private func good(_ race: Race, _ input: ControlInput) -> ControlInput {
        var out = input
        if race.boostCharge >= Race.boostCost && race.crossedStart && !race.car.docked { out.boost = true }
        return out
    }

    /// Never drifts (steering capped under the drift point) and brakes for corners by grip alone.
    private func timid(_ race: Race, _ input: ControlInput) -> ControlInput {
        var out = input
        out.steer = clamp(input.steer, -0.55, 0.55)
        out.boost = race.car.docked   // leaves a bay if running wide parked the car, never fires the nitro
        return out
    }

    func testNitroPlayerReachesGoldNearlyEverywhere() {
        var golds = 0, silvers = 0, driftBoosts = 0, boosts = 0
        var misses: [String] = []
        for built in Self.built {
            let r = drive(built, policy: good)
            XCTAssertTrue(r.finished, built.track.def.id)
            let stars = built.targets.stars(for: r.time)
            if stars == 3 { golds += 1 } else { misses.append("\(built.track.def.id) \(String(format: "%.2f", r.time)) vs gold \(built.targets.gold)") }
            if stars >= 2 { silvers += 1 }
            driftBoosts += r.stats.driftBoosts
            boosts += r.stats.boosts
        }
        print("nitro player: gold \(golds)/120, silver+ \(silvers)/120, drift boosts \(driftBoosts), nitros \(boosts); missed: \(misses)")
        XCTAssertGreaterThanOrEqual(golds, 100, "gold must be reachable with the tools the game gives: \(misses)")
        XCTAssertEqual(silvers, 120)
        XCTAssertGreaterThan(driftBoosts, 120 * 2, "the robot's line drifts a few corners a track")
    }

    func testTimidPlayerFinishesEverythingAndEarnsSilverOften() {
        var finished = 0, silvers = 0, golds = 0
        var slow: [String] = []
        for built in Self.built {
            let r = drive(built, policy: timid)
            if r.finished { finished += 1 }
            let stars = built.targets.stars(for: r.time)
            if stars >= 2 { silvers += 1 } else { slow.append("\(built.track.def.id) \(String(format: "%.2f", r.time)) vs silver \(built.targets.silver)") }
            if stars == 3 { golds += 1 }
        }
        print("timid player: finished \(finished)/120, silver+ \(silvers)/120, gold \(golds)/120; slow: \(slow.prefix(20))")
        XCTAssertEqual(finished, 120, "nobody is ever stuck")
        XCTAssertGreaterThanOrEqual(silvers, 80, "silver is for careful drivers too")
        XCTAssertLessThan(golds, 50, "but gold mostly needs the drift")
    }
}
