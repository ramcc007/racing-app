import Foundation

/// Counters for one race. Medals, daily goals and achievements are all worked out from these.
public struct RaceStats: Codable, Equatable, Sendable {
    public var drafts = 0
    public var draftSeconds = 0.0
    public var bumps = 0
    public var softTouches = 0
    public var boosts = 0
    public var swaps = 0
    public var gatePasses = 0
    /// Passes through a gate or bridge that an echo opened.
    public var echoGatePasses = 0
    public var gateHits = 0
    public var iceBreaks = 0
    public var splashes = 0
    public var docks = 0
    public var jumps = 0
    public var distance = 0.0
    public var offroadSeconds = 0.0

    public init() {}
}

/// Things that happened during a tick, for sound, haptics and on-screen messages.
public enum RaceEvent: Equatable, Sendable {
    case countdown(Int)
    case go
    case lap(number: Int, time: Double)
    case finished
    case echoSpawned(lap: Int)
    case bump
    case lifeLost(remaining: Int)
    case softTouch
    case draftStart
    case boost
    case boostEmpty
    case gateOpened
    case gateClosed
    case gateHit
    case dock
    case undock
    case iceCrack(patch: Int, wear: Int)
    case iceBreak(patch: Int)
    case splash
    case swap
    case swapUnavailable
    case jump
    case land
}

/// One recorded lap, replayed in sync with the current lap.
public struct Echo: Sendable {
    /// Which lap it came from (1-based).
    public let lap: Int
    /// x, y, heading, flags (1 = docked, 2 = airborne) for every tick of that lap.
    let frames: [Float]
    /// An echo only turns solid once you have pulled clear of it (they all start together on the line).
    public internal(set) var solid = false
    var hint = 0
    var insidePatch: Int?
    var insideSensor = false

    public var frameCount: Int { frames.count / 4 }

    public func pose(at frame: Int) -> EchoPose? {
        guard frame >= 0, frame < frameCount else { return nil }
        let b = frame * 4
        let flags = Int(frames[b + 3])
        return EchoPose(position: Vec2(Double(frames[b]), Double(frames[b + 1])), heading: Double(frames[b + 2]),
                        docked: flags & 1 != 0, airborne: flags & 2 != 0)
    }

    /// The recorded path between two frames, for drawing the fading trail.
    public func trail(from start: Int, to end: Int, every stride: Int = 3) -> [Vec2] {
        let lo = max(0, start), hi = min(frameCount - 1, end)
        guard hi > lo else { return [] }
        return Swift.stride(from: lo, through: hi, by: max(1, stride)).map { f in
            Vec2(Double(frames[f * 4]), Double(frames[f * 4 + 1]))
        }
    }
}

public struct EchoPose: Equatable, Sendable {
    public let position: Vec2
    public let heading: Double
    public let docked: Bool
    public let airborne: Bool
}

/// The outcome of a race, saved into progress.
public struct RaceResult: Codable, Equatable, Sendable {
    public let trackID: String
    public let carID: String
    public let finished: Bool
    public let totalTime: Double
    public let lapTimes: [Double]
    public let lapsCompleted: Int
    public let stats: RaceStats

    public init(trackID: String, carID: String, finished: Bool, totalTime: Double, lapTimes: [Double], lapsCompleted: Int, stats: RaceStats) {
        self.trackID = trackID
        self.carID = carID
        self.finished = finished
        self.totalTime = totalTime
        self.lapTimes = lapTimes
        self.lapsCompleted = lapsCompleted
        self.stats = stats
    }
}

/// One race: countdown, laps, echoes and every rule. Call `tick` 120 times per second.
public final class Race {
    public enum Phase: Equatable, Sendable { case countdown, racing, finished }

    public let track: Track
    public let spec: CarSpec
    public let laps: Int
    /// Survival mode only: bumps left before the run ends.
    public private(set) var livesLeft: Int?

