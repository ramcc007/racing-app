import Foundation
import EchoLapCore

/// Launch flags used by UI tests and App Store screenshots. Always off in release builds.
enum ScreenshotFlags {
    #if DEBUG
    private static let args = ProcessInfo.processInfo.arguments
    /// True while a UI test or screenshot run drives the app (no review prompts, no Game Center).
    static var active: Bool { args.contains("-EchoScene") || args.contains("-EchoUITest") }
    static var skipRuleCards: Bool { args.contains("-EchoScene") }
    static var scene: String? {
        guard let i = args.firstIndex(of: "-EchoScene"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    #else
    static let active = false
    static let skipRuleCards = false
    static let scene: String? = nil
    #endif
}

#if DEBUG
/// Puts the app into a known state for screenshots: `-EchoScene home|race|results|world|garage|trophies|daily|intro`.
/// `-EchoReset` starts from a fresh install (used by the UI tests).
@MainActor
enum ScreenshotScene {
    static var pendingDestination: HomeDestination?
    static var pendingDaily = false

    static func apply(to app: AppModel) {
        if ProcessInfo.processInfo.arguments.contains("-EchoReset") { app.resetProgress() }
        guard let scene = ScreenshotFlags.scene else { return }
        app.resetProgress()
        if scene == "intro" { return }
        seed(app)
        switch scene {
        case "race":
            app.route = .race(RaceRequest(def: Catalog.track(id: "3-4")!, kind: .career))
        case "results":
            app.route = .race(RaceRequest(def: Catalog.track(id: "2-3")!, kind: .career))
        case "world":
            app.route = .home
            pendingDestination = .world(.neon)
        case "garage":
            app.route = .home
            pendingDestination = .garage
        case "trophies":
            app.route = .home
            pendingDestination = .trophies
        case "daily":
            app.route = .home
            pendingDaily = true
        default:
            app.route = .home
        }
    }

    /// A player a few evenings in: Worlds 1 and 2 done, World 3 half done, a few styles bought.
    private static func seed(_ app: AppModel) {
        app.update { p in
            p.introSeen = true
            p.tutorialDone = true
            p.seenRules = [2, 3]
            for def in Catalog.career where def.world <= .neon {
                if def.world == .neon && def.slot > 8 { continue }
                let lap = (14 + 0.15 * Double(def.index - 1)) * (def.kind == .breather ? 0.85 : 1) * 0.97
                let stars = def.world == .harbour ? 3 : (def.slot % 4 == 0 ? 2 : 3)
                let laps = (0..<def.laps).map { lap * (1 + 0.012 * Double($0 == 0 ? 3 : 0)) }
                p.tracks[def.id] = TrackRecord(bestTime: laps.reduce(0, +), stars: stars, medal: def.slot % 3 != 0,
                                               bestLapTimes: laps, plays: 2 + def.slot % 3)
            }
            p.xp = Economy.xpForLevel(12) + 410
            p.sparks = 1_860
            p.sparksEarnedTotal = 4_290
            p.owned.formUnion(["paint.lava", "paint.mint", "trail.neon", "finish.fireworks"])
            p.selectedCar = "wedge"
            p.paints["wedge"] = "paint.lava"
            p.trail = "trail.neon"
            p.finishCelebration = "finish.fireworks"
            p.dailyStreak = 4
            p.bestDailyStreak = 6
            p.survivalBest = 14
            p.survivalRuns = 9
            p.stats.races = 141
            p.stats.finishes = 133
            p.stats.laps = 448
            p.stats.drafts = 612
            p.stats.boosts = 377
            p.stats.swaps = 0
            p.stats.echoGatePasses = 38
            p.stats.golds = 72
            p.stats.distance = 2_310_000
            p.lastDailyDay = app.today.adding(days: -1).string
            _ = p.goals(for: app.today)
            p.achievements = Set(Achievement.unlocked(in: p).map(\.id))
        }
    }
}
#endif
