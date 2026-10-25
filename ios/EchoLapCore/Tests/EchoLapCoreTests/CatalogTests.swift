import XCTest
@testable import EchoLapCore

final class CatalogTests: XCTestCase {
    func testOneHundredTwentyTracksInOrder() {
        XCTAssertEqual(Catalog.career.count, 120)
        XCTAssertEqual(Set(Catalog.career.map(\.id)).count, 120)
        XCTAssertEqual(Catalog.career.map(\.index), Array(1...120))
        for world in World.allCases {
            let list = Catalog.tracks(in: world)
            XCTAssertEqual(list.count, 15)
            XCTAssertEqual(list.map(\.slot), Array(1...15))
            XCTAssertTrue(list.allSatisfy { $0.world == world })
            XCTAssertEqual(Set(list.map(\.name)).count, 15, "\(world.name): unique names")
            XCTAssertEqual(list[4].kind, .breather)
            XCTAssertEqual(list[9].kind, .breather)
            XCTAssertEqual(list[14].kind, .boss)
        }
        XCTAssertEqual(Catalog.next(after: Catalog.track(id: "1-15")!)?.id, "2-1")
        XCTAssertNil(Catalog.next(after: Catalog.track(id: "8-15")!))
        XCTAssertEqual(Catalog.previous(of: Catalog.track(id: "2-1")!)?.id, "1-15")
    }

    func testEveryCareerTrackIsOneSprint() {
        for def in Catalog.career { XCTAssertEqual(def.laps, 1, def.id) }
        // Bosses are longer sprints, breathers shorter.
        let d1 = Difficulty.of(Catalog.track(id: "3-1")!), boss = Difficulty.of(Catalog.track(id: "3-15")!), rest = Difficulty.of(Catalog.track(id: "3-5")!)
        XCTAssertGreaterThan(boss.lapLength, d1.lapLength * 1.2)
        XCTAssertLessThan(rest.lapLength, d1.lapLength)
        XCTAssertEqual(Difficulty.of(Catalog.track(id: "1-1")!).lapLength / Difficulty.assumedLapSpeed, 20, accuracy: 0.01)
        XCTAssertGreaterThan(Difficulty.of(Catalog.track(id: "8-14")!).lapLength / Difficulty.assumedLapSpeed, 38)
    }

    func testFeaturesPerWorldAndSlot() {
        for def in Catalog.career {
            XCTAssertTrue(def.features.isSuperset(of: def.world.primaryFeatures), def.id)
            if def.slot < 6 { XCTAssertEqual(def.features, def.world.primaryFeatures, "\(def.id): early slots teach one rule") }
            XCTAssertEqual(def.softEchoes, def.world == .harbour, "\(def.id): only World 1 has soft echoes")
        }
    }

    func testMedalsMatchTheirWorldsAndSkills() {
        for def in Catalog.career {
            guard let medal = def.medal else { XCTFail("\(def.id) has no medal"); continue }
            if def.kind == .breather {
                XCTAssertEqual(medal, .drifter, "\(def.id): breathers have the easy medal")
            } else {
                XCTAssertEqual(medal, def.world.medal, def.id)
            }
            XCTAssertFalse(medal.detail.isEmpty)
        }
        var s = RaceStats()
        XCTAssertFalse(Medal.drifter.isEarned(by: s))
        s.driftBoosts = 3
        XCTAssertTrue(Medal.drifter.isEarned(by: s))
        s.nearMisses = 2
        XCTAssertTrue(Medal.nearMiss.isEarned(by: s))
        XCTAssertTrue(Medal.echoMaster.isEarned(by: s))
        s.bumps = 1
        XCTAssertFalse(Medal.echoMaster.isEarned(by: s))
        XCTAssertTrue(Medal.iceDancer.isEarned(by: s))
        XCTAssertFalse(Medal.drifter.needsEchoes)
        XCTAssertTrue(Medal.nearMiss.needsEchoes)
    }

    func testNoOtherGameNamesInPlayerFacingText() {
        // Guideline 2.3.7 / 5.2: never another game's or brand's name where players or App Review can see it.
        let banned = ["mario", "kart", "asphalt", "need for speed", "csr", "hill climb", "real racing", "trackmania",
                      "temple run", "final lap", "forza", "gran turismo", "ridge racer", "outrun", "sonic", "nintendo",
                      "ferrari", "porsche", "lamborghini", "bugatti", "mclaren", "formula 1", "nascar"]
        var texts = Catalog.career.map(\.name)
        texts += World.allCases.flatMap { [$0.name, $0.ruleTitle, $0.ruleText] }
        texts += Medal.allCases.flatMap { [$0.title, $0.goal] }
        texts += Cars.all.flatMap { [$0.name, $0.role] }
        texts += Cosmetics.all.map(\.name)
        texts += Achievement.all.flatMap { [$0.title, $0.detail] }
        texts += World.allCases.flatMap { [$0.rival.name, $0.rival.taunt, $0.rival.beaten, $0.rival.won] }
        texts += DailyGoal.Kind.allCases.map { DailyGoal(kind: $0, target: 3).title }
        XCTAssertEqual(Set(World.allCases.map(\.rival.name)).count, 8, "every rival has their own name")
        for text in texts {
            for word in banned { XCTAssertFalse(text.lowercased().contains(word), "\"\(text)\" contains \"\(word)\"") }
        }
    }

