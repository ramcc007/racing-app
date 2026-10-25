import XCTest
@testable import EchoLapCore

final class PhysicsTests: XCTestCase {
    private func straightCar() -> CarState { CarState(position: .zero, heading: 0) }

    private func run(_ car: inout CarState, seconds: Double, input: ControlInput, spec: CarSpec = Cars.pip,
                     env: Physics.Environment = Physics.Environment()) {
        for _ in 0..<Int(seconds * 120) { Physics.step(&car, input: input, spec: spec, env: env) }
    }

    func testAcceleratesToTopSpeedAndNoFurther() {
        var car = straightCar()
        run(&car, seconds: 1, input: ControlInput())
        XCTAssertGreaterThan(car.forwardSpeed, 0.6 * Cars.pip.topSpeed, "fast pick-up in the first second")
        run(&car, seconds: 6, input: ControlInput())
        XCTAssertEqual(car.forwardSpeed, Cars.pip.topSpeed, accuracy: 1.5, "settles at top speed")
        XCTAssertLessThanOrEqual(car.forwardSpeed, Cars.pip.topSpeed + 0.01)
    }

    func testBrakingSlowsAtTheBrakeRateAndNeverReverses() {
        var car = straightCar()
        car.velocity = Vec2(300, 0)
        run(&car, seconds: 0.5, input: ControlInput(brake: true))
        XCTAssertEqual(car.forwardSpeed, 300 - 0.5 * Physics.brake, accuracy: 2)
        run(&car, seconds: 3, input: ControlInput(brake: true))
        XCTAssertEqual(car.forwardSpeed, 0, accuracy: 0.01, "stops, never reverses")
    }

    func testThrottleIsAutomatic() {
        var car = straightCar()
        run(&car, seconds: 0.5, input: ControlInput())
        XCTAssertGreaterThan(car.forwardSpeed, 100, "no thumb needed to go")
    }

    func testHoldingATurnAtSpeedDriftsAndReleasingGivesABoost() {
        var car = straightCar()
        car.velocity = Vec2(320, 0)
        var tiers: [Int] = []
        for _ in 0..<Int(1.0 * 120) {
            Physics.step(&car, input: ControlInput(steer: 1), spec: Cars.pip, env: Physics.Environment())
            if car.drifting { tiers.append(car.driftTier) }
        }
        XCTAssertTrue(car.drifting, "full lock at speed is a drift")
        XCTAssertEqual(tiers.last, 2, "a one-second drift is a tier 2 boost")
        XCTAssertLessThan(car.forwardSpeed, 320, "drifting costs some speed")
        XCTAssertGreaterThan(car.forwardSpeed, 150, "but not too much")
        var released: Int?
        for _ in 0..<30 {
            Physics.step(&car, input: ControlInput(steer: 0), spec: Cars.pip, env: Physics.Environment())
            if let r = car.driftReleased { released = r }
        }
        XCTAssertEqual(released, 2)
        XCTAssertFalse(car.drifting)
        XCTAssertGreaterThan(car.boostTime, 0.4, "the boost is running")
        XCTAssertEqual(Physics.driftTier(for: 0.2), 0)
        XCTAssertEqual(Physics.driftTier(for: 0.3), 1)
        XCTAssertEqual(Physics.driftTier(for: 1.6), 3)
    }

    func testGentleSteeringDoesNotDrift() {
        var car = straightCar()
        car.velocity = Vec2(320, 0)
        run(&car, seconds: 1, input: ControlInput(steer: 0.4))
        XCTAssertFalse(car.drifting)
        XCTAssertNil(car.driftReleased)
    }

    func testDriftCornersTighterThanGrip() {
        XCTAssertGreaterThan(Physics.driftCornerSpeed(radius: 150, spec: Cars.pip), Physics.cornerSpeed(radius: 150, spec: Cars.pip))
    }

    func testPositiveSteerTurnsRight() {
        var car = straightCar()
        car.velocity = Vec2(250, 0)
        run(&car, seconds: 0.5, input: ControlInput(steer: 1))
        XCTAssertLessThan(car.heading, -0.2, "heading decreases: clockwise, to the right")
        XCTAssertLessThan(car.position.y, 0, "moved towards the right side")
    }

    func testNoTurningWhenStopped() {
        var car = straightCar()
        run(&car, seconds: 1, input: ControlInput(steer: 1, brake: true))
        XCTAssertEqual(car.heading, 0, accuracy: 1e-9)
    }

