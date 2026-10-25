import Foundation

/// What the player (or the robot) asks the car to do this tick. The car always accelerates by itself: the thumb
/// steers, pulls down to brake, and flicks up to fire the nitro.
public struct ControlInput: Equatable, Sendable {
    /// -1 (full left) ... 1 (full right). Hold past the drift point at speed and the car drifts.
    public var steer: Double
    /// Pull the thumb down (or the robot before a hairpin): slow down hard.
    public var brake: Bool
    /// One-shot: fire the nitro meter, or leave the pad bay.
    public var boost: Bool
    /// One-shot: relay swap with the echo ahead (relay tracks only).
    public var swap: Bool

    public init(steer: Double = 0, brake: Bool = false, boost: Bool = false, swap: Bool = false) {
        self.steer = steer
        self.brake = brake
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
    /// Sliding through a corner: tighter turn, less grip, a little speed bled away, and a boost on release.
    public var drifting = false
    /// Seconds spent in the current drift (the tier of the boost it will give on release).
    public var driftTime: Double = 0
    /// Set for exactly one step when a drift ended: the tier of boost it gave (0 if it was too short).
    public var driftReleased: Int?
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
    /// 0 (no boost yet), 1, 2 or 3: the boost the current drift would give if released now.
    public var driftTier: Int { Physics.driftTier(for: driftTime) }
}

/// Arcade top-down car model. Deterministic: the same inputs always give the same path, which is what lets echoes replay exactly.
public enum Physics {
    public static let carLength = 40.0
    public static let carWidth = 22.0
    /// Fixed simulation step: 120 per second on every device.
    public static let dt = 1.0 / 120.0
    /// Braking, units per second².
    public static let brake = 420.0
    /// Nitro: duration of one fire and the top-speed multiplier while it lasts.
    public static let boostDuration = 1.1
    public static let boostTopSpeed = 1.3
    public static let draftTopSpeed = 1.05
    /// Speed below which steering fades out (you can't turn a parked car).
    static let steerFadeSpeed = 90.0

    // Drift. Entering needs real steering at real speed; leaving needs the thumb back near the middle (hysteresis).
    public static let driftEnterSteer = 0.45
    public static let driftExitSteer = 0.22
    public static let driftEnterSpeed = 0.45
    public static let driftExitSpeed = 0.3
    /// Turn rate multiplier while drifting.
    public static let driftTurn = 1.6
    /// Grip and scrub multipliers while drifting: the tail steps out and the slide costs a little speed.
    public static let driftGrip = 0.55
    public static let driftScrub = 0.3
    /// Extra speed bled per second while drifting (so a long drift is also how you slow for a hairpin).
    public static let driftDrag = 30.0
    /// Share of the killed sideways slide that comes back as forward speed, cornering normally and drifting.
    public static let redirect = 0.9
    public static let driftRedirect = 0.8
    /// Hold a drift this long for a tier 1, 2 or 3 boost on release.
    public static let driftTiers = [0.25, 0.8, 1.4]
    /// Seconds of boost each tier gives.
    public static let driftBoostSeconds = [0.0, 0.4, 0.9, 1.3]

    public static func driftTier(for seconds: Double) -> Int {
        driftTiers.filter { seconds >= $0 }.count
    }

    /// Turn rate available at a given forward speed.
    public static func turnRate(speed: Double, spec: CarSpec) -> Double {
        let s = max(0, speed)
        return spec.steer * (1 - 0.35 * min(1, s / spec.topSpeed)) * min(1, s / steerFadeSpeed)
    }

    /// Fastest speed at which the car can still hold a corner of radius r without drifting.
    public static func cornerSpeed(radius r: Double, spec: CarSpec) -> Double {
        // v / turnRate(v) <= r  with  turnRate(v) = steer * (1 - 0.35 v / vmax)  for v above the fade speed.
        let v = r * spec.steer / (1 + 0.35 * r * spec.steer / spec.topSpeed)
        return max(v, steerFadeSpeed)
    }

