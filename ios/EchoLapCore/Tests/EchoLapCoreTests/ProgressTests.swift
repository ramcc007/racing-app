import XCTest
@testable import EchoLapCore

final class ProgressTests: XCTestCase {
    private let day = DayKey(year: 2026, month: 10, day: 25)

    private func targets(robot: Double = 60) -> Targets {
        Targets(robotTime: robot, gold: robot * 1.1, silver: robot * 1.2, robotLapTimes: [robot], plan: .plain,
                paceTime: [0, robot], paceProgress: [0, 1000])
    }

    private func result(_ id: String, time: Double, finished: Bool = true, laps: Int = 3, stats: RaceStats = RaceStats()) -> RaceResult {
        RaceResult(trackID: id, carID: "pip", finished: finished, totalTime: time,
                   lapTimes: Array(repeating: time / Double(laps), count: laps), lapsCompleted: finished ? laps : 1, stats: stats)
    }

    // MARK: - Unlocks

    func testFreshPlayerSeesOnlyTheFirstTrack() {
        let p = PlayerProgress()
        XCTAssertTrue(p.isUnlocked(.harbour))
        XCTAssertFalse(p.isUnlocked(.canyon))
        XCTAssertTrue(p.isUnlocked(Catalog.track(id: "1-1")!))
        XCTAssertFalse(p.isUnlocked(Catalog.track(id: "1-2")!))
        XCTAssertEqual(p.nextTrack.id, "1-1")
        XCTAssertEqual(p.totalStars, 0)
        XCTAssertFalse(p.survivalUnlocked)
        XCTAssertFalse(p.weeklyUnlocked)
        XCTAssertEqual(Set(Cars.all.filter(p.isUnlocked).map(\.id)), ["pip"])
    }

    func testFinishingATrackOpensTheNextOne() {
        var p = PlayerProgress()
        let def = Catalog.track(id: "1-1")!
        let summary = p.record(result("1-1", time: 75), def: def, targets: targets(), day: day)
        XCTAssertEqual(summary.stars, 1)
        XCTAssertEqual(summary.unlockedTrack?.id, "1-2")
        XCTAssertTrue(p.isUnlocked(Catalog.track(id: "1-2")!))
        XCTAssertEqual(p.nextTrack.id, "1-2")
    }

    func testWorldsOpenAtTheirStarThresholds() {
        var p = PlayerProgress()
        for (k, def) in Catalog.tracks(in: .harbour).enumerated() where k < 7 {
            _ = p.record(result(def.id, time: 60), def: def, targets: targets(), day: day)   // 3 stars each
        }
        XCTAssertEqual(p.totalStars, 21)
        XCTAssertTrue(p.isUnlocked(.canyon), "20 stars opens World 2")
        XCTAssertFalse(p.isUnlocked(.neon))
        XCTAssertTrue(p.isUnlocked(Catalog.track(id: "2-1")!))
    }

    func testTwoStarPlayerCanReachEveryWorld() {
        // Silver on every track (30 stars a world) must open the next world each time.
        for world in World.allCases.dropFirst() {
            XCTAssertLessThanOrEqual(world.starsToUnlock, 30 * (world.rawValue - 1), world.name)
        }
        XCTAssertGreaterThan(World.orbit.starsToUnlock, 15 * 7, "but finishing alone (1 star) is not enough to see the end")
    }

    func testRacersUnlockWithStars() {
        var p = PlayerProgress()
        p.tracks = Dictionary(uniqueKeysWithValues: Catalog.career.prefix(10).map { ($0.id, TrackRecord(bestTime: 1, stars: 3, medal: false, bestLapTimes: [], plays: 1)) })
        XCTAssertEqual(p.totalStars, 30)
        XCTAssertTrue(p.isUnlocked(Cars.wedge))
        XCTAssertFalse(p.isUnlocked(Cars.hopper))
        p.select(Cars.hopper)
        XCTAssertEqual(p.selectedCar, "pip", "locked racers can't be selected")
        p.select(Cars.wedge)
        XCTAssertEqual(p.selectedCar, "wedge")
    }

    func testSurvivalAndWeeklyUnlock() {
        var p = PlayerProgress()
        for def in Catalog.tracks(in: .harbour).prefix(5) {
            _ = p.record(result(def.id, time: 75), def: def, targets: targets(), day: day)   // 1 star each
        }
        XCTAssertTrue(p.survivalUnlocked, "finishing 1-5 opens Echo Survival")
        XCTAssertFalse(p.weeklyUnlocked)
        for def in Catalog.tracks(in: .harbour).prefix(7) {
            _ = p.record(result(def.id, time: 60), def: def, targets: targets(), day: day)
        }
        XCTAssertTrue(p.weeklyUnlocked)
    }

