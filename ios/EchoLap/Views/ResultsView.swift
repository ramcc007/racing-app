import SwiftUI
import StoreKit
import EchoLapCore

/// After a race: time, stars, laps, medal, every Spark and XP earned, anything unlocked, and what to do next.
struct ResultsView: View {
    let outcome: RaceController.Outcome
    let request: RaceRequest
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @AppStorage("echolap.reviewAskedAtStars") private var reviewAskedAtStars = 0
    @State private var shownStars = 0

    private var result: RaceResult { outcome.result }
    private var summary: RewardSummary? { outcome.summary }
    private var def: TrackDef { request.def }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        if def.mode == .career, result.finished { starsBlock }
                        if !lapTimes.isEmpty, def.mode != .survival { lapsBlock }
                        if let medal = def.medal, def.mode == .career, result.finished { medalBlock(medal) }
                        if let summary { rewardsBlock(summary) }
                        if let summary { unlocksBlock(summary) }
                    }
                    .padding(20)
                }
                .scrollBounceBehavior(.basedOnSize)
                actions
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .frame(maxWidth: 520)
            .solidCard(cornerRadius: 30)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .accessibilityIdentifier("results")
        .task { await revealStars() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(Theme.rounded(.title, .black))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(def.mode == .career ? "\(def.label) · \(def.name)" : def.name)
                .font(Theme.rounded(.subheadline, .semibold)).foregroundStyle(Theme.muted)
            if def.mode == .survival {
                Text("\(result.lapsCompleted) \(result.lapsCompleted == 1 ? "lap" : "laps")")
                    .font(Theme.timer(52))
                Text("Best \(app.progress.survivalBest) laps").font(Theme.rounded(.footnote, .bold)).foregroundStyle(Theme.muted)
            } else if result.finished {
                Text(TimeFormat.race(displayTime))
                    .font(Theme.timer(52))
                    .accessibilityLabel(TimeFormat.spoken(displayTime))
                if let summary, let previous = summary.previousBest {
                    let diff = displayTime - previous
                    Text(summary.newBest ? "New best · \(TimeFormat.delta(diff))" : "Best \(TimeFormat.race(previous)) · \(TimeFormat.delta(diff))")
                        .font(Theme.rounded(.subheadline, .heavy))
                        .foregroundStyle(summary.newBest ? Theme.good : Theme.muted)
                } else if summary?.newBest == true || def.mode == .career {
                    Text("First finish").font(Theme.rounded(.subheadline, .heavy)).foregroundStyle(Theme.good)
                }
            } else {
                Text("Not finished").font(Theme.rounded(.title3, .heavy)).foregroundStyle(Theme.bad)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var headline: String {
        if outcome.isTutorial { return "Nice driving!" }
        switch def.mode {
        case .survival: return "Run over"
        case .weekly:
            if case .weekly(let n) = request.kind, n < 2, result.finished { return "Race \(n + 1) of 3 done" }
            return summary == nil ? "Gauntlet" : (result.finished ? "Gauntlet complete" : "Gauntlet over")
        case .daily: return summary?.newBest == true ? "New daily best!" : "Daily track"
        case .career:
            let stars = summary?.stars ?? 0
            return stars >= 3 ? "Gold!" : (stars == 2 ? "Silver!" : "Finished")
        }
    }

    /// The weekly result shows the gauntlet's total time once all three races are done.
    private var displayTime: Double {
        if case .weekly(let n) = request.kind, n == 2 { return app.weeklySession.reduce(0) { $0 + $1.totalTime } }
        return result.totalTime
    }

    // MARK: - Stars

    private var starsBlock: some View {
        let stars = summary?.stars ?? outcome.targets?.stars(for: result.totalTime) ?? 1
        return VStack(spacing: 10) {
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < shownStars ? "star.fill" : "star")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(i < shownStars ? Theme.gold : Theme.muted.opacity(0.4))
                        .scaleEffect(i < shownStars ? 1 : 0.85)
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.5), value: shownStars)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(stars) of 3 stars")
            if let targets = outcome.targets {
                if stars < 3 {
                    let goal = stars == 2 ? targets.gold : targets.silver
                    Text("\(stars == 2 ? "Gold" : "Silver"): beat \(TimeFormat.race(goal)) (\(TimeFormat.delta(result.totalTime - goal)) away)")
                        .font(Theme.rounded(.footnote, .bold)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Gold time \(TimeFormat.race(targets.gold))").font(Theme.rounded(.footnote, .bold)).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func revealStars() async {
        guard def.mode == .career, result.finished else { return }
        let stars = summary?.stars ?? 1
        if reduceMotion {
            shownStars = stars
        } else {
            for k in 1...max(1, stars) {
                try? await Task.sleep(for: .milliseconds(k == 1 ? 350 : 280))
                shownStars = k
                Sound.play(.star(k))
                Haptics.light(0.6 + 0.2 * Double(k))
            }
        }
        maybeAskForReview(stars: stars)
    }

    /// At most twice, and only after a gold on a good run: never on a failure, never during a race.
    private func maybeAskForReview(stars: Int) {
        guard stars == 3, !ScreenshotFlags.active else { return }
        let total = app.progress.totalStars
        if (reviewAskedAtStars == 0 && total >= 24) || (reviewAskedAtStars > 0 && reviewAskedAtStars < 120 && total >= 120) {
            reviewAskedAtStars = total
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                requestReview()
            }
        }
    }

    // MARK: - Laps and medal

    /// Every lap of this race, or of all three gauntlet races once the gauntlet is done.
    private var lapTimes: [Double] {
        if case .weekly(let n) = request.kind, n == 2 { return app.weeklySession.flatMap(\.lapTimes) }
        return result.lapTimes
    }

    private var lapsBlock: some View {
        let laps = lapTimes
        let best = laps.min() ?? 0
        return VStack(spacing: 6) {
            ForEach(Array(laps.enumerated()), id: \.offset) { i, t in
                HStack {
                    Circle().fill(Theme.echoColor(lap: i + 1)).frame(width: 10, height: 10)
                    Text(lapTitle(i)).font(Theme.rounded(.callout, .semibold)).foregroundStyle(Theme.muted)
                    Spacer()
                    if t == best && laps.count > 1 {
                        Text("BEST").font(Theme.rounded(.caption2, .black)).foregroundStyle(Theme.good)
                    }
                    Text(TimeFormat.race(t)).font(Theme.rounded(.callout, .heavy)).monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(lapTitle(i)), \(TimeFormat.spoken(t))" + (t == best && laps.count > 1 ? ", best lap" : ""))
            }
        }
        .padding(14)
        .background(Theme.raised.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    private func lapTitle(_ i: Int) -> String {
        if def.mode == .weekly, case .weekly(let n) = request.kind, n == 2 {
            let perRace = max(1, def.laps)
            return "Race \(i / perRace + 1) · lap \(i % perRace + 1)"
        }
        return "Lap \(i + 1)"
    }

    private func medalBlock(_ medal: Medal) -> some View {
        let earned = summary?.medalEarned ?? medal.isEarned(by: result.stats, laps: def.laps)
        return HStack(spacing: 12) {
            Image(systemName: earned ? "medal.fill" : "medal").font(.title).foregroundStyle(earned ? Theme.good : Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(earned ? (summary?.medalIsNew == true ? "Medal earned: \(medal.title)" : "Medal: \(medal.title) ✓") : "Medal: \(medal.title)")
                    .font(Theme.rounded(.headline, .heavy))
                Text(medal.goal(laps: def.laps)).font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.raised.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Rewards and unlocks

    private func rewardsBlock(_ s: RewardSummary) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(s.lines.enumerated()), id: \.offset) { _, line in
                HStack {
                    Text(line.title).font(Theme.rounded(.callout, .semibold))
                    Spacer()
                    Label("+\(line.sparks)", systemImage: "sparkle").font(Theme.rounded(.callout, .heavy)).foregroundStyle(Theme.spark)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(line.title), plus \(line.sparks) Sparks")
            }
            if !s.lines.isEmpty { Divider().overlay(Theme.line) }
            HStack {
                Label("+\(s.xpGained) XP", systemImage: "chevron.up.2").font(Theme.rounded(.callout, .heavy)).foregroundStyle(Theme.accent)
                Spacer()
                Label("\(app.progress.sparks)", systemImage: "sparkle").font(Theme.rounded(.callout, .heavy)).foregroundStyle(Theme.spark)
                    .accessibilityLabel("\(app.progress.sparks) Sparks in total")
            }
            if s.leveledUp {
                Label("Level \(s.levelAfter) · \(Economy.title(forLevel: s.levelAfter))", systemImage: "arrow.up.circle.fill")
                    .font(Theme.rounded(.headline, .black))
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.gold.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(Theme.raised.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func unlocksBlock(_ s: RewardSummary) -> some View {
        let items = unlockItems(s)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.text) { item in
                    Label(item.text, systemImage: item.icon)
                        .font(Theme.rounded(.callout, .bold))
                        .foregroundStyle(item.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine)
        }
    }

    private struct UnlockItem { let text: String; let icon: String; let color: Color }

    private func unlockItems(_ s: RewardSummary) -> [UnlockItem] {
        var items: [UnlockItem] = []
        for world in s.unlockedWorlds { items.append(UnlockItem(text: "New world open: \(world.name)", icon: "globe", color: Theme.worldColor(world))) }
        for car in s.unlockedCars { items.append(UnlockItem(text: "New racer: \(car.name)", icon: "car.side.fill", color: Theme.accent)) }
        if s.survivalUnlocked { items.append(UnlockItem(text: "Echo Survival is open", icon: "heart.fill", color: Theme.bad)) }
        if s.weeklyUnlocked { items.append(UnlockItem(text: "The weekly gauntlet is open", icon: "flag.2.crossed.fill", color: Theme.echo[1])) }
        for goal in s.goalsCompleted { items.append(UnlockItem(text: "Goal done: \(goal.title)", icon: "checkmark.circle.fill", color: Theme.good)) }
        for a in s.newAchievements { items.append(UnlockItem(text: "Achievement: \(a.title)", icon: "trophy.fill", color: Theme.gold)) }
        if s.dailyStreak > 1, def.mode == .daily { items.append(UnlockItem(text: "Daily streak: \(s.dailyStreak) days", icon: "flame.fill", color: Theme.accent)) }
        return items
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if let primary = primaryAction {
                Button(action: primary.action) {
                    Label(primary.title, systemImage: primary.icon).font(Theme.rounded(.headline, .heavy)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .primaryButtonStyle()
                .controlSize(.large)
                .accessibilityIdentifier("resultsPrimary")
            }
            HStack(spacing: 10) {
                ForEach(secondaryActions, id: \.title) { action in
                    Button(action: action.action) {
                        Label(action.title, systemImage: action.icon).font(Theme.rounded(.subheadline, .bold)).frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .secondaryButtonStyle()
                    .controlSize(.large)
                    .accessibilityIdentifier("results" + action.id)
                }
            }
        }
    }

    private struct Action {
        let id: String
        let title: String
        let icon: String
        let action: () -> Void
    }

    private var nextCareerTrack: TrackDef? {
        guard def.mode == .career, let next = Catalog.next(after: def), app.progress.isUnlocked(next) else { return nil }
        return next
    }

    private var primaryAction: Action? {
        if outcome.isTutorial {
            return Action(id: "Continue", title: "Continue", icon: "arrow.right") { app.goHome() }
        }
        switch request.kind {
        case .weekly(let n) where n < 2 && result.finished:
            return Action(id: "Next", title: "Race \(n + 2) of 3", icon: "arrow.right") { app.continueWeekly(after: n) }
        case .weekly:
            return Action(id: "Retry", title: "Try the gauntlet again", icon: "arrow.counterclockwise") { app.restart(request) }
        case .survival:
            return Action(id: "Retry", title: "Run again", icon: "arrow.counterclockwise") { app.restart(request) }
        case .daily:
            return Action(id: "Retry", title: "Race again", icon: "arrow.counterclockwise") { app.restart(request) }
        default:
            if let next = nextCareerTrack, result.finished {
                return Action(id: "Next", title: "Next: \(next.label)", icon: "arrow.right") { app.play(next) }
            }
            return Action(id: "Retry", title: "Retry", icon: "arrow.counterclockwise") { app.restart(request) }
        }
    }

    private var secondaryActions: [Action] {
        if outcome.isTutorial {
            return [Action(id: "Again", title: "Race again", icon: "arrow.counterclockwise") { app.play(def) }]
        }
        var list: [Action] = []
        if case .career = request.kind, nextCareerTrack != nil, result.finished {
            list.append(Action(id: "Retry", title: "Retry", icon: "arrow.counterclockwise") { app.restart(request) })
        }
        list.append(Action(id: "Menu", title: "Menu", icon: "house.fill") { app.goHome() })
        return list
    }
}