    public private(set) var phase: Phase = .countdown
    public private(set) var countdown = 3.0
    public private(set) var car: CarState
    /// Race clock since GO.
    public private(set) var time = 0.0
    public private(set) var lapStartTime = 0.0
    /// Ticks since the current lap started (echoes replay this frame).
    public private(set) var lapTick = 0
    /// Laps completed.
    public private(set) var lapsDone = 0
    public private(set) var lapTimes: [Double] = []
    public private(set) var echoes: [Echo] = []
    /// 0...1. One boost costs `boostCost`.
    public private(set) var boostCharge = 0.0
    public private(set) var stats = RaceStats()
    /// Passes recorded on each ice patch; at `iceBreakPasses` it is water.
    public private(set) var iceWear: [Int: Int] = [:]
    public private(set) var gateOpen = false
    public private(set) var drafting = false
    public private(set) var swapUsedThisLap = false
    public private(set) var progress = 0.0
    public private(set) var crossedStart = false
    public private(set) var checkpoints = [false, false, false]
    public private(set) var location: TrackLocation
    public private(set) var offroad = false
    /// Events since the caller last emptied this list.
    public var events: [RaceEvent] = []

    public static let boostCost = 0.34
    public static let draftGain = 0.40
    public static let iceBreakPasses = 3
    public static let sensorOpenSeconds = 5.0
    public static let gateGraceSeconds = 1.0
    public static let maxEchoes = 16
    public static let swapReach = 420.0
    /// The car starts this far behind the line. The clock starts when it crosses the line at speed.
    public static let runUp = 180.0

    private var recording: [Float] = []
    private var gateGrace = 0.0
    private var sensorOpenUntil = -1.0
    private var holderIsEcho = false
    private var sinceDraft = 10.0
    private var carInsidePatch: Int?
    private var carInsideSensor = false
    private var touchingSoft = false
    private var wasAirborne = false
    private let startIndex: Int
    private let checkpointS: [Double]

    public init(track: Track, spec: CarSpec, laps: Int? = nil, lives: Int? = nil) {
        self.track = track
        self.spec = spec
        self.laps = laps ?? track.def.laps
        self.livesLeft = lives
        startIndex = track.wrap(track.count - Int(Race.runUp / track.step))
        car = CarState(position: track.points[startIndex], heading: track.tangents[startIndex].angle)
        location = track.locate(track.points[startIndex], hint: startIndex)
        progress = track.s(startIndex)
        checkpointS = [0.25, 0.5, 0.75].map { $0 * track.length }
        recording.reserveCapacity(4 * 120 * 40)
    }

    public var isFinished: Bool { phase == .finished }
    /// 1-based lap currently being driven.
    public var currentLap: Int { laps == Int.max ? lapsDone + 1 : min(lapsDone + 1, laps) }
    /// Time into the current lap.
    public var lapTime: Double { time - lapStartTime }
    /// Distance raced since the line, comparable with the robot's pace curve (negative during the run-up).
    public var totalProgress: Double { Double(lapsDone) * track.length + (crossedStart ? progress : progress - track.length) }
    /// True during the untimed run-up to the line.
    public var isRunUp: Bool { phase == .racing && !crossedStart }

    /// How much longer the shortcut gate will stay open as things stand (0 when shut). A parked echo leaves at a known
    /// moment and a sensor bridge closes on a timer, so the easy-controls assist can tell whether it will get through.
    public var gateOpenFor: Double {
        guard let sc = track.shortcut, gateOpen else { return 0 }
        switch sc.trigger {
        case .sensor:
            return max(0, sensorOpenUntil - time)
        case .pad:
            if car.docked { return .infinity }
            let frame = lapTick - 1
            var longest: Double?
            for echo in echoes {
                guard let p = echo.pose(at: frame), p.docked else { continue }
                var f = frame
                while let q = echo.pose(at: f + 1), q.docked { f += 1 }
                longest = max(longest ?? 0, Double(f - frame) * Physics.dt)
            }
            return longest.map { $0 + Race.gateGraceSeconds } ?? gateGrace
        }
    }

    /// Adds boost charge (the tutorial uses it so the boost lesson always happens).
    public func addBoost(_ amount: Double) {
        boostCharge = min(1, boostCharge + max(0, amount))
    }

