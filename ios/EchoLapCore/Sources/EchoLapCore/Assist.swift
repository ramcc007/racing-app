import Foundation

/// The smoothed line the robot and the assist follow. Drawn on the road as the guide, and driven by the gold rival.
public struct RacingLine: Sendable {
    /// Sideways offset from the centreline at every sample (+ = left of the driving direction).
    public let lateral: [Double]
    public let points: [Vec2]
    let step: Double
    let length: Double

    public init(track: Track) {
        let line = Routes.racingLine(track)
        points = line
        lateral = (0..<track.count).map { (line[$0] - track.points[$0]).dot(track.normal($0)) }
        step = track.step
        length = track.length
    }

    /// Where a car would be after racing this far from the line (negative during the run-up), and which way it faces.
    public func pose(atProgress progress: Double) -> (position: Vec2, heading: Double) {
        let n = points.count
        var s = progress.truncatingRemainder(dividingBy: length)
        if s < 0 { s += length }
        let f = s / step
        let i = Int(f) % n, j = (i + 1) % n
        let t = f - Double(Int(f))
        let a = points[i], b = points[j]
        return (a + (b - a) * t, (b - a).angle)
    }
}

/// Easy controls (the default). The car accelerates, brakes for corners and follows the racing line by itself, the way
/// the most played casual racers do it. The player moves left or right across the road (to slipstream an echo, dodge
/// one, or line up), steers into the parking bay or an open shortcut to take it, and boosts.
///
/// It cruises a little below top speed (the robot that sets the target times drives flat out), so finishing is easy
/// but gold needs the echo tools: a slipstream or a boost lifts the cruise speed, and the bay and shortcut save distance.
public final class AssistDriver {
    /// Share of the safe corner speed the assist uses (the robot uses 0.93).
    public static let defaultCornerPace = 0.88
    /// Share of top speed the assist cruises at on its own. Slipstreaming and boosting raise it with the car's own top speed.
    public static let defaultCruise = 0.85
    /// Seconds to cross the full width of the road while holding one side.
    public static let laneChangeSeconds = 0.8

    public let track: Track
    let spec: CarSpec
    let cornerPace: Double
    let cruise: Double
    /// Racing line as a sideways offset from the centreline at every sample (+ = left of the driving direction).
    let lineLateral: [Double]
    let lineRadii: [Double]
    private let bayRoute: Route?
    private let shortcutRoute: Route?
    /// The shortcut route's sample nearest the gate.
    private let gateRouteIndex: Int

    /// Where the player has moved across the road, relative to the racing line (+ = left of the driving direction).
    public private(set) var offset = 0.0
    public enum Mode: Equatable, Sendable { case line, bay, shortcut }
    public private(set) var mode = Mode.line
    private var routeIndex = 0
    private var wasDocked = false

    public init(track: Track, spec: CarSpec = Cars.pip, cornerPace: Double = AssistDriver.defaultCornerPace,
                cruise: Double = AssistDriver.defaultCruise) {
        self.track = track
        self.spec = spec
        self.cornerPace = cornerPace
        self.cruise = cruise
        let racing = RacingLine(track: track)
        let line = racing.points
        lineLateral = racing.lateral
        lineRadii = Geometry.radii(line)
        bayRoute = track.bays.first.map { Route(Routes.visitBay(line, bay: $0, track: track), step: track.step) }
        let sr = track.shortcut != nil ? Route(Routes.takeShortcut(line, track: track), step: track.step) : nil
        shortcutRoute = sr
        gateRouteIndex = (sr != nil && track.shortcut != nil) ? sr!.nearest(to: track.shortcut!.gateCenter, around: nil) : 0
    }

    /// How far either side of the centreline the car may be steered while staying fully on the road.
    public var laneLimit: Double { track.halfWidth - Physics.carWidth / 2 - 6 }

    /// Which side of the road (+1 left, -1 right) the bay is on, if the track has one.
    public var baySide: Double? {
        track.bays.first.map { bay in (bay.center - track.points[bay.index]).dot(track.normal(bay.index)) > 0 ? 1 : -1 }
    }

    /// Which side of the road (+1 left, -1 right) the shortcut leaves on, if the track has one.
    public var shortcutSide: Double? {
        track.shortcut.map { sc in sc.direction.dot(track.normal(sc.entryIndex)) > 0 ? 1 : -1 }
    }

    /// The player's chosen line at a sample, clamped to the road (for drawing the guide line).
    public func lateral(at index: Int) -> Double {
        clamp(lineLateral[track.wrap(index)] + offset, -laneLimit, laneLimit)
    }

