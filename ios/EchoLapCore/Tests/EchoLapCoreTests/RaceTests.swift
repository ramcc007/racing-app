import XCTest
@testable import EchoLapCore

final class RaceTests: XCTestCase {
    // MARK: - Countdown, flying start, laps, echoes

    func testCountdownThenGoAndNoMovement() {
        let race = Race(track: TestTracks.circle(), spec: Cars.pip)
        let start = race.car.position
        let events = TestTracks.run(race, ticks: 359)
        XCTAssertEqual(events, [.countdown(3), .countdown(2), .countdown(1)])
        XCTAssertEqual(race.car.position, start, "the car waits for GO")
        let go = TestTracks.run(race, ticks: 1)
        XCTAssertEqual(go, [.go])
        XCTAssertEqual(race.phase, .racing)
    }

    func testClockStartsAtTheLine() {
        let race = Race(track: TestTracks.circle(), spec: Cars.pip)
        TestTracks.run(race, ticks: 360)
        XCTAssertTrue(race.isRunUp)
        TestTracks.run(race, ticks: 30)
        XCTAssertEqual(race.time, 0, "untimed run-up")
        let crossTicks = (0..<600).firstIndex { _ in
            race.tick(TestTracks.followCircle(race))
            race.events.removeAll()
            return race.crossedStart
        }
        XCTAssertNotNil(crossTicks)
        XCTAssertEqual(race.time, 0, accuracy: 1e-9, "clock is zero on the tick it crosses")
        race.tick(TestTracks.followCircle(race))
        XCTAssertEqual(race.time, Physics.dt, accuracy: 1e-9)
    }

    func testFullRaceLapsEchoesAndFinish() {
        let track = TestTracks.circle(def: TestTracks.def(laps: 3))
        let race = Race(track: track, spec: Cars.pip)
        var events: [RaceEvent] = []
        for _ in 0..<(120 * 120) where !race.isFinished {
            race.tick(TestTracks.followCircle(race))
            events += race.events
            race.events.removeAll()
        }
        XCTAssertTrue(race.isFinished)
        XCTAssertEqual(race.lapTimes.count, 3)
        XCTAssertEqual(race.echoes.count, 2, "laps 1 and 2 became echoes; the last lap does not")
        XCTAssertEqual(race.time, race.lapTimes.reduce(0, +), accuracy: 1e-6, "race time is the sum of laps")
        let lapEvents = events.compactMap { e -> Int? in if case let .lap(n, _) = e { return n } else { return nil } }
        XCTAssertEqual(lapEvents, [1, 2, 3])
        XCTAssertEqual(events.filter { $0 == .finished }.count, 1)
        // A circle of radius 600 is driven flat out; holding the corner scrubs a little speed (under 12%).
        for lap in race.lapTimes {
            XCTAssertGreaterThanOrEqual(lap, track.length / Cars.pip.topSpeed - 0.05)
            XCTAssertLessThan(lap, track.length / Cars.pip.topSpeed * 1.12)
        }
        let result = race.result()
        XCTAssertTrue(result.finished)
        XCTAssertEqual(result.lapsCompleted, 3)
    }

    func testEchoReplaysTheLapExactly() {
        let track = TestTracks.circle(def: TestTracks.def(laps: 2))
        let race = Race(track: track, spec: Cars.pip)
        var lap1: [Vec2] = []
        var wasCrossed = false
        while race.lapsDone == 0 && race.time < 60 {
            race.tick(TestTracks.followCircle(race))
            race.events.removeAll()
            // Frame 0 is the first tick after the line (the crossing tick itself isn't part of any lap).
            if wasCrossed { lap1.append(race.car.position) }
            wasCrossed = race.crossedStart
        }
        XCTAssertEqual(race.echoes.count, 1)
        let echo = race.echoes[0]
        XCTAssertEqual(echo.frameCount, lap1.count, "one frame per tick of lap 1")
        for f in stride(from: 0, to: lap1.count, by: 97) {
            let pose = echo.pose(at: f)!
            XCTAssertEqual(pose.position.x, lap1[f].x, accuracy: 0.01)
            XCTAssertEqual(pose.position.y, lap1[f].y, accuracy: 0.01)
        }
        XCTAssertNil(echo.pose(at: lap1.count), "an echo disappears when its lap is over")
    }

