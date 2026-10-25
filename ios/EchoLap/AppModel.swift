import Foundation
import SwiftUI
import EchoLapCore

/// A race the player asked for.
struct RaceRequest: Identifiable, Hashable {
    enum Kind: Hashable {
        case career, daily, survival, tutorial
        /// Race n (0, 1, 2) of this week's gauntlet; earlier results are carried in the session.
        case weekly(Int)
    }
    let id = UUID()
    let def: TrackDef
    let kind: Kind
    /// 0 for the first go at a track this sitting; GO AGAIN counts up, and retries get a short countdown.
    var attempt = 0
}

/// Where the app is.
enum Route: Hashable {
    case intro
    case home
    case race(RaceRequest)
}

/// Owns saved progress, navigation, track building and the saved runs that race you as echoes.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var progress: PlayerProgress
    @Published var route: Route
    /// A short message shown over the menus (for example why something is locked). Clears itself.
    @Published var toast: String?
    /// Results of the weekly gauntlet races finished so far in this attempt.
    @Published var weeklySession: [RaceResult] = []

    private var toastTask: Task<Void, Never>?
    private let fileURL: URL
    private let runsFolder: URL
    private var building: [String: Task<BuiltTrack, Never>] = [:]
    private var runsCache: [String: [SavedRun]] = [:]

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let runs = support.appendingPathComponent("runs", isDirectory: true)
        try? FileManager.default.createDirectory(at: runs, withIntermediateDirectories: true)
        // The old single-ghost folder is no longer used.
        try? FileManager.default.removeItem(at: support.appendingPathComponent("ghosts", isDirectory: true))
        let url = support.appendingPathComponent("progress.json")
        var loaded = PlayerProgress()
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            loaded = saved
        }
        fileURL = url
        runsFolder = runs
        progress = loaded
        route = loaded.introSeen ? .home : .intro
        applySettings()
        #if DEBUG
        ScreenshotScene.apply(to: self)
        #endif
    }

    var today: DayKey { DayKey(date: Date()) }

    // MARK: - Saving

    /// Change progress and save straight away (progress is never only in memory).
    func update(_ change: (inout PlayerProgress) -> Void) {
        change(&progress)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        try? data.write(to: fileURL, options: [.atomic])   // a crash mid-write never corrupts the save
        GameCenterService.shared.sync(progress)
    }

    func applySettings() {
        Haptics.enabled = progress.settings.haptics
        Sound.enabled = progress.settings.sound
    }

    func showToast(_ text: String) {
        toast = text
        UIAccessibility.post(notification: .announcement, argument: text)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    // MARK: - Tracks

    /// Builds (or returns the cached) track off the main thread. The first build of a track takes a moment
    /// because the robot driver test-drives it; it's cached for the rest of the session.
    func build(_ def: TrackDef) async -> BuiltTrack {
        if let task = building[def.id] { return await task.value }
        let task = Task.detached(priority: .userInitiated) { TrackLibrary.shared.build(def) }
        building[def.id] = task
        return await task.value
    }

    /// Starts building tracks the player is likely to open next, in the background.
    func prefetch(_ defs: [TrackDef]) {
        for def in defs where building[def.id] == nil {
            building[def.id] = Task.detached(priority: .utility) { TrackLibrary.shared.build(def) }
        }
    }

    // MARK: - Saved runs (the echo ladder)

    /// The best runs saved for a track, fastest first.
    func savedRuns(for id: String) -> [SavedRun] {
        if let cached = runsCache[id] { return cached }
        let loaded = (try? Data(contentsOf: runsFolder.appendingPathComponent(id + ".json")))
            .flatMap { try? JSONDecoder().decode([SavedRun].self, from: $0) } ?? []
        runsCache[id] = loaded
        return loaded
    }

    /// The echoes to put on the road for a track: as many of your best runs as your rung on its ladder.
    func ladder(for id: String) -> [Echo] {
        let runs = savedRuns(for: id)
        return SavedRun.ladder(runs, count: progress.ladderCount(for: id, savedRuns: runs.count))
    }

    private func saveRun(_ run: SavedRun) {
        let kept = SavedRun.keepBest(savedRuns(for: run.trackID), adding: run)
        runsCache[run.trackID] = kept
        guard let data = try? JSONEncoder().encode(kept) else { return }
        try? data.write(to: runsFolder.appendingPathComponent(run.trackID + ".json"), options: [.atomic])
    }

    /// Echoes for a demo or screenshot: the robot drives the track a few times with a little weave.
    nonisolated static func demoEchoes(for built: BuiltTrack, count: Int) -> [Echo] {
        var runs: [SavedRun] = []
        for k in 0..<count {
            let race = Race(track: built.track, spec: Cars.pip, laps: 1, countdown: 0.05)
            let driver = RobotDriver(track: built.track, plan: built.targets.plan)
            driver.weave = 0.25 + 0.1 * Double(k)
            var ticks = 0
            while !race.isFinished && ticks < 120 * 120 {
                race.tick(driver.input(for: race))
                race.events.removeAll(keepingCapacity: true)
                ticks += 1
            }
            if race.isFinished { runs.append(SavedRun(race: race)) }
        }
        return SavedRun.ladder(runs, count: count)
    }

    // MARK: - Navigation

    func play(_ def: TrackDef, kind: RaceRequest.Kind = .career) {
        if def.mode == .career && !progress.isUnlocked(def) {
            if !progress.isUnlocked(def.world) {
                showToast("\(def.world.name) opens at \(def.world.starsToUnlock) stars.")
            } else {
                showToast("Finish the track before this one first.")
            }
            return
        }
        Haptics.tap()
        route = .race(RaceRequest(def: def, kind: kind))
    }

    func playDaily() { play(Catalog.daily(today), kind: .daily) }

    func playSurvival() {
        guard progress.survivalUnlocked else {
            showToast("Finish track 1-5 to open Echo Survival.")
            return
        }
        play(Catalog.survival(today), kind: .survival)
    }

    func startWeekly() {
        guard progress.weeklyUnlocked else {
            showToast("The weekly gauntlet opens at \(Catalog.weeklyUnlockStars) stars.")
            return
        }
        weeklySession = []
        play(Catalog.weekly(today.week)[0], kind: .weekly(0))
    }

    func goHome() {
        route = .home
    }

    /// GO AGAIN: the same event, straight away, with a short countdown. A weekly gauntlet starts over from its first track.
    func restart(_ request: RaceRequest) {
        switch request.kind {
        case .weekly: startWeekly()
        default: route = .race(RaceRequest(def: request.def, kind: request.kind, attempt: request.attempt + 1))
        }
    }

    /// The next track of this week's gauntlet, after race `index` was finished.
    func continueWeekly(after index: Int) {
        let tracks = Catalog.weekly(today.week)
        guard index + 1 < tracks.count else { goHome(); return }
        play(tracks[index + 1], kind: .weekly(index + 1))
    }

    /// The intro's "Start racing": the first race is track 1-1 and teaches the controls by doing.
    func startTutorial() {
        update { $0.introSeen = true }
        route = .race(RaceRequest(def: Catalog.track(id: "1-1")!, kind: .tutorial))
    }

    func replayTutorial() {
        route = .race(RaceRequest(def: Catalog.track(id: "1-1")!, kind: .tutorial))
    }

    func resetProgress() {
        progress = PlayerProgress()
        save()
        runsCache = [:]
        try? FileManager.default.removeItem(at: runsFolder)
        try? FileManager.default.createDirectory(at: runsFolder, withIntermediateDirectories: true)
        applySettings()
        route = .intro
    }

    // MARK: - Results

    /// Saves a race result and returns what it earned. Weekly races only count once all three are done.
    /// A finished career or daily run is kept as an echo for the ladder.
    func record(_ result: RaceResult, request: RaceRequest, targets: Targets?, run: SavedRun?) -> RewardSummary? {
        let day = today
        switch request.kind {
        case .weekly(let index):
            weeklySession.append(result)
            guard index == 2 || !result.finished else { return nil }
            let total = weeklySession.reduce(0) { $0 + $1.totalTime }
            var stats = RaceStats()
            for r in weeklySession {
                stats.drafts += r.stats.drafts; stats.boosts += r.stats.boosts; stats.bumps += r.stats.bumps
                stats.draftSeconds += r.stats.draftSeconds; stats.swaps += r.stats.swaps
                stats.echoGatePasses += r.stats.echoGatePasses; stats.jumps += r.stats.jumps; stats.distance += r.stats.distance
                stats.drifts += r.stats.drifts; stats.driftBoosts += r.stats.driftBoosts; stats.nearMisses += r.stats.nearMisses
            }
            let finished = weeklySession.count == 3 && weeklySession.allSatisfy(\.finished)
            let combined = RaceResult(trackID: "weekly-" + day.week.string, carID: result.carID, finished: finished,
                                      totalTime: total, lapTimes: weeklySession.flatMap(\.lapTimes),
                                      lapsCompleted: weeklySession.reduce(0) { $0 + $1.lapsCompleted }, stats: stats)
            var summary = RewardSummary()
            update { summary = $0.record(combined, def: request.def, targets: nil, day: day) }
            if finished { GameCenterService.shared.submitTime(.weekly, seconds: total, periodKey: day.week.string) }
            return summary
        default:
            var summary = RewardSummary()
            update { summary = $0.record(result, def: request.def, targets: targets, day: day) }
            if request.kind == .daily, result.finished {
                GameCenterService.shared.submitTime(.daily, seconds: result.totalTime, periodKey: day.string)
            }
            if request.kind == .tutorial {
                update { $0.tutorialDone = true }
            }
            if let run, result.finished, request.def.mode == .career || request.def.mode == .daily {
                saveRun(run)
            }
            return summary
        }
    }
}