    func testUnknownTrackIDsNeverCountStars() {
        var p = PlayerProgress()
        p.tracks["daily-2026-10-25"] = TrackRecord(bestTime: 1, stars: 3, medal: true, bestLapTimes: [], plays: 1)
        p.tracks["9-9"] = TrackRecord(bestTime: 1, stars: 3, medal: true, bestLapTimes: [], plays: 1)
        XCTAssertEqual(p.totalStars, 0)
        XCTAssertEqual(p.medalCount, 0)
    }

    // MARK: - Career rewards

    func testStarSparksAreIncrementalAndMedalPaysOnce() {
        var p = PlayerProgress()
        let def = Catalog.track(id: "1-1")!
        var s = p.record(result("1-1", time: 75), def: def, targets: targets(), day: day)   // 1 star
        XCTAssertEqual(s.lines.first, RewardLine(title: "1 stars", sparks: 20))
        s = p.record(result("1-1", time: 71), def: def, targets: targets(), day: day)       // 2 stars
        XCTAssertEqual(s.lines.first, RewardLine(title: "2 stars", sparks: 15))
        var stats = RaceStats()
        stats.drafts = 10
        s = p.record(result("1-1", time: 65, laps: 2, stats: stats), def: def, targets: targets(), day: day)   // 3 stars + medal
        XCTAssertEqual(s.stars, 3)
        XCTAssertTrue(s.medalIsNew)
        XCTAssertTrue(s.lines.contains(RewardLine(title: "3 stars", sparks: 15)))
        XCTAssertTrue(s.lines.contains(RewardLine(title: "Echo medal: Draft train", sparks: Economy.medalSparks)))
        s = p.record(result("1-1", time: 64, laps: 2, stats: stats), def: def, targets: targets(), day: day)
        XCTAssertFalse(s.medalIsNew)
        XCTAssertEqual(s.lines.first, RewardLine(title: "Finish", sparks: Economy.replaySparks), "nothing new: a small finish reward")
        XCTAssertEqual(p.tracks["1-1"]?.plays, 4)
        XCTAssertEqual(p.tracks["1-1"]?.bestTime, 64)
        XCTAssertEqual(p.tracks["1-1"]?.stars, 3)
        XCTAssertEqual(p.stats.golds, 1)
    }

    func testSlowerRunKeepsTheBestTime() {
        var p = PlayerProgress()
        let def = Catalog.track(id: "1-1")!
        _ = p.record(result("1-1", time: 62), def: def, targets: targets(), day: day)
        let s = p.record(result("1-1", time: 70), def: def, targets: targets(), day: day)
        XCTAssertFalse(s.newBest)
        XCTAssertEqual(p.tracks["1-1"]?.bestTime, 62)
        XCTAssertEqual(p.tracks["1-1"]?.stars, 3, "stars never go down")
    }

    func testUnfinishedRaceGivesNoStarsOrSparks() {
        var p = PlayerProgress()
        let def = Catalog.track(id: "1-1")!
        let s = p.record(result("1-1", time: 20, finished: false), def: def, targets: targets(), day: day)
        XCTAssertNil(p.tracks["1-1"])
        XCTAssertEqual(s.totalSparks, 0)
        XCTAssertEqual(s.xpGained, Economy.unfinishedXP)
        XCTAssertEqual(p.stats.races, 1)
        XCTAssertEqual(p.stats.finishes, 0)
    }

    func testXPAndLevelUpSparks() {
        var p = PlayerProgress()
        let def = Catalog.track(id: "1-1")!
        let s = p.record(result("1-1", time: 60), def: def, targets: targets(), day: day)
        let expectedXP = Economy.finishXP + 3 * Economy.starXP
        XCTAssertEqual(s.xpGained, expectedXP)
        XCTAssertEqual(p.xp, expectedXP)
        XCTAssertEqual(Economy.level(forXP: 59), 1)
        XCTAssertEqual(Economy.level(forXP: 60), 2)
        XCTAssertEqual(Economy.level(forXP: 2700), 10)
        p.xp = 0
        let s2 = p.record(result("1-1", time: 60), def: def, targets: targets(), day: day)
        XCTAssertTrue(s2.leveledUp)
        XCTAssertTrue(s2.lines.contains(RewardLine(title: "Driver level 2", sparks: Economy.levelUpSparks)))
    }