    /// Fastest speed for a corner of radius r when drifting through it. The slide widens the real path, so this
    /// credits only part of the extra turn rate.
    public static func driftCornerSpeed(radius r: Double, spec: CarSpec) -> Double {
        let steer = spec.steer * (1 + (driftTurn - 1) * 0.6)
        let v = r * steer / (1 + 0.35 * r * steer / spec.topSpeed)
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
        car.driftReleased = nil

        if car.docked {
            car.velocity = .zero
            endDrift(&car)
            return
        }
        if car.airTime > 0 {
            // In the air: no steering and no grip, a little drag, keep flying.
            car.airTime = max(0, car.airTime - dt)
            car.velocity = car.velocity * exp(-0.15 * dt)
            car.position += car.velocity * dt
            endDrift(&car)
            return
        }

        let spinning = car.spinTime > 0
        let target = spinning ? 0 : clamp(input.steer, -1, 1)
        car.steer += (target - car.steer) * min(1, 14 * dt)

        let speedBefore = car.forwardSpeed
        // Drift state, with hysteresis so it never flickers mid-corner.
        if spinning {
            endDrift(&car)
        } else if car.drifting {
            if abs(car.steer) < driftExitSteer || speedBefore < driftExitSpeed * spec.topSpeed { endDrift(&car) }
        } else if abs(car.steer) >= driftEnterSteer && speedBefore >= driftEnterSpeed * spec.topSpeed {
            car.drifting = true
            car.driftTime = 0
        }
        if car.drifting { car.driftTime += dt }

        if spinning {
            car.heading += car.spinRate * dt
            car.spinRate *= exp(-2.5 * dt)
            car.spinTime = max(0, car.spinTime - dt)
        } else {
            // Positive steer turns right (clockwise on screen with y up, i.e. heading decreases).
            car.heading -= car.steer * turnRate(speed: speedBefore, spec: spec) * (car.drifting ? driftTurn : 1) * dt
        }
        car.heading = wrapAngle(car.heading)

        let fwd = car.forward, right = fwd.perp * -1
        var vf = car.velocity.dot(fwd)
        var vr = car.velocity.dot(right)

        var top = spec.topSpeed
        var grip = spec.grip
        var scrub = spec.scrub
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

        if input.brake && !spinning {
            let drop = min(abs(vf), brake * dt)
            vf -= vf > 0 ? drop : -drop
        } else if !spinning {
            if vf < top { vf += accel * (1 - max(0, vf) / top) * dt }
        }
        if vf > top { vf -= (vf - top) * min(1, 2.5 * dt) }

        if car.drifting {
            grip *= driftGrip
            scrub *= driftScrub
            vf -= min(vf, driftDrag * dt)
        }
        // The tyres kill the sideways slide; most of that speed is turned into forward speed (arcade cornering
        // keeps you fast), the rest is lost to the scrub.
        let vrBefore = vr
        vr *= exp(-grip * dt)
        if vf > 0 && !spinning {
            let recovered = (vrBefore * vrBefore - vr * vr) * (car.drifting ? driftRedirect : redirect)
            vf = (vf * vf + max(0, recovered)).squareRoot()
        }
        vf -= scrub * abs(vr) * dt
        if spinning { vf *= exp(-1.5 * dt) }

        car.velocity = fwd * vf + right * vr + env.wind * dt
        car.position += car.velocity * dt
    }

    /// Ends a drift: the boost it earned starts now, and the step reports the tier.
    private static func endDrift(_ car: inout CarState) {
        guard car.drifting else { return }
        car.drifting = false
        let tier = driftTier(for: car.driftTime)
        car.driftReleased = tier
        if tier > 0 { car.boostTime = max(car.boostTime, driftBoostSeconds[tier]) }
        car.driftTime = 0
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