    func testBackwardsOverTheLineDoesNotCountALap() {
        let race = Race(track: TestTracks.circle(), spec: Cars.pip)
        race.testingStart(at: 5)
        race.testingSetCar { $0.heading += .pi; $0.position = race.track.points[5] }
        TestTracks.run(race, ticks: 240, input: ControlInput())
        XCTAssertEqual(race.lapsDone, 0)
    }

    // MARK: - Echo contact

    func testEchoTurnsSolidOnlyAfterYouPullClear() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 100, speed: 0)
        race.testingInsertEcho(TestTracks.parkedEcho(at: track.points[100], heading: track.tangents[100].angle))
        TestTracks.run(race, ticks: 5, input: ControlInput(brake: true))
        XCTAssertFalse(race.echoes[0].solid, "overlapping at the start: not solid")
        XCTAssertEqual(race.stats.bumps, 0)
        TestTracks.run(race, ticks: 200, input: ControlInput()) { r in r.echoes[0].solid }
        XCTAssertTrue(race.echoes[0].solid)
    }

    func testBumpingASolidEchoSpinsYouOnce() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 100, speed: 250)
        var echo = TestTracks.parkedEcho(at: track.points[112], heading: track.tangents[112].angle)
        echo.solid = true
        race.testingInsertEcho(echo)
        let events = TestTracks.run(race, ticks: 60, input: ControlInput())
        XCTAssertEqual(events.filter { $0 == .bump }.count, 1, "immunity stops a double bump")
        XCTAssertEqual(race.stats.bumps, 1)
        XCTAssertGreaterThan(race.car.immuneTime, 0)
        XCTAssertLessThan(race.car.speed, 250)
    }

    func testSoftEchoesNeverSpinYou() {
        let track = TestTracks.circle(def: TestTracks.def(features: [.softEchoes], world: .harbour, index: 3))
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 100, speed: 250)
        var echo = TestTracks.parkedEcho(at: track.points[112], heading: track.tangents[112].angle)
        echo.solid = true
        race.testingInsertEcho(echo)
        let events = TestTracks.run(race, ticks: 60, input: ControlInput())
        XCTAssertFalse(events.contains(.bump))
        XCTAssertTrue(events.contains(.softTouch))
        XCTAssertEqual(race.stats.softTouches, 1)
        XCTAssertEqual(race.car.spinTime, 0)
    }

    func testSurvivalEndsAfterThreeBumps() {
        let track = TestTracks.circle(def: TestTracks.def(laps: Int.max, mode: .survival))
        let race = Race(track: track, spec: Cars.pip, laps: Int.max, lives: 3)
        var lost: [Int] = []
        for k in 0..<3 {
            race.testingStart(at: 100 + k * 60, speed: 250)
            var echo = TestTracks.parkedEcho(at: track.points[112 + k * 60], heading: track.tangents[112 + k * 60].angle)
            echo.solid = true
            race.testingInsertEcho(echo)
            race.testingSetCar { $0.immuneTime = 0 }
            for e in TestTracks.run(race, ticks: 40) { if case let .lifeLost(n) = e { lost.append(n) } }
        }
        XCTAssertEqual(lost, [2, 1, 0])
        XCTAssertTrue(race.isFinished)
        XCTAssertEqual(race.livesLeft, 0)
    }

    // MARK: - Slipstream and boost

    func testDraftingFillsBoostAndBoostSpendsIt() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 200, speed: 300)
        // An echo two car-lengths ahead, going the same speed.
        race.testingInsertEcho(TestTracks.movingEcho(on: track, startIndex: 200 + 10, speed: 300))
        var events: [RaceEvent] = []
        for _ in 0..<240 {
            race.tick(TestTracks.followCircle(race, brake: race.car.forwardSpeed > 300))
            events += race.events
            race.events.removeAll()
        }
        XCTAssertTrue(events.contains(.draftStart))
        XCTAssertGreaterThan(race.stats.draftSeconds, 1)
        XCTAssertGreaterThan(race.boostCharge, 0.34)
        let before = race.boostCharge
        race.tick(ControlInput(boost: true))
        XCTAssertTrue(race.events.contains(.boost))
        XCTAssertEqual(race.boostCharge, before - Race.boostCost, accuracy: 0.01)
        XCTAssertEqual(race.car.boostTime, Physics.boostDuration, accuracy: 0.02)
        XCTAssertEqual(race.stats.boosts, 1)
    }

    func testBumpingASolidEchoEmptiesTheNitro() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 100, speed: 250)
        race.testingSetBoost(0.9)
        var echo = TestTracks.parkedEcho(at: track.points[112], heading: track.tangents[112].angle)
        echo.solid = true
        race.testingInsertEcho(echo)
        TestTracks.run(race, ticks: 60)
        XCTAssertEqual(race.stats.bumps, 1)
        XCTAssertLessThan(race.boostCharge, 0.05, "risk: a touch costs the whole meter")
    }

    func testPassingASolidEchoByAWhiskerIsANearMiss() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        // A parked echo one car width to the inside of the centreline; drive past on the centreline, just clear of it.
        let i = 112
        race.testingStart(at: 100, speed: 300, lateral: 0)
        var echo = TestTracks.parkedEcho(at: track.points[i] + track.normal(i) * 26, heading: track.tangents[i].angle)
        echo.solid = true
        race.testingInsertEcho(echo)
        let before = race.boostCharge
        let events = TestTracks.run(race, ticks: 90, input: ControlInput(steer: 0)) { r in r.stats.nearMisses > 0 || r.stats.bumps > 0 }
        XCTAssertEqual(race.stats.bumps, 0, "no contact")
        XCTAssertTrue(events.contains(.nearMiss))
        XCTAssertEqual(race.stats.nearMisses, 1)
        XCTAssertEqual(race.boostCharge, before + Race.nearMissGain, accuracy: 0.02)
    }

    func testPassingWideIsNotANearMiss() {
        let track = TestTracks.circle(halfWidth: 60)
        let race = Race(track: track, spec: Cars.pip)
        let i = 112
        race.testingStart(at: 100, speed: 300)
        var echo = TestTracks.parkedEcho(at: track.points[i] + track.normal(i) * 48, heading: track.tangents[i].angle)
        echo.solid = true
        race.testingInsertEcho(echo)
        TestTracks.run(race, ticks: 90, input: ControlInput(steer: 0))
        XCTAssertEqual(race.stats.nearMisses, 0)
    }

    func testRidingTheEdgeFillsTheNitroSlowly() {
        let track = TestTracks.circle(halfWidth: 40)
        let race = Race(track: track, spec: Cars.pip)
        // Start on the outer edge of the road (the left normal points inwards on an anticlockwise circle).
        race.testingStart(at: 10, speed: 320, lateral: -30)
        var events: [RaceEvent] = []
        for _ in 0..<240 {
            let car = race.car
            // Hold a line 30 units outside the centre: a gentle follow controller aimed at the outer edge.
            let tangentAngle = car.position.angle + .pi / 2
            let radial = car.position.length - (race.track.points[0].length + 30)
            let diff = wrapAngle(tangentAngle - car.heading)
            race.tick(ControlInput(steer: clamp(-diff * 5 - radial * 0.05, -0.55, 0.55)))
            events += race.events
            race.events.removeAll()
        }
        XCTAssertTrue(events.contains(.edgeStart))
        XCTAssertGreaterThan(race.stats.edgeSeconds, 1.0)
        XCTAssertGreaterThan(race.boostCharge, 0.08)
        XCTAssertLessThan(race.stats.offroadSeconds, 0.3)
    }

    func testEchoesFromEarlierRunsRaceFromTheLine() {
        let track = TestTracks.circle(def: TestTracks.def(laps: 1))
        // Record one run.
        let first = Race(track: track, spec: Cars.pip, laps: 1)
        while !first.isFinished && first.time < 60 { first.tick(TestTracks.followCircle(first)); first.events.removeAll() }
        XCTAssertTrue(first.isFinished)
        let run = SavedRun(race: first)
        XCTAssertEqual(run.frameCount, first.recordedFrames.count / 4)
        XCTAssertEqual(run.floats(), first.recordedFrames)
        // Race it.
        let second = Race(track: track, spec: Cars.pip, laps: 1, echoes: SavedRun.ladder([run], count: 1), countdown: 1)
        XCTAssertEqual(second.ladderEchoes, 1)
        XCTAssertEqual(second.echoes[0].lap, 1)
        var seenEchoOnRoad = false
        while !second.isFinished && second.time < 60 {
            second.tick(TestTracks.followCircle(second))
            second.events.removeAll()
            if second.crossedStart, second.echoPoses()[0] != nil { seenEchoOnRoad = true }
        }
        XCTAssertTrue(seenEchoOnRoad)
        XCTAssertEqual(second.result().echoesOnRoad, 1)
        XCTAssertEqual(second.time, first.time, accuracy: 0.05, "the same driving takes the same time")
    }

    func testShortCountdownForQuickRetries() {
        let race = Race(track: TestTracks.circle(), spec: Cars.pip, countdown: 1)
        let events = TestTracks.run(race, ticks: 121)
        XCTAssertEqual(events, [.countdown(1), .go])
    }

    func testDriftingGivesABoostAndFillsTheNitro() {
        let track = TestTracks.circle(radius: 220, halfWidth: 60)
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 10, speed: 330)
        var events: [RaceEvent] = []
        for _ in 0..<(120 * 3) {
            race.tick(TestTracks.followCircle(race))
            events += race.events
            race.events.removeAll()
        }
        XCTAssertTrue(events.contains(.driftStart), "a tight circle at speed is a drift")
        XCTAssertGreaterThan(race.stats.driftSeconds, 0.3)
        XCTAssertGreaterThan(race.stats.drifts, 0)
    }

    func testBoostWithoutChargeDoesNothing() {
        let race = Race(track: TestTracks.circle(), spec: Cars.pip)
        race.testingStart(at: 10, speed: 200)
        race.tick(ControlInput(boost: true))
        XCTAssertTrue(race.events.contains(.boostEmpty))
        XCTAssertEqual(race.car.boostTime, 0)
    }

    func testNeedleDraftsFaster() {
        func charge(_ spec: CarSpec) -> Double {
            let track = TestTracks.circle()
            let race = Race(track: track, spec: spec)
            race.testingStart(at: 200, speed: 300)
            race.testingInsertEcho(TestTracks.movingEcho(on: track, startIndex: 210, speed: 300))
            for _ in 0..<120 { race.tick(TestTracks.followCircle(race, brake: race.car.forwardSpeed > 300)); race.events.removeAll() }
            return race.boostCharge
        }
        XCTAssertGreaterThan(charge(Cars.needle), charge(Cars.pip) * 1.3)
    }

    // MARK: - Pads, gates and sensors

    func testParkingOnThePadOpensTheGateAndBoostLeaves() {
        let track = TestTracks.circleWithShortcut(trigger: .pad)
        let pad = track.pad!
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: pad.index - 6)
        race.testingSetCar { $0.position = pad.center + Vec2(3, 0); $0.velocity = .zero }
        var events = TestTracks.run(race, ticks: 2, input: ControlInput(brake: true))
        XCTAssertTrue(race.car.docked)
        XCTAssertTrue(events.contains(.dock))
        XCTAssertTrue(events.contains(.gateOpened))
        XCTAssertTrue(race.gateOpen)
        events = TestTracks.run(race, ticks: 240, input: ControlInput())
        XCTAssertTrue(race.car.docked, "stays parked until you choose to leave")
        race.tick(ControlInput(boost: true))
        XCTAssertTrue(race.events.contains(.undock))
        XCTAssertFalse(race.car.docked)
        XCTAssertGreaterThan(race.car.speed, 100)
        race.events.removeAll()
        events = TestTracks.run(race, ticks: 130, input: ControlInput())
        XCTAssertTrue(events.contains(.gateClosed), "closes about a second after the bay empties")
        XCTAssertFalse(race.gateOpen)
    }

    func testAParkedEchoHoldsTheGateOpen() {
        let track = TestTracks.circleWithShortcut(trigger: .pad)
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 10)
        race.testingInsertEcho(TestTracks.parkedEcho(at: track.pad!.center, heading: 0, docked: true))
        TestTracks.run(race, ticks: 3)
        XCTAssertTrue(race.gateOpen)
    }

    func testClosedGateBlocksTheShortcut() {
        let track = TestTracks.circleWithShortcut(trigger: .pad)
        let sc = track.shortcut!
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: sc.entryIndex)
        race.testingSetCar {
            $0.position = sc.gateCenter - sc.direction * 120
            $0.heading = sc.direction.angle
            $0.velocity = sc.direction * 250
        }
        let events = TestTracks.run(race, ticks: 90)
        XCTAssertTrue(events.contains(.gateHit))
        XCTAssertLessThan((race.car.position - sc.gateCenter).dot(sc.direction), 0, "still on the near side")
    }

    func testEchoHeldGatePassCounts() {
        let track = TestTracks.circleWithShortcut(trigger: .pad)
        let sc = track.shortcut!
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: sc.entryIndex)
        race.testingInsertEcho(TestTracks.parkedEcho(at: track.pad!.center, heading: 0, docked: true))
        race.testingSetCar {
            $0.position = sc.gateCenter - sc.direction * 120
            $0.heading = sc.direction.angle
            $0.velocity = sc.direction * 250
        }
        TestTracks.run(race, ticks: 90)
        XCTAssertEqual(race.stats.gatePasses, 1)
        XCTAssertEqual(race.stats.echoGatePasses, 1)
        XCTAssertEqual(race.stats.gateHits, 0)
    }

    func testSensorLowersTheBridgeForFiveSeconds() {
        let track = TestTracks.circleWithShortcut(trigger: .sensor)
        let sensor = track.sensor!
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: sensor.index - 6)
        race.testingSetCar { $0.position = sensor.center; $0.velocity = .zero }
        TestTracks.run(race, ticks: 2, input: ControlInput(brake: true))
        XCTAssertTrue(race.gateOpen)
        XCTAssertFalse(race.car.docked, "sensors never park you")
        TestTracks.run(race, ticks: Int(4.8 * 120), input: ControlInput(brake: true))
        XCTAssertTrue(race.gateOpen)
        race.testingSetCar { $0.position = sensor.center + Vec2(0, 200) }
        TestTracks.run(race, ticks: 60, input: ControlInput(brake: true))
        XCTAssertFalse(race.gateOpen)
    }

    // MARK: - Thin ice

    func testIceCracksOnEachPassAndBreaksAfterThree() {
        let base = TestTracks.circle()
        let ice = SurfacePatch(id: 0, kind: .ice, startIndex: 100, count: 15, lateralMin: -40, lateralMax: 40)
        let track = TestTracks.circle(def: TestTracks.def(features: [.thinIce]), patches: [ice])
        _ = base
        let race = Race(track: track, spec: Cars.pip)
        var events: [RaceEvent] = []
        func drivePast() -> [RaceEvent] {
            var all: [RaceEvent] = []
            for _ in 0..<110 { race.tick(TestTracks.followCircle(race)); all += race.events; race.events.removeAll() }
            return all
        }
        for pass in 1...3 {
            race.testingStart(at: 92, speed: 250)
            race.testingSetCar { $0.immuneTime = 0 }
            events = drivePast()
            XCTAssertEqual(race.iceWear[0], pass, "pass \(pass)")
            XCTAssertTrue(events.contains(.iceCrack(patch: 0, wear: pass)))
        }
        XCTAssertTrue(events.contains(.iceBreak(patch: 0)))
        XCTAssertEqual(race.stats.iceBreaks, 1)
        race.testingStart(at: 92, speed: 250)
        events = drivePast()
        XCTAssertTrue(events.contains(.splash))
        XCTAssertEqual(race.stats.splashes, 1)
        XCTAssertGreaterThan(race.car.spinTime, 0)
    }

    func testIceIsFastAndSlippery() {
        let ice = SurfacePatch(id: 0, kind: .ice, startIndex: 0, count: 470, lateralMin: -40, lateralMax: 40)
        let track = TestTracks.circle(def: TestTracks.def(features: [.thinIce]), patches: [ice])
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 10, speed: 200)
        TestTracks.run(race, ticks: 2)
        XCTAssertEqual(race.car.surface, .ice)
    }

    // MARK: - Relay swap, jumps, wind, sand, off-road

    func testRelaySwapJumpsToTheEchoAheadOncePerLap() {
        let track = TestTracks.circle(def: TestTracks.def(features: [.relay]))
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 100, speed: 250)
        race.testingInsertEcho(TestTracks.movingEcho(on: track, startIndex: 130, speed: 250))
        TestTracks.run(race, ticks: 1, input: TestTracks.followCircle(race))
        let before = race.progress
        race.tick(ControlInput(swap: true))
        XCTAssertTrue(race.events.contains(.swap))
        XCTAssertGreaterThan(race.progress - before, Physics.carLength)
        XCTAssertEqual(race.stats.swaps, 1)
        race.events.removeAll()
        race.tick(ControlInput(swap: true))
        XCTAssertTrue(race.events.contains(.swapUnavailable), "only once a lap")
    }

    func testSwapUnavailableWithoutRelayRule() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 100, speed: 250)
        race.testingInsertEcho(TestTracks.movingEcho(on: track, startIndex: 130, speed: 250))
        race.tick(ControlInput(swap: true))
        XCTAssertTrue(race.events.contains(.swapUnavailable))
    }

    func testRampLaunchesAJumpAndYouLand() {
        let base = TestTracks.circle()
        let jump = Jump(index: 120, center: base.points[120], direction: base.tangents[120])
        let track = TestTracks.circle(def: TestTracks.def(features: [.jumps]), jumps: [jump])
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 110, speed: 320)
        var events: [RaceEvent] = []
        for _ in 0..<240 { race.tick(TestTracks.followCircle(race)); events += race.events; race.events.removeAll() }
        XCTAssertTrue(events.contains(.jump))
        XCTAssertTrue(events.contains(.land))
        XCTAssertEqual(race.stats.jumps, 1)
    }

    func testNoJumpWhenSlow() {
        let base = TestTracks.circle()
        let jump = Jump(index: 120, center: base.points[120], direction: base.tangents[120])
        let track = TestTracks.circle(def: TestTracks.def(features: [.jumps]), jumps: [jump])
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 117, speed: 100)
        TestTracks.run(race, ticks: 60, input: ControlInput(brake: true))
        XCTAssertEqual(race.stats.jumps, 0)
    }

    func testWindPushesAndAnEchoShelters() {
        let base = TestTracks.circle()
        let push = base.normal(150) * 200
        let wind = WindZone(startIndex: 100, count: 120, force: push)
        let track = TestTracks.circle(def: TestTracks.def(features: [.wind]), winds: [wind])
        let calm = TestTracks.circle()
        func end(_ t: Track, sheltered: Bool) -> Vec2 {
            let race = Race(track: t, spec: Cars.pip)
            race.testingStart(at: 140, speed: 250)
            if sheltered { race.testingInsertEcho(TestTracks.movingEcho(on: t, startIndex: 142 + 6, speed: 250)) }
            TestTracks.run(race, ticks: 30, input: ControlInput(brake: true))
            return race.car.position
        }
        // Sideways drift caused by the wind = windy end position minus the calm one.
        let open = (end(track, sheltered: false) - end(calm, sheltered: false)).dot(push.normalized)
        let behind = (end(track, sheltered: true) - end(calm, sheltered: true)).dot(push.normalized)
        XCTAssertGreaterThan(open, 1, "wind pushes you sideways")
        XCTAssertLessThan(behind, open, "an echo ahead shelters you")
    }

    func testSandSlowsYou() {
        let sand = SurfacePatch(id: 0, kind: .sand, startIndex: 0, count: 470, lateralMin: -40, lateralMax: 40)
        let track = TestTracks.circle(def: TestTracks.def(features: [.sand]), patches: [sand])
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 10, speed: 0)
        for _ in 0..<(120 * 8) { race.tick(TestTracks.followCircle(race)); race.events.removeAll() }
        XCTAssertEqual(race.car.surface, .sand)
        XCTAssertLessThan(race.car.forwardSpeed, Cars.pip.topSpeed * 0.75)
    }

    func testTheBarrierKeepsYouOnTheTrackAndAHardHitCostsSpeed() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 0, speed: 300)
        // Drive straight off the circle for three seconds: the barrier along the kerb stops you.
        let events = TestTracks.run(race, ticks: 360, input: ControlInput(steer: 0))
        XCTAssertTrue(events.contains(.wallHit))
        XCTAssertEqual(race.stats.wallHits, 1, "one hit, then a scrape along the wall")
        XCTAssertFalse(race.offroad, "never in the scenery")
        XCTAssertLessThanOrEqual(race.location.distance, track.halfWidth + Race.wallOffset + 0.5)
        XCTAssertEqual(race.stats.offroadSeconds, 0, accuracy: 0.05)
    }

    func testAGlancingScrapeAlongTheBarrierIsNotAHit() {
        let track = TestTracks.circle(halfWidth: 40)
        let race = Race(track: track, spec: Cars.pip)
        // Start on the outer edge, pointing almost along the road, drifting slowly outwards into the wall.
        race.testingStart(at: 10, speed: 300, lateral: -(40 + Race.wallOffset - 2))
        race.testingSetCar { $0.heading -= 0.06 }
        let before = race.car.speed
        let events = TestTracks.run(race, ticks: 60, input: ControlInput(steer: 0))
        XCTAssertFalse(events.contains(.wallHit))
        XCTAssertGreaterThan(race.car.speed, before * 0.45, "a scrape costs speed but never stops you")
        XCTAssertLessThan(race.car.speed, before * 0.9, "riding the wall is slower than driving")
    }

    func testCarPinnedNoseFirstAgainstTheBarrierTurnsBackOntoTheRoad() {
        let track = TestTracks.circle()
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 10)
        let i = 10
        let out = track.normal(i) * -1   // anticlockwise circle: the left normal points inwards, so this is outwards
        race.testingSetCar { car in
            car.position = track.points[i] + out * (track.halfWidth + Race.wallOffset)
            car.heading = out.angle
            car.velocity = .zero
        }
        for _ in 0..<(120 * 4) { race.tick(ControlInput(steer: 0)) }
        XCTAssertGreaterThan(race.car.forwardSpeed, 60, "the car is moving again")
        XCTAssertGreaterThan(race.progress, track.s(10) + 100, "and going the right way")
    }

    /// The first race's drift lesson: holding full lock at speed, even on a straight, is a drift that reaches tier 1
    /// before the wall takes the speed away, and letting go gives the boost.
    func testFullLockOnAStraightTeachesTheDriftAgainstTheWall() {
        let track = TestTracks.circle(radius: 1500, halfWidth: 36)
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: 20, speed: 320)
        var events: [RaceEvent] = []
        for _ in 0..<(120 * 2) { race.tick(ControlInput(steer: 1)); events += race.events; race.events.removeAll() }
        for _ in 0..<30 { race.tick(ControlInput(steer: 0)); events += race.events; race.events.removeAll() }
        XCTAssertTrue(events.contains(.driftTier(1)), "\(events)")
        XCTAssertTrue(events.contains { if case .driftBoost(let t) = $0 { return t >= 1 } else { return false } })
        XCTAssertFalse(race.offroad)
    }

    func testTheBarrierHasGapsAtTheBayAndTheLane() {
        let track = TestTracks.circleWithShortcut(trigger: .pad)
        let pad = track.pad!
        let race = Race(track: track, spec: Cars.pip)
        race.testingStart(at: pad.index - 12, speed: 200)
        // Aim straight at the bay centre from the road.
        race.testingSetCar { car in
            car.heading = (pad.center - car.position).angle
            car.velocity = car.forward * 200
        }
        TestTracks.run(race, ticks: 120, input: ControlInput(steer: 0)) { $0.car.docked }
        XCTAssertTrue(race.car.docked, "the bay is reachable through the barrier")
    }
}