    /// Where each echo is right now (nil once it has finished its lap).
    public func echoPoses() -> [EchoPose?] { echoes.map { $0.pose(at: lapTick - 1) } }

    public func result() -> RaceResult {
        RaceResult(trackID: track.def.id, carID: spec.id, finished: phase == .finished && (livesLeft == nil ? lapsDone >= laps : true),
                   totalTime: time, lapTimes: lapTimes, lapsCompleted: lapsDone, stats: stats)
    }

    // MARK: - Tick

    public func tick(_ input: ControlInput) {
        switch phase {
        case .finished:
            return
        case .countdown:
            let before = Int(countdown.rounded(.up))
            if countdown == 3.0 { events.append(.countdown(3)) }
            countdown -= Physics.dt
            let after = Int(countdown.rounded(.up))
            if after < before && after > 0 { events.append(.countdown(after)) }
            if countdown <= 1e-9 {
                countdown = 0
                phase = .racing
                events.append(.go)
            }
            return
        case .racing:
            break
        }

        // The clock and the echo recording start when the car first crosses the line (a flying start), so every echo
        // replays a flying lap and races in step with you.
        if crossedStart {
            time += Physics.dt
            lapTick += 1
        }
        let frame = lapTick - 1
        let poses = echoes.map { $0.pose(at: frame) }
        let prevPos = car.position

        // Controls that act instantly.
        if input.boost {
            if car.docked {
                car.docked = false
                car.velocity = car.forward * 140
                car.undockCooldown = 1.2
                events.append(.undock)
            } else if boostCharge >= Race.boostCost - 1e-9 {
                boostCharge -= Race.boostCost
                car.boostTime = Physics.boostDuration
                stats.boosts += 1
                events.append(.boost)
            } else {
                events.append(.boostEmpty)
            }
        }
        if input.swap { trySwap(poses: poses, frame: frame) }

        // Slipstream and wind shelter, from where everything is before moving.
        var env = Physics.Environment()
        env.surface = car.surface
        var shelter = false
        drafting = false
        let fwd = car.forward
        for pose in poses {
            guard let p = pose, !p.docked, !p.airborne, !car.isAirborne else { continue }
            let eFwd = Vec2.fromAngle(p.heading)
            let d = car.position - p.position
            let along = -d.dot(eFwd)
            let side = abs(d.dot(eFwd.perp))
            if along > 0.3 * Physics.carLength, along < 3.2 * Physics.carLength, side < 1.2 * Physics.carWidth { shelter = true }
            if along > 0.6 * Physics.carLength, along < 2.8 * Physics.carLength, side < 0.9 * Physics.carWidth,
               fwd.dot(eFwd) > 0.85, car.forwardSpeed > 120 {
                drafting = true
            }
        }
        if drafting {
            boostCharge = min(1, boostCharge + Race.draftGain * spec.draft * Physics.dt)
            stats.draftSeconds += Physics.dt
            if sinceDraft > 0.5 {
                stats.drafts += 1
                events.append(.draftStart)
            }
            sinceDraft = 0
        } else {
            sinceDraft += Physics.dt
        }
        env.drafting = drafting
        env.wind = track.wind(at: location.index) * (shelter ? 0.25 : 1)

        Physics.step(&car, input: input, spec: spec, env: env)
        stats.distance += car.position.distance(to: prevPos)
        if wasAirborne && !car.isAirborne { events.append(.land) }
        wasAirborne = car.isAirborne

        updateSurroundings(prevPos: prevPos)
        updateEchoes(poses: poses)
        updateGate()

        if crossedStart {
            recording.append(Float(car.position.x))
            recording.append(Float(car.position.y))
            recording.append(Float(car.heading))
            recording.append(Float((car.docked ? 1 : 0) | (car.isAirborne ? 2 : 0)))
        }

        updateProgress()
    }

    // MARK: - Surroundings: road, patches, walls, gate, bays, ramps