    func testSparksBalanceMatchesTheLines() {
        var p = PlayerProgress()
        var total = 0
        for def in Catalog.tracks(in: .harbour) {
            let s = p.record(result(def.id, time: 60), def: def, targets: targets(), day: day)
            total += s.totalSparks
        }
        XCTAssertEqual(p.sparks, total)
        XCTAssertEqual(p.sparksEarnedTotal, total)
    }

    // MARK: - Daily, weekly, survival

    func testDailyStreak() {
        var p = PlayerProgress()
        func playDaily(_ d: DayKey, time: Double = 50) -> RewardSummary {
            p.record(result("daily-" + d.string, time: time), def: Catalog.daily(d), targets: nil, day: d)
        }
        var s = playDaily(day)
        XCTAssertEqual(p.dailyStreak, 1)
        XCTAssertTrue(s.lines.contains(RewardLine(title: "Daily track", sparks: Economy.dailyFirstFinishSparks)))
        XCTAssertTrue(s.lines.contains(RewardLine(title: "Streak: 1 day", sparks: 10)))
        s = playDaily(day, time: 45)
        XCTAssertEqual(p.dailyStreak, 1, "replaying the same day doesn't grow the streak")
        XCTAssertEqual(s.lines.first, RewardLine(title: "Finish", sparks: Economy.replaySparks))
        XCTAssertEqual(p.daily[day.string]?.bestTime, 45)
        XCTAssertEqual(p.daily[day.string]?.plays, 2)
        for k in 1...8 { _ = playDaily(day.adding(days: k)) }
        XCTAssertEqual(p.dailyStreak, 9)
        let last = p.record(result("d", time: 50), def: Catalog.daily(day.adding(days: 9)), targets: nil, day: day.adding(days: 9))
        XCTAssertTrue(last.lines.contains(RewardLine(title: "Streak: 10 days", sparks: 70)), "streak bonus caps at 7 days")
        _ = playDaily(day.adding(days: 12))
        XCTAssertEqual(p.dailyStreak, 1, "a missed day restarts the streak")
        XCTAssertEqual(p.bestDailyStreak, 10)
    }

    func testWeeklyRecord() {
        var p = PlayerProgress()
        let defs = Catalog.weekly(day.week)
        var s = p.record(result("weekly", time: 150), def: defs[2], targets: nil, day: day)
        XCTAssertEqual(s.lines.first, RewardLine(title: "Weekly gauntlet", sparks: Economy.weeklyCompleteSparks))
        s = p.record(result("weekly", time: 140), def: defs[2], targets: nil, day: day)
        XCTAssertEqual(s.lines.first, RewardLine(title: "Gauntlet again", sparks: Economy.weeklyReplaySparks))
        XCTAssertEqual(p.weekly[day.week.string]?.bestTotal, 140)
    }

    func testSurvivalSparksPerLapAreCapped() {
        var p = PlayerProgress()
        let def = Catalog.survival(day)
        var s = p.record(RaceResult(trackID: def.id, carID: "pip", finished: true, totalTime: 99, lapTimes: [], lapsCompleted: 7, stats: RaceStats()),
                         def: def, targets: nil, day: day)
        XCTAssertEqual(s.lines.first, RewardLine(title: "7 laps survived", sparks: 35))
        s = p.record(RaceResult(trackID: def.id, carID: "pip", finished: true, totalTime: 999, lapTimes: [], lapsCompleted: 40, stats: RaceStats()),
                     def: def, targets: nil, day: day)
        XCTAssertEqual(s.lines.first, RewardLine(title: "40 laps survived", sparks: Economy.survivalSparksCap))
        XCTAssertEqual(p.survivalBest, 40)
        XCTAssertEqual(p.survivalRuns, 2)
    }

    // MARK: - Daily goals

    func testGoalsAreTheSameForTheSameDayAndUnlocks() {
        let worlds: Set<World> = [.harbour]
        XCTAssertEqual(GoalState.make(for: day, unlocked: worlds), GoalState.make(for: day, unlocked: worlds))
        XCTAssertEqual(GoalState.make(for: day, unlocked: worlds).goals.count, 3)
        XCTAssertEqual(Set(GoalState.make(for: day, unlocked: worlds).goals.map(\.kind)).count, 3, "three different goals")
        for k in 0..<60 {
            let g = GoalState.make(for: day.adding(days: k), unlocked: worlds)
            XCTAssertFalse(g.goals.contains { [.swaps, .echoGate, .jumps, .cleanRace].contains($0.kind) },
                           "only rules the player has unlocked")
        }
    }

