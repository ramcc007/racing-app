import Foundation

/// What the player (or the robot) asks the car to do this tick.
public struct ControlInput: Equatable, Sendable {
    /// Thumb down: accelerate. Thumb up: coast and slow down.
    public var throttle: Bool
    /// -1 (full left) ... 1 (full right). Positive turns towards the car's left in world terms is handled by Physics.
    public var steer: Double
    /// One-shot: spend boost, or leave the pad bay.
    public var boost: Bool
    /// One-shot: relay swap with the echo ahead (relay tracks only).
    public var swap: Bool

    public init(throttle: Bool = false, steer: Double = 0, boost: Bool = false, swap: Bool = false) {
        self.throttle = throttle
        self.steer = steer
        self.boost = boost
        self.swap = swap
    }
}

/// The road surface under a car.
public enum Surface: String, Codable, Sendable {
    case asphalt, sand, ice, water, grass
}

/// Everything about one car at one instant.
public struct CarState: Equatable, Codable, Sendable {
    public var position: Vec2
    public var velocity: Vec2
    /// Direction the nose points, radians (0 = +x).
    public var heading: Double
    /// Smoothed steering actually applied, -1...1.
    public var steer: Double = 0
    public var boostTime: Double = 0
    public var spinTime: Double = 0
    public var spinRate: Double = 0
    /// While above zero, echoes can't spin you out again.
    public var immuneTime: Double = 0
    /// While above zero the car is flying off a ramp.
    public var airTime: Double = 0
    public var docked = false
    public var undockCooldown: Double = 0
    public var drifting = false
    public var surface: Surface = .asphalt

    public init(position: Vec2, heading: Double) {
        self.position = position
        self.velocity = .zero
        self.heading = heading
    }

    public var forward: Vec2 { Vec2.fromAngle(heading) }
    /// Speed along the nose direction.
    public var forwardSpeed: Double { velocity.dot(forward) }
    public var speed: Double { velocity.length }
    public var isAirborne: Bool { airTime > 0 }
    public var isSpinning: Bool { spinTime > 0 }
}

/// Arcade top-down car model. Deterministic: the same inputs always give the same path, which is what lets echoes replay exactly.
public enum Physics {
    public static let carLength = 40.0
    public static let carWidth = 22.0
    /// Fixed simulation step: 120 per second on every device.
    public static let dt = 1.0 / 120.0
    /// Slowdown with the thumb lifted, units per second².
    public static let coast = 170.0
    public static let boostDuration = 1.1
    public static let boostTopSpeed = 1.3
    public static let draftTopSpeed = 1.05
    /// Speed below which steering fades out (you can't turn a parked car).
    static let steerFadeSpeed = 90.0

    /// Turn rate available at a given forward speed.
    public static func turnRate(speed: Double, spec: CarSpec) -> Double {
        let s = max(0, speed)
        return spec.steer * (1 - 0.35 * min(1, s / spec.topSpeed)) * min(1, s / steerFadeSpeed)
    }

    /// Fastest speed at which the car can still hold a corner of radius r (used by the robot to brake in time).
    public static func cornerSpeed(radius r: Double, spec: CarSpec) -> Double {
        // v / turnRate(v) <= r  with  turnRate(v) = steer * (1 - 0.35 v / vmax)  for v above the fade speed.
        let v = r * spec.steer / (1 + 0.35 * r * spec.steer / spec.topSpeed)
        return max(v, steerFadeSpeed)
    }

    public struct Environment: Sendable {
        public var surface: Surface = .asphalt
        public var wind: Vec2 = .zero
        public var drafting = false
        public init() {}
    }

    /// Advances one car by dt.
    public static func step(_ car: inout CarState, input: ControlInput, spec: CarSpec, env: Environment, dt: Double = dt) {
        car.boostTime = max(0, car.boostTime - dt)
        car.immuneTime = max(0, car.immuneTime - dt)
        car.undockCooldown = max(0, car.undockCooldown - dt)
        car.surface = env.surface

        if car.docked {
            car.velocity = .zero
            car.drifting = false
            return
        }
        if car.airTime > 0 {
            // In the air: no steering and no grip, a little drag, keep flying.
            car.airTime = max(0, car.airTime - dt)
            car.velocity = car.velocity * exp(-0.15 * dt)
            car.position += car.velocity * dt
            car.drifting = false
            return
        }

        let spinning = car.spinTime > 0
        let target = spinning ? 0 : clamp(input.steer, -1, 1)
        car.steer += (target - car.steer) * min(1, 14 * dt)

        let speedBefore = car.forwardSpeed
        if spinning {
            car.heading += car.spinRate * dt
            car.spinRate *= exp(-2.5 * dt)
            car.spinTime = max(0, car.spinTime - dt)
        } else {
            // Positive steer turns right (clockwise on screen with y up, i.e. heading decreases).
            car.heading -= car.steer * turnRate(speed: speedBefore, spec: spec) * dt
        }
        car.heading = wrapAngle(car.heading)

        let fwd = car.forward, right = fwd.perp * -1
        var vf = car.velocity.dot(fwd)
        var vr = car.velocity.dot(right)

        var top = spec.topSpeed
        var grip = spec.grip
        switch env.surface {
        case .asphalt: break
        case .sand:
            top *= 1 - 0.28 * spec.roughPenalty
            grip *= 0.85
        case .grass:
            top *= 1 - 0.5 * spec.roughPenalty
            grip *= 0.7
        case .ice:
            top *= 1.06
            grip *= spec.iceGrip
        case .water:
            top *= 0.3
            grip *= 0.5
        }
        if env.drafting { top *= draftTopSpeed }
        let boosting = car.boostTime > 0
        if boosting { top *= boostTopSpeed }
        let accel = spec.accel * (boosting ? 1.6 : 1)

        if input.throttle && !spinning {
            if vf < top { vf += accel * (1 - max(0, vf) / top) * dt }
        } else {
            let drop = min(abs(vf), coast * dt)
            vf -= vf > 0 ? drop : -drop
        }
        if vf > top { vf -= (vf - top) * min(1, 2.5 * dt) }

        let hard = abs(car.steer) > 0.75 && max(0, vf) > 0.7 * spec.topSpeed
        if hard { grip *= 0.42 }
        vr *= exp(-grip * dt)
        vf -= spec.scrub * abs(vr) * dt
        if spinning { vf *= exp(-1.5 * dt) }

        car.velocity = fwd * vf + right * vr + env.wind * dt
        car.position += car.velocity * dt
        car.drifting = abs(vr) > 45
    }

    /// Two circles along the body: front and back. Used for car-to-car contact.
    public static func bodyCircles(position: Vec2, heading: Double) -> (Vec2, Vec2) {
        let f = Vec2.fromAngle(heading) * 9.5
        return (position + f, position - f)
    }

    public static let bodyRadius = 10.5

    /// Whether two cars touch.
    public static func touching(_ a: Vec2, _ ah: Double, _ b: Vec2, _ bh: Double) -> Bool {
        guard (a - b).lengthSquared < 60 * 60 else { return false }
        let (a1, a2) = bodyCircles(position: a, heading: ah)
        let (b1, b2) = bodyCircles(position: b, heading: bh)
        let r2 = (2 * bodyRadius) * (2 * bodyRadius)
        for p in [a1, a2] { for q in [b1, b2] where (p - q).lengthSquared < r2 { return true } }
        return false
    }
}
