import Foundation

/// Best result on one track.
public struct TrackRecord: Codable, Equatable, Sendable {
    public var bestTime: Double
    public var stars: Int
    public var medal: Bool
    public var bestLapTimes: [Double]
    public var plays: Int

    public init(bestTime: Double, stars: Int, medal: Bool, bestLapTimes: [Double], plays: Int) {
        self.bestTime = bestTime
        self.stars = stars
        self.medal = medal
        self.bestLapTimes = bestLapTimes
        self.plays = plays
    }
}

public struct DailyRecord: Codable, Equatable, Sendable {
    public var bestTime: Double
    public var plays: Int
}

public struct WeeklyRecord: Codable, Equatable, Sendable {
    public var bestTotal: Double?
    public var plays: Int
}

/// Lifetime counters (for achievements and the stats screen).
public struct LifetimeStats: Codable, Equatable, Sendable {
    public var races = 0
    public var finishes = 0
    public var laps = 0
    public var drafts = 0
    public var boosts = 0
    public var bumps = 0
    public var swaps = 0
    public var echoGatePasses = 0
    public var iceBreaks = 0
    public var splashes = 0
    public var jumps = 0
    public var distance = 0.0
    public var golds = 0

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        races = (try? c.decodeIfPresent(Int.self, forKey: .races)) ?? 0
        finishes = (try? c.decodeIfPresent(Int.self, forKey: .finishes)) ?? 0
        laps = (try? c.decodeIfPresent(Int.self, forKey: .laps)) ?? 0
        drafts = (try? c.decodeIfPresent(Int.self, forKey: .drafts)) ?? 0
        boosts = (try? c.decodeIfPresent(Int.self, forKey: .boosts)) ?? 0
        bumps = (try? c.decodeIfPresent(Int.self, forKey: .bumps)) ?? 0
        swaps = (try? c.decodeIfPresent(Int.self, forKey: .swaps)) ?? 0
        echoGatePasses = (try? c.decodeIfPresent(Int.self, forKey: .echoGatePasses)) ?? 0
        iceBreaks = (try? c.decodeIfPresent(Int.self, forKey: .iceBreaks)) ?? 0
        splashes = (try? c.decodeIfPresent(Int.self, forKey: .splashes)) ?? 0
        jumps = (try? c.decodeIfPresent(Int.self, forKey: .jumps)) ?? 0
        distance = (try? c.decodeIfPresent(Double.self, forKey: .distance)) ?? 0
        golds = (try? c.decodeIfPresent(Int.self, forKey: .golds)) ?? 0
    }
}

/// Player choices. Stored with progress so they survive reinstalls via the same save.
public struct GameSettings: Codable, Equatable, Sendable {
    public enum Camera: String, Codable, CaseIterable, Sendable { case follow, fixed }
    /// Easy: the car drives and steers itself; hold a side of the screen to move across the road (AssistDriver).
    /// Pro: hold to drive, slide to steer.
    public enum Controls: String, Codable, CaseIterable, Sendable { case easy, pro }
    public var controls: Controls = .easy
    /// Show the glowing guide line and direction arrows on the road.
    public var showGuide = true
    public var sound = true
    public var haptics = true
    /// Thumb distance for full steering lock is divided by this (0.6 = gentle, 1.6 = twitchy).
    public var steeringSensitivity = 1.0
    /// Follow: the track turns so you always drive up the screen. Fixed: north stays up (easier for motion sickness).
    public var camera: Camera = .follow
    public var boostButtonOnLeft = false
    public var showGhost = true
    public var showHints = true
    /// Extra calm mode on top of the system Reduce Motion setting: no camera shake, no speed lines.
    public var calmEffects = false
    public var tiltSteering = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        controls = (try? c.decodeIfPresent(Controls.self, forKey: .controls)) ?? .easy
        showGuide = (try? c.decodeIfPresent(Bool.self, forKey: .showGuide)) ?? true
        sound = (try? c.decodeIfPresent(Bool.self, forKey: .sound)) ?? true
        haptics = (try? c.decodeIfPresent(Bool.self, forKey: .haptics)) ?? true
        steeringSensitivity = clamp((try? c.decodeIfPresent(Double.self, forKey: .steeringSensitivity)) ?? 1, 0.6, 1.6)
        camera = (try? c.decodeIfPresent(Camera.self, forKey: .camera)) ?? .follow
        boostButtonOnLeft = (try? c.decodeIfPresent(Bool.self, forKey: .boostButtonOnLeft)) ?? false
        showGhost = (try? c.decodeIfPresent(Bool.self, forKey: .showGhost)) ?? true
        showHints = (try? c.decodeIfPresent(Bool.self, forKey: .showHints)) ?? true
        calmEffects = (try? c.decodeIfPresent(Bool.self, forKey: .calmEffects)) ?? false
        tiltSteering = (try? c.decodeIfPresent(Bool.self, forKey: .tiltSteering)) ?? false
    }
}

