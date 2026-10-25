import XCTest
@testable import EchoLapCore

/// Prints why generation attempts fail for chosen tracks (set ECHOLAP_DIAG=1-5,3-7). Skipped otherwise.
final class DiagnosticsTests: XCTestCase {
    func testDiagnoseTracks() throws {
        guard let list = ProcessInfo.processInfo.environment["ECHOLAP_DIAG"] else { throw XCTSkip("set ECHOLAP_DIAG") }
        for id in list.split(separator: ",").map(String.init) {
            guard let def = Catalog.track(id: id) else { continue }
            TrackGenerator.rejections = [:]
            var robotFails = 0, ok = 0
            for attempt in 0..<200 {
                guard let t = TrackGenerator.generate(def, attempt: attempt) else { continue }
                if Robot.bestRun(t) == nil { robotFails += 1 } else { ok += 1 }
            }
            print(id, "rejections:", TrackGenerator.rejections.sorted { $0.key < $1.key }, "robotFails:", robotFails, "ok:", ok)
        }
    }
}

final class RadiusDiagnostics: XCTestCase {
    func testRadiusDistribution() throws {
        guard ProcessInfo.processInfo.environment["ECHOLAP_RADIUS"] != nil else { throw XCTSkip("set ECHOLAP_RADIUS") }
        for id in ["1-1", "2-1", "4-1", "6-1", "8-1"] {
            let def = Catalog.track(id: id)!
            let d = Difficulty.of(def)
            var mins: [Double] = []
            for attempt in 0..<40 {
                var rng = SeededRandom(seed: def.seed &+ UInt64(attempt) &* 0x9E37_79B9_7F4A_7C15)
                let n = 7 + Int((d.wiggle * 5).rounded()) + rng.int(3)
                let variance = 0.22 + 0.38 * d.wiggle
                let stretch = rng.range(0.8, 1.25)
                var ctrl: [Vec2] = []
                for i in 0..<n {
                    let a = Double(i) / Double(n) * 2 * .pi + rng.range(-0.35, 0.35) * (2 * .pi / Double(n))
                    let r = 1 + rng.range(-variance, variance)
                    ctrl.append(Vec2(cos(a) * r * stretch, sin(a) * r / stretch))
                }
                var poly = Geometry.closedSpline(ctrl, perSegment: 24)
                let scale = d.lapLength / Geometry.closedLength(poly)
                poly = poly.map { $0 * scale }
                let pts = Geometry.resampleClosed(poly, step: 8)
                mins.append(Geometry.radii(pts).min()!)
            }
            mins.sort()
            print(id, "need", Int(d.minRadius), "minR quartiles", Int(mins[0]), Int(mins[10]), Int(mins[20]), Int(mins[30]), Int(mins[39]))
        }
    }
}

final class PadDiagnostics: XCTestCase {
    func testPadPlans() throws {
        guard let list = ProcessInfo.processInfo.environment["ECHOLAP_PADS"] else { throw XCTSkip("set ECHOLAP_PADS") }
        for id in list.split(separator: ",").map(String.init) {
            let def = Catalog.track(id: id)!
            let built = TrackLibrary.make(def)
            let t = built.track
            guard let sc = t.shortcut else { print(id, "no shortcut"); continue }
            print(id, "len", Int(t.length), "lane", Int(sc.length), "saves", Int(t.s(sc.exitIndex) - t.s(sc.entryIndex) - sc.length), "bay idx", t.bays.first?.index ?? -1, "entry", sc.entryIndex)
            let plain = Robot.drive(t)!
            print("  plain", String(format: "%.2f", plain.totalTime), plain.lapTimes.map { String(format: "%.2f", $0) })
            for park in [0, 1] {
                for hold in [0.5, 1.0, 2.0, 3.0, 4.0] {
                    let plan = RobotPlan(bayLaps: [park], padHold: hold, shortcutLaps: Set((park + 1)..<def.laps))
                    if let r = Robot.drive(t, plan: plan) {
                        print("  park", park, "hold", hold, String(format: "%.2f", r.totalTime), "hits", r.gateHits, "parkedAt", r.parkedAtLapTime.map { String(format: "%.2f", $0) } ?? "-", "gateAt", r.gateReachedAtLapTime.map { String(format: "%.2f", $0) } ?? "-", r.lapTimes.map { String(format: "%.1f", $0) })
                    } else { print("  park", park, "hold", hold, "DNF") }
                }
            }
            // shortcut always open check: shortcut lap time when gate is open
        }
    }
}

final class PadDiagnostics2: XCTestCase {
    func testPadLongHold() throws {
        guard let list = ProcessInfo.processInfo.environment["ECHOLAP_PADS2"] else { throw XCTSkip("set ECHOLAP_PADS2") }
        for id in list.split(separator: ",").map(String.init) {
            let def = Catalog.track(id: id)!
            let t = TrackLibrary.make(def).track
            let plan = RobotPlan(bayLaps: [0], padHold: 30, shortcutLaps: Set(1..<def.laps))
            let race = Race(track: t, spec: Cars.pip, laps: def.laps)
            let driver = RobotDriver(track: t, plan: plan)
            var ticks = 0
            var lastLog = -10.0
            while !race.isFinished && ticks < 120 * 300 {
                race.tick(driver.input(for: race)); ticks += 1
                for e in race.events where e != .draftStart { if case .countdown = e { continue }; print("  t=\(String(format: "%.2f", race.time)) lap \(race.lapsDone) \(e) pos \(Int(race.car.position.x)),\(Int(race.car.position.y)) v \(Int(race.car.speed))") }
                race.events.removeAll()
                if race.time - lastLog > 5 { lastLog = race.time; print("  .. t=\(String(format: "%.1f", race.time)) lap \(race.lapsDone) prog \(Int(race.progress)) v \(Int(race.car.speed)) docked \(race.car.docked) gate \(race.gateOpen) offroad \(race.offroad)") }
            }
            print(id, "finished", race.isFinished, "time", race.time)
        }
    }
}