    func testGoalsCompleteOncePlusBonus() {
        var p = PlayerProgress()
        p.goals = GoalState(day: day.string, goals: [DailyGoal(kind: .finishRaces, target: 2), DailyGoal(kind: .useBoosts, target: 3),
                                                     DailyGoal(kind: .completeLaps, target: 4)],
                            progress: [0, 0, 0], claimed: [false, false, false], bonusClaimed: false)
        var stats = RaceStats()
        stats.boosts = 2
        let def = Catalog.track(id: "1-1")!
        var s = p.record(result("1-1", time: 60, laps: 2, stats: stats), def: def, targets: targets(), day: day)
        XCTAssertTrue(s.goalsCompleted.isEmpty)
        s = p.record(result("1-1", time: 60, laps: 2, stats: stats), def: def, targets: targets(), day: day)
        XCTAssertEqual(s.goalsCompleted.count, 3)
        XCTAssertTrue(s.lines.contains(RewardLine(title: "All daily goals", sparks: Economy.allGoalsBonus)))
        s = p.record(result("1-1", time: 60, laps: 2, stats: stats), def: def, targets: targets(), day: day)
        XCTAssertTrue(s.goalsCompleted.isEmpty, "a goal pays once")
        XCTAssertFalse(s.lines.contains { $0.title.hasPrefix("Goal") || $0.title == "All daily goals" })
    }

    // MARK: - Cosmetics

    func testBuyingAndEquipping() {
        var p = PlayerProgress()
        XCTAssertEqual(p.buy("paint.mint"), .notEnoughSparks)
        p.sparks = 1000
        XCTAssertNil(p.buy("paint.mint"))
        XCTAssertEqual(p.sparks, 800)
        XCTAssertEqual(p.buy("paint.mint"), .alreadyOwned)
        XCTAssertEqual(p.buy("nope"), .unknown)
        p.equip("paint.mint")
        XCTAssertEqual(p.paint(for: Cars.pip), "paint.mint")
        p.equip("trail.neon")
        XCTAssertEqual(p.trail, "trail.classic", "can't equip what you don't own")
        XCTAssertTrue(p.owned.isSuperset(of: Cosmetics.freeIDs))
    }

    // MARK: - Achievements

    func testAchievementsUnlockOnce() {
        var p = PlayerProgress()
        let def = Catalog.track(id: "1-1")!
        let s = p.record(result("1-1", time: 60), def: def, targets: targets(), day: day)
        let ids = Set(s.newAchievements.map(\.id))
        XCTAssertTrue(ids.contains("firstFinish"))
        XCTAssertTrue(ids.contains("firstGold"))
        let again = p.record(result("1-1", time: 60), def: def, targets: targets(), day: day)
        XCTAssertFalse(again.newAchievements.contains { $0.id == "firstFinish" })
        XCTAssertEqual(Set(Achievement.all.map(\.id)).count, Achievement.all.count, "unique IDs")
        XCTAssertTrue(Achievement.all.allSatisfy { $0.gameCenterID.hasPrefix("echolap.ach.") })
    }

    // MARK: - Saving

    func testSaveRoundTrip() throws {
        var p = PlayerProgress()
        let def = Catalog.track(id: "1-1")!
        _ = p.record(result("1-1", time: 61.5), def: def, targets: targets(), day: day)
        p.sparks = 999
        p.settings.camera = .fixed
        p.settings.steeringSensitivity = 1.4
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(PlayerProgress.self, from: data)
        XCTAssertEqual(back, p)
    }

    func testOldOrBrokenSavesStillLoad() throws {
        let empty = try JSONDecoder().decode(PlayerProgress.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, PlayerProgress())
        let odd = """
        {"sparks": "lots", "xp": -50, "selectedCar": "rocket", "futureField": [1,2,3],
         "settings": {"steeringSensitivity": 9, "camera": "drone"},
         "tracks": {"1-1": {"bestTime": 61.2, "stars": 3, "medal": true, "bestLapTimes": [30.6, 30.6], "plays": 2}},
         "owned": ["paint.mint"]}
        """
        let p = try JSONDecoder().decode(PlayerProgress.self, from: Data(odd.utf8))
        XCTAssertEqual(p.sparks, 0, "a wrong type falls back to the default")
        XCTAssertEqual(p.xp, 0, "negative values are cleaned up")
        XCTAssertEqual(p.selectedCar, "pip", "an unknown racer falls back to Pip")
        XCTAssertEqual(p.settings.steeringSensitivity, 1.6, "clamped to the allowed range")
        XCTAssertEqual(p.settings.camera, .follow)
        XCTAssertEqual(p.tracks["1-1"]?.stars, 3)
        XCTAssertTrue(p.owned.contains("paint.mint"))
        XCTAssertTrue(p.owned.isSuperset(of: Cosmetics.freeIDs), "free items always owned")
    }
}
