import Foundation
@testable import EchoLapCore

/// Hand-built tracks with known geometry, so each rule can be tested in an exact situation.
enum TestTracks {
    static func def(features: Set<Feature> = [], laps: Int = 3, world: World = .canyon, index: Int = 20,
                    mode: RaceMode = .career, id: String = "test") -> TrackDef {
        TrackDef(id: id, world: world, slot: 1, index: index, kind: .normal, laps: laps, seed: 1, name: "Test",
                 features: features, mode: mode)
    }

    /// An anticlockwise circle of the given radius, start line at angle 0.
    static func circle(radius: Double = 600, halfWidth: Double = 36, def: TrackDef = def(),
                       patches: [SurfacePatch] = [], shortcut: Shortcut? = nil, bays: [Bay] = [],
                       winds: [WindZone] = [], jumps: [Jump] = []) -> Track {
        let step = 8.0
        let n = Int((2 * .pi * radius / step).rounded())
        let pts = (0..<n).map { i -> Vec2 in
            let a = Double(i) / Double(n) * 2 * .pi
            return Vec2(cos(a) * radius, sin(a) * radius)
        }
        let realStep = 2 * .pi * radius / Double(n)
        return Track(def: def, difficulty: Difficulty.of(def), step: realStep, points: pts, tangents: Geometry.tangents(pts),
                     radii: Geometry.radii(pts), halfWidth: halfWidth, patches: patches, shortcut: shortcut, bays: bays,
                     winds: winds, jumps: jumps, attempt: 0)
    }

    /// A circle with a diameter shortcut (quarter to three-quarters of the lap) and a bay of the given kind before it.
    static func circleWithShortcut(trigger: Bay.Kind, laps: Int = 4) -> Track {
        let base = circle()
        let n = base.count
        let i = n / 4, j = 3 * n / 4
        let sc = Shortcut(entryIndex: i, exitIndex: j, a: base.points[i], b: base.points[j], halfWidth: 30, trigger: trigger)
        let bayIndex = i - 40
        // Outside the circle: outward = -left normal for an anticlockwise loop.
        let center = base.points[bayIndex] - base.normal(bayIndex) * (36 + 30)
        let bay = Bay(kind: trigger, index: bayIndex, center: center, radius: 26)
        let features: Set<Feature> = [trigger == .pad ? .pads : .sensors]
        return circle(def: def(features: features, laps: laps), shortcut: sc, bays: [bay])
    }

    /// A still echo parked at a point for a number of frames.
    static func parkedEcho(at p: Vec2, heading: Double, frames: Int = 2000, docked: Bool = false, lap: Int = 1) -> Echo {
        var data: [Float] = []
        data.reserveCapacity(frames * 4)
        for _ in 0..<frames {
            data += [Float(p.x), Float(p.y), Float(heading), docked ? 1 : 0]
        }
        return Echo(lap: lap, frames: data)
    }

    /// An echo driving round the circle at constant speed, starting at `startIndex`.
    static func movingEcho(on track: Track, startIndex: Int, speed: Double, frames: Int = 3000) -> Echo {
        var data: [Float] = []
        let r = track.points[0].length
        let a0 = track.points[track.wrap(startIndex)].angle
        for f in 0..<frames {
            let a = a0 + speed * Double(f) * Physics.dt / r
            let p = Vec2(cos(a) * r, sin(a) * r)
            data += [Float(p.x), Float(p.y), Float(a + .pi / 2), 0]
        }
        return Echo(lap: 1, frames: data)
    }

    /// Ticks the race with a fixed input until the predicate holds or the tick limit runs out.
    @discardableResult
    static func run(_ race: Race, ticks: Int, input: ControlInput = ControlInput(throttle: true),
                    until stop: (Race) -> Bool = { _ in false }) -> [RaceEvent] {
        var all: [RaceEvent] = []
        for _ in 0..<ticks {
            race.tick(input)
            all += race.events
            race.events.removeAll()
            if stop(race) { break }
        }
        return all
    }

    /// Steering that follows the circle (positive steer turns right; an anticlockwise circle needs left = negative).
    static func followCircle(_ race: Race, throttle: Bool = true) -> ControlInput {
        let car = race.car
        let tangentAngle = car.position.angle + .pi / 2
        let radial = car.position.length - race.track.points[0].length
        let diff = wrapAngle(tangentAngle - car.heading)
        return ControlInput(throttle: throttle, steer: clamp(-diff * 3 - radial * 0.02, -1, 1))
    }
}