    func testDailyWeeklySurvivalAreDeterministic() {
        let day = DayKey(year: 2026, month: 10, day: 25)
        XCTAssertEqual(Catalog.daily(day), Catalog.daily(day))
        XCTAssertNotEqual(Catalog.daily(day).seed, Catalog.daily(day.adding(days: 1)).seed)
        XCTAssertEqual(Catalog.weekly(day.week), Catalog.weekly(day.adding(days: 1).week).count == 3 && day.week == day.adding(days: 1).week ? Catalog.weekly(day.week) : Catalog.weekly(day.week))
        XCTAssertEqual(Catalog.weekly(day.week).count, 3)
        for k in 0..<120 {
            let d = Catalog.daily(day.adding(days: k))
            XCTAssertTrue([World.harbour, .canyon, .neon].contains(d.world), "daily tracks use only the first three worlds")
            XCTAssertFalse(d.features.contains(.softEchoes))
            XCTAssertEqual(d.mode, .daily)
        }
        XCTAssertEqual(Catalog.survival(day).laps, Int.max)
    }

    func testCarsAreBalancedAndUnlockInOrder() {
        XCTAssertEqual(Cars.all.count, 6)
        XCTAssertEqual(Cars.all.map(\.starsToUnlock), Cars.all.map(\.starsToUnlock).sorted())
        XCTAssertEqual(Cars.all.first?.starsToUnlock, 0)
        XCTAssertLessThanOrEqual(Cars.all.map(\.starsToUnlock).max()!, 360)
        let speeds = Cars.all.map(\.topSpeed)
        XCTAssertLessThan(speeds.max()! / speeds.min()!, 1.1, "top speeds within 10%: no racer is simply better")
        for car in Cars.all {
            let b = car.bars
            for v in [b.speed, b.grip, b.accel, b.draft] { XCTAssertTrue((1...5).contains(v)) }
        }
        XCTAssertEqual(Cars.car(id: "nope").id, "pip")
    }

    func testDifficultyCurveIsMonotonic() {
        let normals = Catalog.career.filter { $0.kind == .normal }.map(Difficulty.of)
        for (a, b) in zip(normals, normals.dropFirst()) {
            XCTAssertGreaterThanOrEqual(a.roadWidth, b.roadWidth)
            XCTAssertLessThanOrEqual(a.lapLength, b.lapLength)
            XCTAssertGreaterThanOrEqual(a.minRadius, b.minRadius)
            XCTAssertGreaterThanOrEqual(a.goldSlack, b.goldSlack)
        }
        for def in Catalog.career {
            let d = Difficulty.of(def)
            XCTAssertLessThan(d.goldSlack, d.silverSlack, def.id)
            XCTAssertGreaterThan(d.goldSlack, 0)
            XCTAssertEqual(d.bumpPenalty == 0, def.softEchoes, def.id)
            XCTAssertGreaterThanOrEqual(d.roadWidth, 2.3 * Physics.carWidth, "\(def.id): always room to pass an echo")
        }
        let first = Difficulty.of(Catalog.career[0]), last = Difficulty.of(Catalog.career[119])
        XCTAssertEqual(first.goldSlack, 0.10, accuracy: 1e-9)
        XCTAssertEqual(last.goldSlack, 0.05, accuracy: 1e-9)
        XCTAssertEqual(first.silverSlack, 0.22, accuracy: 1e-9)
        XCTAssertEqual(last.silverSlack, 0.12, accuracy: 1e-9)
    }

    func testEconomyAndCosmetics() {
        XCTAssertEqual(Set(Cosmetics.all.map(\.id)).count, Cosmetics.all.count)
        XCTAssertTrue(Cosmetics.all.allSatisfy { $0.price >= 0 })
        for kind in Cosmetic.Kind.allCases {
            XCTAssertEqual(Cosmetics.items(kind).filter { $0.price == 0 }.count, 1, "one free \(kind) to start with")
        }
        XCTAssertGreaterThan(Cosmetics.totalPrice, 10_000, "a long-term collection goal")
        XCTAssertEqual(Economy.starSparks, [0, 20, 35, 50])
        XCTAssertEqual(Economy.xpForLevel(1), 0)
        XCTAssertEqual(Economy.xpForLevel(2), 60)
        XCTAssertEqual(Economy.title(forLevel: 1), "Rookie")
        XCTAssertEqual(Economy.title(forLevel: 50), "Echo Master")
    }
}