    private func updateSurroundings(prevPos: Vec2) {
        let loc = track.locate(car.position, hint: location.index)
        location = loc
        let hw = track.halfWidth
        var onLane = false
        if let sc = track.shortcut {
            let (d, t) = Geometry.segmentDistance(car.position, sc.a, sc.b)
            onLane = d <= sc.halfWidth + 2 && t > 0 && t < 1
        }
        let onBay = track.bays.contains { car.position.distance(to: $0.center) <= $0.radius + 8 }
        let onRoad = loc.distance <= hw + 2
        offroad = !(onRoad || onLane || onBay)
        if offroad && !car.isAirborne { stats.offroadSeconds += Physics.dt }

        // Soft outer wall: you can run wide, but not wander off into the scenery.
        if !onLane && !onBay && loc.distance > hw + 120 {
            let n = (car.position - track.points[loc.index]).normalized
            car.position = track.points[loc.index] + n * (hw + 120)
            let out = car.velocity.dot(n)
            if out > 0 { car.velocity -= n * out }
            car.velocity = car.velocity * 0.98
            // Pinned nose-first against the wall a car can't steer (no speed, no turning): swing it round to face
            // along the road so it can always drive on.
            if car.forward.dot(n) > 0.2 {
                let want = track.tangents[loc.index].angle
                let diff = wrapAngle(want - car.heading)
                car.heading += max(-2.5 * Physics.dt, min(2.5 * Physics.dt, diff))
            }
        }

        // Surface and thin ice. Ice wears when a car leaves it; driving onto broken ice is a splash.
        let patch = car.isAirborne ? nil : track.patch(at: loc)
        let inside = patch?.id
        if inside != carInsidePatch {
            if let left = carInsidePatch { wear(patch: left) }
            if let p = patch, p.kind == .ice, (iceWear[p.id] ?? 0) >= Race.iceBreakPasses { splash() }
            carInsidePatch = inside
        }
        if car.isAirborne {
            car.surface = .asphalt
        } else if offroad {
            car.surface = .grass
        } else if let p = patch {
            car.surface = p.kind == .sand ? .sand : ((iceWear[p.id] ?? 0) >= Race.iceBreakPasses ? .water : .ice)
        } else {
            car.surface = .asphalt
        }

        // The gate (or bridge) blocks the shortcut while closed.
        if let sc = track.shortcut, !car.isAirborne {
            let dir = sc.direction
            let u0 = (prevPos - sc.gateCenter).dot(dir), u1 = (car.position - sc.gateCenter).dot(dir)
            let w = abs((car.position - sc.gateCenter).dot(dir.perp))
            let crossed = (u0 < 0) != (u1 < 0)
            if w <= sc.halfWidth + 4 && (crossed || abs(u1) < 10) {
                if !gateOpen {
                    let back: Double = u0 < 0 ? -1 : 1
                    car.position = sc.gateCenter + dir * (back * 14) + dir.perp * (car.position - sc.gateCenter).dot(dir.perp)
                    car.velocity = car.velocity * -0.25
                    car.boostTime = 0
                    stats.gateHits += 1
                    events.append(.gateHit)
                } else if crossed && u1 > u0 {
                    stats.gatePasses += 1
                    if holderIsEcho { stats.echoGatePasses += 1 }
                }
            }
        }

        // Bays: park on the pad; drive through the sensor.
        if let pad = track.pad, !car.docked, !car.isAirborne, car.undockCooldown <= 0,
           car.position.distance(to: pad.center) < pad.radius * 0.8 {
            car.docked = true
            car.position = pad.center
            car.heading = track.tangents[pad.index].angle
            car.velocity = .zero
            car.boostTime = 0
            stats.docks += 1
            events.append(.dock)
        }
        if let sensor = track.sensor {
            let inside = car.position.distance(to: sensor.center) < sensor.radius
            if inside && !carInsideSensor {
                sensorOpenUntil = time + Race.sensorOpenSeconds
                holderIsEcho = false
            }
            carInsideSensor = inside
        }

        // Ramps: launch if crossed forwards at speed.
        for jump in track.jumps where !car.isAirborne {
            let u0 = (prevPos - jump.center).dot(jump.direction), u1 = (car.position - jump.center).dot(jump.direction)
            let side = abs((car.position - jump.center).dot(jump.direction.perp))
            if u0 < 0, u1 >= 0, side <= hw + 4, car.forwardSpeed > 150 {
                car.airTime = 0.25 + car.forwardSpeed / 520
                stats.jumps += 1
                events.append(.jump)
            }
        }
    }