/// One line on the results screen's reward list.
public struct RewardLine: Equatable, Sendable {
    public let title: String
    public let sparks: Int
}

/// Everything a finished race changed, for the results screen.
public struct RewardSummary: Equatable, Sendable {
    public var stars = 0
    public var previousStars = 0
    public var newBest = false
    public var previousBest: Double?
    public var medalEarned = false
    public var medalIsNew = false
    public var lines: [RewardLine] = []
    public var xpGained = 0
    public var levelBefore = 1
    public var levelAfter = 1
    public var unlockedWorlds: [World] = []
    public var unlockedCars: [CarSpec] = []
    public var unlockedTrack: TrackDef?
    public var survivalUnlocked = false
    public var weeklyUnlocked = false
    public var newAchievements: [Achievement] = []
    public var goalsCompleted: [DailyGoal] = []
    public var dailyStreak = 0

    public var totalSparks: Int { lines.reduce(0) { $0 + $1.sparks } }
    public var leveledUp: Bool { levelAfter > levelBefore }

    public init() {}
}

/// Everything the player has done, saved after every change.
/// Decoding never fails on missing or unknown fields, so saves from older and newer versions always load.
public struct PlayerProgress: Codable, Equatable, Sendable {
    public var schema = 1
    public var introSeen = false
    public var tutorialDone = false
    /// World rule cards the player has dismissed.
    public var seenRules: Set<Int> = []
    public var tracks: [String: TrackRecord] = [:]
    public var sparks = 0
    public var sparksEarnedTotal = 0
    public var xp = 0
    public var owned: Set<String> = Cosmetics.freeIDs
    public var selectedCar = "pip"
    /// Paint per racer id.
    public var paints: [String: String] = [:]
    public var trail = "trail.classic"
    public var finishCelebration = "finish.confetti"
    public var daily: [String: DailyRecord] = [:]
    public var dailyStreak = 0
    public var bestDailyStreak = 0
    public var lastDailyDay: String?
    public var goals: GoalState?
    public var weekly: [String: WeeklyRecord] = [:]
    public var survivalBest = 0
    public var survivalRuns = 0
    public var stats = LifetimeStats()
    public var achievements: Set<String> = []
    public var settings = GameSettings()
    public var lastTrackID: String?

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        schema = get(.schema, 1)
        introSeen = get(.introSeen, false)
        tutorialDone = get(.tutorialDone, false)
        seenRules = get(.seenRules, [])
        tracks = get(.tracks, [:])
        sparks = max(0, get(.sparks, 0))
        sparksEarnedTotal = max(0, get(.sparksEarnedTotal, 0))
        xp = max(0, get(.xp, 0))
        owned = get(.owned, Cosmetics.freeIDs).union(Cosmetics.freeIDs)
        selectedCar = get(.selectedCar, "pip")
        paints = get(.paints, [:])
        trail = get(.trail, "trail.classic")
        finishCelebration = get(.finishCelebration, "finish.confetti")
        daily = get(.daily, [:])
        dailyStreak = get(.dailyStreak, 0)
        bestDailyStreak = get(.bestDailyStreak, 0)
        lastDailyDay = get(.lastDailyDay, nil as String?)
        goals = get(.goals, nil as GoalState?)
        weekly = get(.weekly, [:])
        survivalBest = get(.survivalBest, 0)
        survivalRuns = get(.survivalRuns, 0)
        stats = get(.stats, LifetimeStats())
        achievements = get(.achievements, [])
        settings = get(.settings, GameSettings())
        lastTrackID = get(.lastTrackID, nil as String?)
        if Cars.all.first(where: { $0.id == selectedCar }) == nil { selectedCar = "pip" }
    }

    // MARK: - Derived

    public var totalStars: Int { tracks.reduce(0) { $0 + (Catalog.track(id: $1.key) != nil ? $1.value.stars : 0) } }
    public var medalCount: Int { tracks.reduce(0) { $0 + (Catalog.track(id: $1.key) != nil && $1.value.medal ? 1 : 0) } }
    public var level: Int { Economy.level(forXP: xp) }

    public func stars(in world: World) -> Int {
        Catalog.tracks(in: world).reduce(0) { $0 + (tracks[$1.id]?.stars ?? 0) }
    }

    public func isUnlocked(_ world: World) -> Bool { totalStars >= world.starsToUnlock }

    public var unlockedWorlds: Set<World> { Set(World.allCases.filter(isUnlocked)) }

    /// A career track is open when its world is open and the track before it (in the same world) is finished.
    public func isUnlocked(_ def: TrackDef) -> Bool {
        guard def.mode == .career else { return true }
        guard isUnlocked(def.world) else { return false }
        if def.slot == 1 { return true }
        return tracks["\(def.world.rawValue)-\(def.slot - 1)"] != nil
    }

    public func isUnlocked(_ car: CarSpec) -> Bool { totalStars >= car.starsToUnlock }

    public var survivalUnlocked: Bool { tracks[Catalog.survivalUnlockTrack] != nil }
    public var weeklyUnlocked: Bool { totalStars >= Catalog.weeklyUnlockStars }

    /// The track the "Continue" button opens: the first open track not yet finished, else the first open track below
    /// three stars, else the last one.
    public var nextTrack: TrackDef {
        let open = Catalog.career.filter(isUnlocked)
        if let fresh = open.first(where: { tracks[$0.id] == nil }) { return fresh }
        if let improvable = open.first(where: { (tracks[$0.id]?.stars ?? 0) < 3 }) { return improvable }
        return open.last ?? Catalog.career[0]
    }

    public func paint(for car: CarSpec) -> String { paints[car.id] ?? "paint.factory" }

    // MARK: - Spending

    public enum PurchaseError: Error, Equatable { case alreadyOwned, notEnoughSparks, unknown }

    /// Buys a cosmetic with Sparks. Returns nil on success, or why it couldn't be bought.
    @discardableResult
    public mutating func buy(_ id: String) -> PurchaseError? {
        guard let item = Cosmetics.item(id) else { return .unknown }
        guard !owned.contains(id) else { return .alreadyOwned }
        guard sparks >= item.price else { return .notEnoughSparks }
        sparks -= item.price
        owned.insert(id)
        return nil
    }

    /// Puts on an owned paint, trail or celebration.
    public mutating func equip(_ id: String, car: CarSpec? = nil) {
        guard owned.contains(id), let item = Cosmetics.item(id) else { return }
        switch item.kind {
        case .paint: paints[(car ?? Cars.car(id: selectedCar)).id] = id
        case .trail: trail = id
        case .finish: finishCelebration = id
        }
    }

    public mutating func select(_ car: CarSpec) {
        guard isUnlocked(car) else { return }
        selectedCar = car.id
    }

    // MARK: - Daily goals

    /// Today's goals, created on first look each day.
    public mutating func goals(for day: DayKey) -> GoalState {
        if let g = goals, g.day == day.string { return g }
        let fresh = GoalState.make(for: day, unlocked: unlockedWorlds)
        goals = fresh
        return fresh
    }

    // MARK: - Recording a race

    /// Saves a finished (or abandoned) race and works out every reward. `targets` is nil for Survival.
    public mutating func record(_ result: RaceResult, def: TrackDef, targets: Targets?, day: DayKey) -> RewardSummary {
        var summary = RewardSummary()
        let starsBefore = totalStars
        let worldsBefore = unlockedWorlds
        let carsBefore = Set(Cars.all.filter { isUnlocked($0) }.map(\.id))
        let survivalBefore = survivalUnlocked
        let weeklyBefore = weeklyUnlocked
        let achievementsBefore = achievements
        let levelBefore = level
        summary.levelBefore = levelBefore
        lastTrackID = def.mode == .career ? def.id : lastTrackID

        // Lifetime stats.
        stats.races += 1
        if result.finished { stats.finishes += 1 }
        stats.laps += result.lapsCompleted
        stats.drafts += result.stats.drafts
        stats.boosts += result.stats.boosts
        stats.bumps += result.stats.bumps
        stats.swaps += result.stats.swaps
        stats.echoGatePasses += result.stats.echoGatePasses
        stats.iceBreaks += result.stats.iceBreaks
        stats.splashes += result.stats.splashes
        stats.jumps += result.stats.jumps
        stats.distance += result.stats.distance

        var xpGain = 0
        var medalThisRace = false
        var starsThisRace = 0

        switch def.mode {
        case .career:
            guard result.finished, let targets else {
                xpGain += Economy.unfinishedXP
                break
            }
            let stars = targets.stars(for: result.totalTime)
            starsThisRace = stars
            let old = tracks[def.id]
            summary.stars = stars
            summary.previousStars = old?.stars ?? 0
            summary.previousBest = old?.bestTime
            let medal = def.medal?.isEarned(by: result.stats, laps: def.laps) ?? false
            medalThisRace = medal
            summary.medalEarned = medal
            summary.medalIsNew = medal && !(old?.medal ?? false)
            let better = old == nil || result.totalTime < old!.bestTime
            summary.newBest = better
            tracks[def.id] = TrackRecord(
                bestTime: better ? result.totalTime : old!.bestTime,
                stars: max(stars, old?.stars ?? 0),
                medal: medal || (old?.medal ?? false),
                bestLapTimes: better ? result.lapTimes : old!.bestLapTimes,
                plays: (old?.plays ?? 0) + 1)
            if stars == 3 && (old?.stars ?? 0) < 3 { stats.golds += 1 }
            let starGain = Economy.starSparks[max(stars, summary.previousStars)] - Economy.starSparks[summary.previousStars]
            if starGain > 0 { summary.lines.append(RewardLine(title: "\(max(stars, summary.previousStars)) stars", sparks: starGain)) }
            if summary.medalIsNew { summary.lines.append(RewardLine(title: "Echo medal: \(def.medal!.title)", sparks: Economy.medalSparks)) }
            if summary.lines.isEmpty { summary.lines.append(RewardLine(title: "Finish", sparks: Economy.replaySparks)) }
            xpGain += Economy.finishXP + Economy.starXP * stars + (medal ? Economy.medalXP : 0)

        case .daily:
            guard result.finished else {
                xpGain += Economy.unfinishedXP
                break
            }
            let key = day.string
            let old = daily[key]
            summary.newBest = old == nil || result.totalTime < old!.bestTime
            summary.previousBest = old?.bestTime
            daily[key] = DailyRecord(bestTime: min(result.totalTime, old?.bestTime ?? .infinity), plays: (old?.plays ?? 0) + 1)
            if old == nil {
                if let last = lastDailyDay.flatMap(DayKey.init), last == day.adding(days: -1) {
                    dailyStreak += 1
                } else if lastDailyDay != key {
                    dailyStreak = 1
                }
                lastDailyDay = key
                bestDailyStreak = max(bestDailyStreak, dailyStreak)
                summary.lines.append(RewardLine(title: "Daily track", sparks: Economy.dailyFirstFinishSparks))
                let streakBonus = Economy.dailyStreakSparks * min(dailyStreak, Economy.dailyStreakCap)
                summary.lines.append(RewardLine(title: "Streak: \(dailyStreak) day\(dailyStreak == 1 ? "" : "s")", sparks: streakBonus))
                xpGain += Economy.dailyXP
            } else {
                summary.lines.append(RewardLine(title: "Finish", sparks: Economy.replaySparks))
            }
            summary.dailyStreak = dailyStreak
            xpGain += Economy.finishXP

        case .weekly:
            // A weekly result is the total of the three races; the app passes the summed result when the third is done.
            guard result.finished else {
                xpGain += Economy.unfinishedXP
                break
            }
            let key = day.week.string
            let old = weekly[key]
            summary.newBest = old?.bestTotal == nil || result.totalTime < old!.bestTotal!
            summary.previousBest = old?.bestTotal
            weekly[key] = WeeklyRecord(bestTotal: min(result.totalTime, old?.bestTotal ?? .infinity), plays: (old?.plays ?? 0) + 1)
            summary.lines.append(old?.bestTotal == nil
                                 ? RewardLine(title: "Weekly gauntlet", sparks: Economy.weeklyCompleteSparks)
                                 : RewardLine(title: "Gauntlet again", sparks: Economy.weeklyReplaySparks))
            xpGain += Economy.finishXP * 3

        case .survival:
            survivalRuns += 1
            let laps = result.lapsCompleted
            summary.newBest = laps > survivalBest
            summary.previousBest = Double(survivalBest)
            survivalBest = max(survivalBest, laps)
            let sparksForLaps = min(Economy.survivalSparksCap, laps * Economy.survivalSparksPerLap)
            if sparksForLaps > 0 { summary.lines.append(RewardLine(title: "\(laps) laps survived", sparks: sparksForLaps)) }
            xpGain += Economy.survivalLapXP * laps
        }

        // Daily goals.
        var g = goals(for: day)
        for i in g.goals.indices where !g.claimed[i] {
            g.progress[i] = min(g.goals[i].target, g.progress[i] + g.goals[i].progress(from: result, mode: def.mode, stars: starsThisRace, medal: medalThisRace))
            if g.isDone(i) {
                g.claimed[i] = true
                summary.goalsCompleted.append(g.goals[i])
                summary.lines.append(RewardLine(title: "Goal: \(g.goals[i].title)", sparks: Economy.goalSparks))
            }
        }
        if g.allDone && !g.bonusClaimed {
            g.bonusClaimed = true
            summary.lines.append(RewardLine(title: "All daily goals", sparks: Economy.allGoalsBonus))
        }
        goals = g

        // XP and levels.
        xp += xpGain
        summary.xpGained = xpGain
        summary.levelAfter = level
        if summary.levelAfter > levelBefore {
            summary.lines.append(RewardLine(title: "Driver level \(summary.levelAfter)", sparks: Economy.levelUpSparks * (summary.levelAfter - levelBefore)))
        }

        let earned = summary.totalSparks
        sparks += earned
        sparksEarnedTotal += earned

        // Unlocks.
        summary.unlockedWorlds = World.allCases.filter { isUnlocked($0) && !worldsBefore.contains($0) }
        summary.unlockedCars = Cars.all.filter { isUnlocked($0) && !carsBefore.contains($0.id) }
        if def.mode == .career, result.finished, totalStars >= starsBefore, let next = Catalog.next(after: def),
           next.world == def.world, isUnlocked(next), summary.previousStars == 0 {
            summary.unlockedTrack = next
        }
        summary.survivalUnlocked = survivalUnlocked && !survivalBefore
        summary.weeklyUnlocked = weeklyUnlocked && !weeklyBefore

        // Achievements (after everything else is saved).
        let now = Set(Achievement.unlocked(in: self).map(\.id))
        achievements.formUnion(now)
        summary.newAchievements = Achievement.all.filter { now.contains($0.id) && !achievementsBefore.contains($0.id) }
        return summary
    }
}
