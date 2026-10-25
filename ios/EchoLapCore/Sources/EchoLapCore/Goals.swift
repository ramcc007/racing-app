import Foundation

/// Three small goals a day, the same for everyone with the same unlocks. Each pays Sparks; all three pay a bonus.
public struct DailyGoal: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case finishRaces, earnStars, driftBoosts, nearMisses, draftSeconds, useBoosts, cleanRace, playDaily, climbRungs, earnMedal, swaps, echoGate, jumps
    }

    public let kind: Kind
    public let target: Int

    public var title: String {
        switch kind {
        case .finishRaces: return "Finish \(target) sprints"
        case .earnStars: return "Earn \(target) stars in career races"
        case .driftBoosts: return "Earn \(target) drift boosts"
        case .nearMisses: return "\(target) near misses"
        case .draftSeconds: return "Slipstream for \(target) seconds"
        case .useBoosts: return "Fire the nitro \(target) times"
        case .cleanRace: return "Finish a sprint with no bumps"
        case .playDaily: return "Finish the daily track"
        case .climbRungs: return "Climb \(target) echo ladder rungs"
        case .earnMedal: return "Earn an echo medal"
        case .swaps: return "Relay-swap \(target) times"
        case .echoGate: return "Pass a gate an echo holds open"
        case .jumps: return "Take \(target) jumps"
        }
    }

    /// How much one finished race adds to this goal.
    public func progress(from result: RaceResult, mode: RaceMode, stars: Int, medal: Bool, rungs: Int = 0) -> Int {
        let s = result.stats
        switch kind {
        case .finishRaces: return result.finished ? 1 : 0
        case .earnStars: return result.finished && mode == .career ? stars : 0
        case .driftBoosts: return s.driftBoosts
        case .nearMisses: return s.nearMisses
        case .draftSeconds: return Int(s.draftSeconds)
        case .useBoosts: return s.boosts
        case .cleanRace: return result.finished && s.bumps == 0 && mode != .survival && result.echoesOnRoad > 0 ? 1 : 0
        case .playDaily: return result.finished && mode == .daily ? 1 : 0
        case .climbRungs: return rungs
        case .earnMedal: return medal ? 1 : 0
        case .swaps: return s.swaps
        case .echoGate: return s.echoGatePasses
        case .jumps: return s.jumps
        }
    }
}

/// Today's goals and how far the player has got.
public struct GoalState: Codable, Equatable, Sendable {
    public var day: String
    public var goals: [DailyGoal]
    public var progress: [Int]
    public var claimed: [Bool]
    public var bonusClaimed: Bool

    public func isDone(_ i: Int) -> Bool { progress[i] >= goals[i].target }
    public var allDone: Bool { goals.indices.allSatisfy(isDone) }

    /// Picks three different goals for the day, only from rules the player has unlocked.
    public static func make(for day: DayKey, unlocked worlds: Set<World>) -> GoalState {
        var rng = SeededRandom(seed: stableHash("echolap.goals." + day.string))
        var pool: [DailyGoal] = [
            DailyGoal(kind: .finishRaces, target: 5),
            DailyGoal(kind: .earnStars, target: 6),
            DailyGoal(kind: .driftBoosts, target: 20),
            DailyGoal(kind: .draftSeconds, target: 12),
            DailyGoal(kind: .useBoosts, target: 8),
            DailyGoal(kind: .playDaily, target: 1),
            DailyGoal(kind: .climbRungs, target: 3),
            DailyGoal(kind: .earnMedal, target: 1),
        ]
        if worlds.contains(.canyon) {
            pool.append(DailyGoal(kind: .cleanRace, target: 1))
            pool.append(DailyGoal(kind: .nearMisses, target: 6))
        }
        if worlds.contains(.neon) { pool.append(DailyGoal(kind: .echoGate, target: 1)) }
        if worlds.contains(.jungle) { pool.append(DailyGoal(kind: .swaps, target: 3)) }
        if worlds.contains(.orbit) { pool.append(DailyGoal(kind: .jumps, target: 5)) }
        var picked: [DailyGoal] = []
        while picked.count < 3 && !pool.isEmpty {
            picked.append(pool.remove(at: rng.int(pool.count)))
        }
        return GoalState(day: day.string, goals: picked, progress: Array(repeating: 0, count: picked.count),
                         claimed: Array(repeating: false, count: picked.count), bonusClaimed: false)
    }
}