    private func wear(patch id: Int) {
        guard let p = track.patches.first(where: { $0.id == id }), p.kind == .ice else { return }
        let before = iceWear[id] ?? 0
        guard before < Race.iceBreakPasses else { return }
        iceWear[id] = before + 1
        events.append(.iceCrack(patch: id, wear: before + 1))
        if before + 1 >= Race.iceBreakPasses {
            stats.iceBreaks += 1
            events.append(.iceBreak(patch: id))
        }
    }

    private func splash() {
        car.spinTime = 1.0
        car.spinRate = 6
        car.velocity = car.velocity * 0.3
        car.immuneTime = 1.5
        car.boostTime = 0
        stats.splashes += 1
        events.append(.splash)
    }

    // MARK: - Echoes

    private func updateEchoes(poses: [EchoPose?]) {
        let needsLocation = !track.patches.isEmpty || track.sensor != nil
        var padHeldByEcho = false
        var touchedSoftNow = false
        for i in echoes.indices {
            guard let p = poses[i] else { continue }
            if !echoes[i].solid, car.position.distance(to: p.position) > Physics.carLength * 1.3 { echoes[i].solid = true }
            if p.docked { padHeldByEcho = true }

            if !car.docked, !car.isAirborne, !p.airborne,
               Physics.touching(car.position, car.heading, p.position, p.heading) {
                if track.def.softEchoes {
                    car.velocity = car.velocity * (1 - 1.8 * Physics.dt)
                    touchedSoftNow = true
                } else if echoes[i].solid && car.immuneTime <= 0 {
                    bump(from: p)
                    if phase == .finished { return }
                }
            }

            guard needsLocation, !p.airborne else { continue }
            let loc = track.locate(p.position, hint: echoes[i].hint)
            echoes[i].hint = loc.index
            let inside = track.patch(at: loc)?.id
            if inside != echoes[i].insidePatch {
                if let left = echoes[i].insidePatch { wear(patch: left) }
                echoes[i].insidePatch = inside
            }
            if let sensor = track.sensor {
                let inSensor = p.position.distance(to: sensor.center) < sensor.radius
                if inSensor && !echoes[i].insideSensor {
                    sensorOpenUntil = time + Race.sensorOpenSeconds
                    holderIsEcho = true
                }
                echoes[i].insideSensor = inSensor
            }
        }
        if touchedSoftNow && !touchingSoft {
            stats.softTouches += 1
            events.append(.softTouch)
        }
        touchingSoft = touchedSoftNow

        // Pad gate: open while any car is parked in the bay, plus a short grace.
        if track.shortcut?.trigger == .pad {
            if car.docked || padHeldByEcho {
                gateGrace = Race.gateGraceSeconds
                holderIsEcho = padHeldByEcho
            } else {
                gateGrace = max(0, gateGrace - Physics.dt)
            }
        }
    }

    private func bump(from p: EchoPose) {
        let penalty = (livesLeft != nil ? 0.7 : track.difficulty.bumpPenalty) * spec.bumpFactor
        let away = car.position - p.position
        let side = away.dot(Vec2.fromAngle(p.heading).perp)
        car.spinTime = penalty
        car.spinRate = side >= 0 ? 9 : -9
        car.velocity = car.velocity * 0.45
        car.immuneTime = penalty + 0.8
        car.boostTime = 0
        car.position += away.normalized * 6
        stats.bumps += 1
        events.append(.bump)
        if let lives = livesLeft {
            livesLeft = lives - 1
            events.append(.lifeLost(remaining: lives - 1))
            if lives - 1 <= 0 {
                phase = .finished
                events.append(.finished)
            }
        }
    }

