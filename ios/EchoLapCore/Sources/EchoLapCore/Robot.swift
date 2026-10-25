import Foundation

/// The robot driver: proves every track can be finished and sets the gold and silver times.
/// It drives the real physics with a pure-pursuit line follower, avoids sand and ice, never boosts, never drafts and
/// never relay-swaps, so a good player always has tools the robot doesn't use.
public struct RobotPlan: Equatable, Sendable, Codable {
    /// Laps (0-based) on which the robot visits the bay: parks on the pad, or drives through the sensor.
    public var bayLaps: Set<Int> = []
    /// Seconds to stay parked on the pad.
    public var padHold: Double = 0
    /// Laps (0-based) on which the robot takes the shortcut.
    public var shortcutLaps: Set<Int> = []

    public init(bayLaps: Set<Int> = [], padHold: Double = 0, shortcutLaps: Set<Int> = []) {
        self.bayLaps = bayLaps
        self.padHold = padHold
        self.shortcutLaps = shortcutLaps
    }

    public static let plain = RobotPlan()
}

/// A path for the robot to follow: points every `step` units and the corner radius at each.
struct Route {
    let points: [Vec2]
    let radii: [Double]
    let step: Double

    init(_ raw: [Vec2], step: Double) {
        let pts = Geometry.resampleClosed(raw, step: step)
        points = pts
        radii = Geometry.radii(pts)
        self.step = step
    }

    var count: Int { points.count }

    func nearest(to p: Vec2, around hint: Int?) -> Int {
        var best = 0, bestD = Double.infinity
        if let hint {
            for d in -40...60 {
                let i = ((hint + d) % count + count) % count
                let dist = (points[i] - p).lengthSquared
                if dist < bestD { bestD = dist; best = i }
            }
            if bestD < 90 * 90 { return best }
        }
        for i in 0..<count {
            let dist = (points[i] - p).lengthSquared
            if dist < bestD { bestD = dist; best = i }
        }
        return best
    }
}

enum Routes {
    /// Smoothed centreline, kept well inside the road, steering around sand and ice onto the clean side.
    static func racingLine(_ track: Track) -> [Vec2] {
        let n = track.count
        let smooth = Geometry.smoothClosed(track.points, window: 7, passes: 3)
        let limit = track.halfWidth * 0.42
        var lateral = (0..<n).map { i in clamp((smooth[i] - track.points[i]).dot(track.normal(i)), -limit, limit) }
        for patch in track.patches {
            let cleanCenter = patch.lateralMin > -track.halfWidth ? (-track.halfWidth + patch.lateralMin) / 2 : (patch.lateralMax + track.halfWidth) / 2
            let margin = 14
            for k in -margin...(patch.count + margin) {
                let i = track.wrap(patch.startIndex + k)
                let edge = k < 0 ? Double(margin + k) / Double(margin) : (k > patch.count ? Double(patch.count + margin - k) / Double(margin) : 1)
                let w = edge * edge * (3 - 2 * edge)
                lateral[i] = lateral[i] * (1 - w) + cleanCenter * w
            }
        }
        return (0..<n).map { track.points[$0] + track.normal($0) * lateral[$0] }
    }

    /// Bends the line through a bay centre around its index.
    static func visitBay(_ line: [Vec2], bay: Bay, track: Track) -> [Vec2] {
        var out = line
        let reach = 15
        for k in -reach...reach {
            let i = track.wrap(bay.index + k)
            let x = 1 - Double(abs(k)) / Double(reach)
            let w = x * x * (3 - 2 * x)
            out[i] = out[i] * (1 - w) + bay.center * w
        }
        return out
    }

