import XCTest
@testable import EchoLapCore

/// Plays the whole game on paper with real targets: a gold player, a silver player and a "just finish" player.
/// Checks that the unlock pacing works for each and that every reward number adds up.
final class CareerSimulationTests: XCTestCase {
    private static let built: [String: BuiltTrack] = {
        var all: [String: BuiltTrack] = [:]
        for def in Catalog.career { all[def.id] = TrackLibrary.shared.build(def) }
        return all
    }()

    private func play(starsWanted: Int, withMedals: Bool) -> (PlayerProgress, [RewardSummary]) {
        var p = PlayerProgress()
        var day = DayKey(year: 2026, month: 11, day: 1)
        var summaries: [RewardSummary] = []
        var progressMade = true
        while progressMade {
            progressMade = false
            for def in Catalog.career where p.isUnlocked(def) && p.tracks[def.id] == nil {
                let t = Self.built[def.id]!.targets
                let time = starsWanted == 3 ? t.gold - 0.01 : (starsWanted == 2 ? t.silver - 0.01 : t.silver + 5)
                var stats = RaceStats()
                if withMedals {
                    stats.drafts = 99; stats.draftSeconds = 99; stats.echoGatePasses = 9; stats.swaps = 9
                    stats.driftBoosts = 9; stats.nearMisses = 9
                } else {
                    stats.bumps = 1; stats.splashes = 1
                }
                let laps = Array(repeating: time / Double(def.laps), count: def.laps)
                let r = RaceResult(trackID: def.id, carID: "pip", finished: true, totalTime: time, lapTimes: laps,
                                   lapsCompleted: def.laps, stats: stats, echoesOnRoad: 1)
                summaries.append(p.record(r, def: def, targets: t, day: day))
                progressMade = true
            }
            day = day.adding(days: 1)
        }
        return (p, summaries)
    }

    func testGoldPlayerOpensEverything() {
        let (p, summaries) = play(starsWanted: 3, withMedals: true)
        XCTAssertEqual(p.tracks.count, 120)
        XCTAssertEqual(p.totalStars, 360)
        XCTAssertEqual(p.medalCount, 120)
        XCTAssertEqual(p.unlockedWorlds.count, 8)
        XCTAssertTrue(Cars.all.allSatisfy(p.isUnlocked))
        XCTAssertEqual(p.stats.golds, 120)
        // Sparks: 50 per track for stars, 40 per medal, plus goals and level-ups — all accounted for in the lines.
        XCTAssertEqual(p.sparks, summaries.reduce(0) { $0 + $1.totalSparks })
        let starAndMedalSparks = summaries.flatMap(\.lines).filter { $0.title.hasSuffix("stars") || $0.title.hasPrefix("Echo medal") }
            .reduce(0) { $0 + $1.sparks }
        XCTAssertEqual(starAndMedalSparks, 120 * (Economy.starSparks[3] + Economy.medalSparks))
        XCTAssertGreaterThanOrEqual(p.level, 20, "a full career makes you a Champion")
        XCTAssertLessThan(p.level, 30, "with plenty of levels left for dailies and Survival")
        for id in ["firstFinish", "firstGold", "world8", "stars360", "medals120", "garage"] {
            XCTAssertTrue(p.achievements.contains(id), id)
        }
        let unlockedWorlds = summaries.flatMap(\.unlockedWorlds)
        XCTAssertEqual(unlockedWorlds, Array(World.allCases.dropFirst()), "each world announced exactly once, in order")
    }

    func testSilverPlayerStillSeesTheWholeGame() {
        let (p, _) = play(starsWanted: 2, withMedals: false)
        XCTAssertEqual(p.tracks.count, 120, "two stars everywhere is enough to reach and finish every track")
        XCTAssertEqual(p.totalStars, 240)
        XCTAssertEqual(p.medalCount, 0, "this player bumped and splashed every race and never drafted")
        XCTAssertFalse(p.isUnlocked(Cars.drifter), "the last racer needs some gold stars")
    }

    func testFinishOnlyPlayerIsAskedToImprove() {
        let (p, _) = play(starsWanted: 1, withMedals: false)
        XCTAssertEqual(p.totalStars, p.tracks.count, "one star each")
        XCTAssertEqual(p.tracks.count, 15, "every World 1 track finished")
        XCTAssertFalse(p.isUnlocked(.canyon), "15 stars is short of the 20 that open World 2: improve some times")
        XCTAssertEqual(p.nextTrack.id, "1-1", "Continue points back to the first track worth improving")
    }
}
