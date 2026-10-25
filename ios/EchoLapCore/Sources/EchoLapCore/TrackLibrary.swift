import Foundation

/// Gold and silver times for a track, plus the robot's pace curve for the live "vs gold" delta.
public struct Targets: Codable, Equatable, Sendable {
    public let robotTime: Double
    public let gold: Double
    public let silver: Double
    public let robotLapTimes: [Double]
    public let plan: RobotPlan
    let paceTime: [Double]
    let paceProgress: [Double]

    /// The time at which the gold pace reaches a given distance raced.
    public func goldPaceTime(atProgress p: Double, goldSlack: Double) -> Double? {
        guard let first = paceProgress.first, p >= first, !paceProgress.isEmpty else { return nil }
        var lo = 0, hi = paceProgress.count - 1
        if p >= paceProgress[hi] { return paceTime[hi] * (1 + goldSlack) }
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if paceProgress[mid] <= p { lo = mid } else { hi = mid }
        }
        let span = paceProgress[hi] - paceProgress[lo]
        let t = span > 1e-9 ? (p - paceProgress[lo]) / span : 0
        return lerp(paceTime[lo], paceTime[hi], t) * (1 + goldSlack)
    }

    /// How far the gold pace has raced at a race time (the inverse of `goldPaceTime`), for the gold rival car.
    /// Nil before the gold pace has started.
    public func goldProgress(atTime t: Double, goldSlack: Double) -> Double? {
        guard let first = paceTime.first, let last = paceTime.last else { return nil }
        let k = 1 + goldSlack
        if t < first * k { return nil }
        if t >= last * k { return paceProgress[paceProgress.count - 1] }
        var lo = 0, hi = paceTime.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if paceTime[mid] * k <= t { lo = mid } else { hi = mid }
        }
        let span = (paceTime[hi] - paceTime[lo]) * k
        let f = span > 1e-9 ? (t - paceTime[lo] * k) / span : 0
        return lerp(paceProgress[lo], paceProgress[hi], f)
    }

    /// Stars for a finishing time: 1 for finishing, 2 for silver, 3 for gold.
    public func stars(for time: Double) -> Int {
        time <= gold + 1e-9 ? 3 : (time <= silver + 1e-9 ? 2 : 1)
    }
}

/// A generated track that the robot has finished, ready to race.
public struct BuiltTrack: Sendable {
    public let track: Track
    public let targets: Targets
}

/// Builds tracks on demand and keeps them. Generation is deterministic: attempt 0, 1, 2... in order until one passes
/// every rule and the robot finishes it, so every device ends up with exactly the same track and targets.
public final class TrackLibrary: @unchecked Sendable {
    public static let shared = TrackLibrary()
    public static let maxAttempts = 600

    private var cache: [String: BuiltTrack] = [:]
    private let lock = NSLock()

    public init() {}

    public func build(_ def: TrackDef) -> BuiltTrack {
        lock.lock()
        if let hit = cache[def.id] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let built = Self.make(def)
        lock.lock()
        cache[def.id] = built
        lock.unlock()
        return built
    }

    public func isBuilt(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache[id] != nil
    }

    /// Robot laps used to validate and time a track (Survival has no lap limit, so three laps prove it).
    static func robotLaps(_ def: TrackDef) -> Int { def.mode == .survival ? 3 : def.laps }

    static func make(_ def: TrackDef) -> BuiltTrack {
        var fallback: Track?
        for attempt in 0..<maxAttempts {
            guard let track = TrackGenerator.generate(def, attempt: attempt) else { continue }
            if fallback == nil { fallback = track }
            guard let run = Robot.bestRun(track, laps: robotLaps(def)) else { continue }
            return BuiltTrack(track: track, targets: targets(for: track, run: run))
        }
        // Not reached in practice (every catalog track is tested), but never leave the player without a track:
        // drop the feature rules and use a plain loop.
        let plain = TrackDef(id: def.id, world: def.world, slot: def.slot, index: max(1, def.index / 2), kind: .breather,
                             laps: def.laps, seed: def.seed, name: def.name, features: [], mode: def.mode)
        for attempt in 0..<maxAttempts {
            if let track = TrackGenerator.generate(plain, attempt: attempt), let run = Robot.bestRun(track, laps: robotLaps(def)) {
                return BuiltTrack(track: track, targets: targets(for: track, run: run))
            }
        }
        fatalError("No track could be generated for \(def.id)")
    }

    static func targets(for track: Track, run: RobotResult) -> Targets {
        let d = track.difficulty
        func round2(_ x: Double) -> Double { (x * 100).rounded(.up) / 100 }
        return Targets(robotTime: run.totalTime, gold: round2(run.totalTime * (1 + d.goldSlack)),
                       silver: round2(run.totalTime * (1 + d.silverSlack)), robotLapTimes: run.lapTimes, plan: run.plan,
                       paceTime: run.paceTime, paceProgress: run.paceProgress)
    }
}