    /// Replaces the long way between entry and exit with the straight shortcut lane.
    static func takeShortcut(_ line: [Vec2], track: Track) -> [Vec2] {
        guard let sc = track.shortcut else { return line }
        let lead = 6
        var out: [Vec2] = []
        out.append(contentsOf: line[0...(sc.entryIndex - lead)])
        for k in (sc.entryIndex - lead + 1)...sc.entryIndex { out.append(track.points[k]) }
        let steps = max(2, Int(sc.length / track.step))
        for k in 1..<steps { out.append(sc.a + (sc.b - sc.a) * (Double(k) / Double(steps))) }
        for k in sc.exitIndex...(sc.exitIndex + lead) { out.append(track.points[track.wrap(k)]) }
        if sc.exitIndex + lead + 1 < line.count { out.append(contentsOf: line[(sc.exitIndex + lead + 1)...]) }
        return Geometry.smoothClosed(out, window: 2, passes: 2)
    }
}

/// Drives one race for the robot (also used for the in-app demo and autopilot).
public final class RobotDriver {
    public let plan: RobotPlan
    let spec: CarSpec
    private var routes: [Int: Route] = [:]   // key: bay bit 1, shortcut bit 2
    private var routeKey = -1
    private var routeIndex = 0
    private var parkedFor = 0.0
    private var lastLap = -1
    private var bayVisitedThisLap = false
    private let track: Track

    public init(track: Track, plan: RobotPlan = .plain, spec: CarSpec = Cars.pip) {
        self.track = track
        self.plan = plan
        self.spec = spec
        let line = Routes.racingLine(track)
        routes[0] = Route(line, step: track.step)
        if let bay = track.bays.first {
            routes[1] = Route(Routes.visitBay(line, bay: bay, track: track), step: track.step)
        }
        if track.shortcut != nil {
            routes[2] = Route(Routes.takeShortcut(line, track: track), step: track.step)
            if let bay = track.bays.first {
                routes[3] = Route(Routes.takeShortcut(Routes.visitBay(line, bay: bay, track: track), track: track), step: track.step)
            }
        }
    }

    public func input(for race: Race) -> ControlInput {
        guard race.phase == .racing else { return ControlInput(throttle: true) }
        let car = race.car
        let lap = race.crossedStart ? race.lapsDone : 0
        if lap != lastLap {
            lastLap = lap
            bayVisitedThisLap = false
        }
        if car.docked {
            parkedFor += Physics.dt
            bayVisitedThisLap = true
            if parkedFor >= plan.padHold {
                parkedFor = 0
                return ControlInput(throttle: true, boost: true)
            }
            return ControlInput(throttle: false)
        }
        if let bay = track.bays.first, car.position.distance(to: bay.center) < bay.radius { bayVisitedThisLap = true }

        let wantBay = plan.bayLaps.contains(lap) && !bayVisitedThisLap
        let wantShortcut = plan.shortcutLaps.contains(lap)
        var key = (wantBay ? 1 : 0) | (wantShortcut ? 2 : 0)
        if routes[key] == nil { key = wantShortcut && routes[2] != nil ? 2 : 0 }
        let route = routes[key]!
        if key != routeKey {
            routeKey = key
            routeIndex = route.nearest(to: car.position, around: nil)
        } else {
            routeIndex = route.nearest(to: car.position, around: routeIndex)
        }

        let speed = max(0, car.forwardSpeed)
        let look = 38 + 0.26 * speed
        let target = route.points[(routeIndex + Int(look / route.step)) % route.count]
        let diff = wrapAngle((target - car.position).angle - car.heading)
        let steer = clamp(-diff * 2.8, -1, 1)

        let brakeDistance = speed * speed / (2 * Physics.coast) + 60
        var tightest = Double.infinity
        for k in 0...(Int(brakeDistance / route.step) + 1) {
            tightest = min(tightest, route.radii[(routeIndex + k) % route.count])
        }
        let allowed = Physics.cornerSpeed(radius: tightest, spec: spec) * 0.93
        // Never ram a closed gate: stop short of it and wait for it to open.
        if key & 2 != 0, let sc = track.shortcut, !race.gateOpen {
            let toGate = sc.gateCenter - car.position
            if toGate.dot(car.forward) > 0, toGate.length < brakeDistance + 40 {
                return ControlInput(throttle: false, steer: steer)
            }
        }
        return ControlInput(throttle: speed < allowed, steer: steer)
    }
}