    func testCornerSpeedMatchesTurnRate() {
        for r in [60.0, 100, 140, 170, 200, 400] {
            let v = Physics.cornerSpeed(radius: r, spec: Cars.pip)
            // Above top speed the car can't go faster anyway; below it, the corner speed holds the radius exactly.
            if v > 90 && v < Cars.pip.topSpeed { XCTAssertEqual(v / Physics.turnRate(speed: v, spec: Cars.pip), r, accuracy: 0.5, "radius \(r)") }
        }
        XCTAssertLessThan(Physics.cornerSpeed(radius: 100, spec: Cars.pip), Physics.cornerSpeed(radius: 400, spec: Cars.pip))
    }

    func testSurfacesChangeTopSpeed() {
        func top(_ surface: Surface, spec: CarSpec = Cars.pip) -> Double {
            var car = straightCar()
            var env = Physics.Environment()
            env.surface = surface
            run(&car, seconds: 8, input: ControlInput(), spec: spec, env: env)
            return car.forwardSpeed
        }
        let asphalt = top(.asphalt)
        XCTAssertEqual(top(.sand), asphalt * 0.72, accuracy: 2)
        XCTAssertEqual(top(.grass), asphalt * 0.5, accuracy: 2)
        XCTAssertEqual(top(.ice), asphalt * 1.06, accuracy: 2)
        XCTAssertLessThan(top(.water), asphalt * 0.35)
        XCTAssertGreaterThan(top(.sand, spec: Cars.hopper), top(.sand), "Dune Hopper loses less on sand")
    }

    func testDraftAndBoostRaiseTopSpeed() {
        var drafting = straightCar()
        var env = Physics.Environment()
        env.drafting = true
        run(&drafting, seconds: 8, input: ControlInput(), env: env)
        XCTAssertEqual(drafting.forwardSpeed, Cars.pip.topSpeed * Physics.draftTopSpeed, accuracy: 2)

        var boosted = straightCar()
        run(&boosted, seconds: 8, input: ControlInput())
        boosted.boostTime = Physics.boostDuration
        run(&boosted, seconds: 1.0, input: ControlInput())
        XCTAssertGreaterThan(boosted.forwardSpeed, Cars.pip.topSpeed * 1.15, "boost lifts speed well above normal top speed")
        run(&boosted, seconds: 3, input: ControlInput())
        XCTAssertEqual(boosted.forwardSpeed, Cars.pip.topSpeed, accuracy: 3, "back to normal after the boost")
    }

    func testDockedCarDoesNotMove() {
        var car = straightCar()
        car.docked = true
        car.velocity = Vec2(100, 0)
        run(&car, seconds: 1, input: ControlInput(steer: 1))
        XCTAssertEqual(car.position, .zero)
        XCTAssertEqual(car.speed, 0)
    }

    func testAirborneCarIgnoresSteering() {
        var car = straightCar()
        car.velocity = Vec2(300, 0)
        car.airTime = 0.5
        run(&car, seconds: 0.4, input: ControlInput(steer: 1))
        XCTAssertEqual(car.heading, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(car.position.x, 100)
    }

    func testSpinIgnoresInputAndSlows() {
        var car = straightCar()
        car.velocity = Vec2(300, 0)
        car.spinTime = 0.8
        car.spinRate = 9
        run(&car, seconds: 0.8, input: ControlInput(steer: -1))
        XCTAssertLessThan(car.forwardSpeed.magnitude, 300)
        XCTAssertEqual(car.spinTime, 0, accuracy: 1e-9)
    }

    func testDeterministic() {
        var a = straightCar(), b = straightCar()
        let inputs: [ControlInput] = (0..<600).map { i in ControlInput(steer: sin(Double(i) / 30), brake: i % 50 >= 40) }
        for input in inputs {
            Physics.step(&a, input: input, spec: Cars.pip, env: Physics.Environment())
            Physics.step(&b, input: input, spec: Cars.pip, env: Physics.Environment())
        }
        XCTAssertEqual(a, b)
    }

    func testHardCorneringAtSpeedDrifts() {
        var car = straightCar()
        car.velocity = Vec2(330, 0)
        var drifted = false
        for _ in 0..<60 {
            Physics.step(&car, input: ControlInput(steer: 1), spec: Cars.pip, env: Physics.Environment())
            drifted = drifted || car.drifting
        }
        XCTAssertTrue(drifted)
    }

    func testCarsTouch() {
        XCTAssertTrue(Physics.touching(.zero, 0, Vec2(30, 0), 0), "nose to tail")
        XCTAssertTrue(Physics.touching(.zero, 0, Vec2(0, 20), 0), "side by side, overlapping")
        XCTAssertFalse(Physics.touching(.zero, 0, Vec2(0, 23), 0), "side by side with a gap")
        XCTAssertFalse(Physics.touching(.zero, 0, Vec2(45, 0), 0), "a car length apart")
    }
}