    private func trySwap(poses: [EchoPose?], frame: Int) {
        guard track.def.features.contains(.relay), !swapUsedThisLap, !car.docked, !car.isAirborne, crossedStart else {
            events.append(.swapUnavailable)
            return
        }
        var best: (index: Int, ahead: Double)?
        for (i, pose) in poses.enumerated() {
            guard let p = pose, !p.docked, !p.airborne else { continue }
            let loc = track.locate(p.position, hint: echoes[i].hint)
            let s = track.s(loc.index)
            let ahead = s - progress
            guard ahead > Physics.carLength, ahead <= Race.swapReach, s < track.length - 40 else { continue }
            if best == nil || ahead < best!.ahead { best = (i, ahead) }
        }
        guard let pick = best, let p = poses[pick.index] else {
            events.append(.swapUnavailable)
            return
        }
        let before = echoes[pick.index].pose(at: max(0, frame - 1))?.position ?? p.position
        car.position = p.position
        car.heading = p.heading
        car.velocity = (p.position - before) / Physics.dt
        car.spinTime = 0
        car.immuneTime = 1.0
        echoes[pick.index].solid = false
        swapUsedThisLap = true
        stats.swaps += 1
        events.append(.swap)
    }

    private func updateGate() {
        guard let sc = track.shortcut else { return }
        let open: Bool
        switch sc.trigger {
        case .pad: open = gateGrace > 0
        case .sensor: open = time < sensorOpenUntil
        }
        if open != gateOpen {
            gateOpen = open
            events.append(open ? .gateOpened : .gateClosed)
        }
    }

    // MARK: - Test hooks (internal: used by the unit tests to set up exact situations)

    /// Skips the countdown and the run-up: the clock is running and the car is at `index` with `speed`.
    func testingStart(at index: Int = 0, speed: Double = 0, lateral: Double = 0) {
        phase = .racing
        countdown = 0
        crossedStart = true
        let i = track.wrap(index)
        car = CarState(position: track.points[i] + track.normal(i) * lateral, heading: track.tangents[i].angle)
        car.velocity = track.tangents[i] * speed
        location = track.locate(car.position, hint: i)
        progress = track.s(i)
        events.removeAll()
    }

    func testingInsertEcho(_ echo: Echo) { echoes.append(echo) }

    func testingSetCar(_ change: (inout CarState) -> Void) { change(&car) }

    func testingSetBoost(_ value: Double) { boostCharge = value }

    func testingMarkCheckpoints() { checkpoints = [true, true, true] }

    // MARK: - Laps

    private func updateProgress() {
        var s = track.s(location.index)
        if let sc = track.shortcut, abs(location.lateral) > track.halfWidth * 0.85 {
            let (d, t) = Geometry.segmentDistance(car.position, sc.a, sc.b)
            if d <= sc.halfWidth + 2 && t > 0 && t < 1 {
                s = track.s(sc.entryIndex) + t * (track.s(sc.exitIndex) - track.s(sc.entryIndex))
            }
        }
        let length = track.length
        let prev = progress
        for k in checkpoints.indices where !checkpoints[k] {
            if prev < checkpointS[k], s >= checkpointS[k], s - prev < length * 0.5 { checkpoints[k] = true }
        }
        progress = s
        if prev > 0.7 * length && s < 0.3 * length {
            if !crossedStart {
                crossedStart = true
            } else if checkpoints.allSatisfy({ $0 }) {
                completeLap()
            }
        }
    }

    private func completeLap() {
        let lapTime = time - lapStartTime
        lapTimes.append(lapTime)
        lapsDone += 1
        events.append(.lap(number: lapsDone, time: lapTime))
        checkpoints = [false, false, false]
        swapUsedThisLap = false
        if lapsDone >= laps {
            phase = .finished
            events.append(.finished)
            return
        }
        echoes.append(Echo(lap: lapsDone, frames: recording, hint: startIndex))
        if echoes.count > Race.maxEchoes { echoes.removeFirst() }
        events.append(.echoSpawned(lap: lapsDone))
        recording.removeAll(keepingCapacity: true)
        lapStartTime = time
        lapTick = 0
        for i in echoes.indices {
            echoes[i].solid = false
            echoes[i].insidePatch = nil
            echoes[i].insideSensor = false
            echoes[i].hint = startIndex
        }
    }
}