/// What the robot achieved on a track.
public struct RobotResult: Sendable {
    public let plan: RobotPlan
    public let totalTime: Double
    public let lapTimes: [Double]
    public let gateHits: Int
    /// Race time against distance raced, sampled 20 times a second (for the live gold-pace delta).
    public let paceTime: [Double]
    public let paceProgress: [Double]
    /// Lap time at which the robot parked, on the first bay lap.
    public let parkedAtLapTime: Double?
    /// Lap time at which it first reached the gate on a later lap.
    public let gateReachedAtLapTime: Double?
}

public enum Robot {
    /// Drives a whole race with one plan. Nil if the robot couldn't finish in a sensible time.
    public static func drive(_ track: Track, plan: RobotPlan = .plain, laps: Int? = nil, spec: CarSpec = Cars.pip) -> RobotResult? {
        let lapCount = laps ?? track.def.laps
        let race = Race(track: track, spec: spec, laps: lapCount)
        let driver = RobotDriver(track: track, plan: plan, spec: spec)
        let limit = Double(lapCount) * (track.length / 110 + 12) + 4
        var paceT: [Double] = [], paceP: [Double] = []
        var parkedAt: Double?, gateAt: Double?
        var ticks = 0
        while !race.isFinished {
            race.tick(driver.input(for: race))
            ticks += 1
            for event in race.events {
                switch event {
                case .dock where parkedAt == nil: parkedAt = race.lapTime
                case .gateHit where gateAt == nil && race.lapsDone >= 1: gateAt = race.lapTime
                default: break
                }
            }
            race.events.removeAll(keepingCapacity: true)
            if race.phase == .racing && ticks % 6 == 0 {
                paceT.append(race.time)
                paceP.append(race.totalProgress)
            }
            if race.time > limit || ticks > Int(limit * 120) + 3000 { return nil }
        }
        return RobotResult(plan: plan, totalTime: race.time, lapTimes: race.lapTimes, gateHits: race.stats.gateHits,
                           paceTime: paceT, paceProgress: paceP, parkedAtLapTime: parkedAt, gateReachedAtLapTime: gateAt)
    }

    /// Tries the plain plan and, where the track has a shortcut, the bay strategies; returns the fastest clean run.
    public static func bestRun(_ track: Track, laps: Int? = nil) -> RobotResult? {
        let lapCount = laps ?? track.def.laps
        guard let plain = drive(track, plan: .plain, laps: lapCount) else { return nil }
        var best = plain
        guard let sc = track.shortcut, lapCount >= 3 else { return best }
        let all = Set(0..<lapCount)
        switch sc.trigger {
        case .pad:
            // Park on one lap; the parked echo holds the gate for the later laps, which arrive just after it.
            // The robot waits at a closed gate, so too short a hold only costs time: try a few holds, keep the fastest.
            for parkLap in [0, 1] where parkLap + 1 < lapCount {
                for hold in stride(from: 1.0, through: 6.0, by: 1.0) {
                    let plan = RobotPlan(bayLaps: [parkLap], padHold: hold, shortcutLaps: Set((parkLap + 1)..<lapCount))
                    if let run = drive(track, plan: plan, laps: lapCount), run.gateHits == 0, run.totalTime < best.totalTime {
                        best = run
                    }
                }
            }
        case .sensor:
            let plans = [RobotPlan(bayLaps: all, shortcutLaps: all),
                         RobotPlan(bayLaps: [0], shortcutLaps: all),
                         RobotPlan(bayLaps: [0, 1], shortcutLaps: all)]
            for plan in plans {
                if let run = drive(track, plan: plan, laps: lapCount), run.gateHits == 0, run.totalTime < best.totalTime { best = run }
            }
        }
        return best
    }
}