    /// The controls for this tick. `steer` is the player's sideways intent: -1 (hold left) ... 1 (hold right).
    public func input(for race: Race, steer intent: Double, boost: Bool = false, swap: Bool = false) -> ControlInput {
        guard race.phase == .racing else { return ControlInput(throttle: true) }
        let car = race.car
        if car.docked {
            wasDocked = true
            return ControlInput(throttle: false, boost: boost)
        }
        let n = track.count
        let i = race.location.index
        if wasDocked {
            // Leaving the pad: carry on from where the car is, so it doesn't swerve.
            wasDocked = false
            mode = .line
            offset = race.location.lateral - lineLateral[i]
        }

        // Moving across the road. The chosen line stays on the road wherever the racing line goes.
        let rate = 2 * track.halfWidth / AssistDriver.laneChangeSeconds
        offset -= clamp(intent, -1, 1) * rate * Physics.dt
        offset = clamp(offset, -laneLimit - lineLateral[i], laneLimit - lineLateral[i])
        let chosen = lineLateral[i] + offset

        func ahead(_ target: Int) -> Int { ((target - i) % n + n) % n }
        // Forks: steering towards the bay or an open shortcut as they come up takes it.
        if mode == .line, let bay = track.bays.first, let side = baySide, bayRoute != nil {
            let d = ahead(bay.index)
            if Double(d) * track.step > 50, Double(d) * track.step < 250, chosen * side > track.halfWidth * 0.3 {
                mode = .bay
                routeIndex = bayRoute!.nearest(to: car.position, around: nil)
            }
        }
        if mode == .line, let sc = track.shortcut, let side = shortcutSide, shortcutRoute != nil, race.gateOpen {
            let d = ahead(sc.entryIndex)
            // Only if the gate will still be open when we get there.
            // Early enough to brake for the turn into the lane, and only if the gate will still be open when we get there.
            let toEntry = Double(d) * track.step
            if toEntry > 70, toEntry < 260, chosen * side > track.halfWidth * 0.3,
               race.gateOpenFor > secondsToGate(from: car.position, speed: car.forwardSpeed) + 0.6 {
                mode = .shortcut
                routeIndex = shortcutRoute!.nearest(to: car.position, around: nil)
            }
        }
        // Back to the road once past the bay or through the shortcut.
        if mode == .bay, let bay = track.bays.first {
            let d = ahead(bay.index)
            if d > n / 2 && n - d > 8 { leave(race) }
        }
        if mode == .shortcut, let sc = track.shortcut, (car.position - sc.b).dot(sc.direction) > 20 { leave(race) }

        let speed = max(0, car.forwardSpeed)
        let look = 38 + 0.26 * speed
        let brakeDistance = speed * speed / (2 * Physics.coast) + 60
        var target: Vec2
        var tightest = Double.infinity
        if mode == .line {
            let ti = (i + Int(look / track.step)) % n
            target = track.points[ti] + track.normal(ti) * lateral(at: ti)
            for k in 0...(Int(brakeDistance / track.step) + 1) { tightest = min(tightest, lineRadii[(i + k) % n]) }
        } else {
            let route = mode == .bay ? bayRoute! : shortcutRoute!
            routeIndex = route.nearest(to: car.position, around: routeIndex)
            target = route.points[(routeIndex + Int(look / route.step)) % route.count]
            for k in 0...(Int(brakeDistance / route.step) + 1) { tightest = min(tightest, route.radii[(routeIndex + k) % route.count]) }
        }
        let diff = wrapAngle((target - car.position).angle - car.heading)
        let steer = clamp(-diff * 2.8, -1, 1)
        var cap = spec.topSpeed * cruise
        if car.boostTime > 0 { cap *= Physics.boostTopSpeed }
        if race.drafting { cap *= Physics.draftTopSpeed / cruise }   // tucked in behind an echo: flat out
        let allowed = min(Physics.cornerSpeed(radius: tightest, spec: spec) * cornerPace, cap)

        // A gate that shut before we got through: give up the shortcut and rejoin the road (never wait at it, since
        // nothing may come to open it again this lap). Brake if it's right in front of us.
        if mode == .shortcut, let sc = track.shortcut, !race.gateOpen {
            let toGate = sc.gateCenter - car.position
            if toGate.dot(sc.direction) > 0 {
                leave(race)
                if toGate.length < brakeDistance { return ControlInput(throttle: false, steer: steer, swap: swap) }
            }
        }
        return ControlInput(throttle: speed < allowed, steer: steer, boost: boost, swap: swap)
    }

    /// Driving time from a point to the gate along the shortcut route: a speed profile that brakes for each corner in
    /// time and accelerates out of it, starting from the car's current speed.
    func secondsToGate(from p: Vec2, speed: Double) -> Double {
        guard let route = shortcutRoute else { return .infinity }
        let start = route.nearest(to: p, around: nil)
        let count = ((gateRouteIndex - start) % route.count + route.count) % route.count
        guard count > 0 else { return 0 }
        let cap = spec.topSpeed * cruise
        var v = (0..<count).map { k in max(90, min(cap, Physics.cornerSpeed(radius: route.radii[(start + k) % route.count], spec: spec) * cornerPace)) }
        for k in stride(from: count - 2, through: 0, by: -1) { v[k] = min(v[k], (v[k + 1] * v[k + 1] + 2 * Physics.coast * route.step).squareRoot()) }
        var now = max(0, speed), t = 0.0
        for k in 0..<count {
            let next = min(v[k], (now * now + 2 * spec.accel * route.step).squareRoot())
            t += route.step / max(30, (now + next) / 2)
            now = next
        }
        return t
    }

    private func leave(_ race: Race) {
        mode = .line
        let i = race.location.index
        offset = clamp(race.location.lateral, -laneLimit, laneLimit) - lineLateral[i]
    }
}
