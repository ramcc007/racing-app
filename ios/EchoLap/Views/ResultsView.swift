import SwiftUI
import StoreKit
import EchoLapCore

/// After a sprint: time, stars, the rival's verdict, the echo ladder, every Spark earned, and a huge GO AGAIN.
struct ResultsView: View {
    let outcome: RaceController.Outcome
    let request: RaceRequest
    let rival: Rival
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
                    VStack(spacing: 14) {
                        header
                        if def.mode == .career, result.finished { starsBlock }
                        if def.mode == .career || def.mode == .daily, result.finished, let summary { ladderBlock(summary) }
                        if def.mode != .survival { skillsRow }
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
                    Text(summary.newBest ? "NEW BEST \u{00B7} \(TimeFormat.delta(diff))" : "Best \(TimeFormat.race(previous)) \u{00B7} \(TimeFormat.delta(diff))")
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
            return stars >= 3 ? "GOLD!" : (stars == 2 ? "Silver" : "Finished")
        }
    }

    /// The weekly result shows the gauntlet's total time once all three races are done.
    private var displayTime: Double {
        if case .weekly(let n) = request.kind, n == 2 { return app.weeklySession.reduce(0) { $0 + $1.totalTime } }
        return result.totalTime
    }

    // MARK: - Stars and the rival

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
                let gap = result.totalTime - targets.gold
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.side.fill").foregroundStyle(Color(hex: rival.color))
                        Text("\(rival.name): \u{201C}\(gap <= 0 ? rival.beaten : rival.won)\u{201D}")
                            .font(Theme.rounded(.subheadline, .heavy)).italic()
                            .foregroundStyle(Color(hex: rival.color))
                    }
                    Text(gap <= 0 ? String(format: "You beat %@ by %.2f s", rival.name, -gap) : String(format: "%@ finished %.2f s ahead", rival.name, gap))
                        .font(Theme.rounded(.footnote, .bold)).foregroundStyle(Theme.text)
                    if stars < 3 {
                        Text(stars == 2 ? "Beat \(rival.name) for 3 stars: \(TimeFormat.race(targets.gold))"
                                        : "Silver: \(TimeFormat.race(targets.silver)) \u{00B7} Gold: \(TimeFormat.race(targets.gold))")
                            .font(Theme.rounded(.footnote, .bold)).foregroundStyle(Theme.muted)
                        Text(tip).font(Theme.rounded(.caption, .medium)).foregroundStyle(Theme.muted)
                    }
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 4)
    }

    private var tip: String {
        let s = result.stats
        if s.driftBoosts < 2 { return "Tip: hold the turn hard through corners and let go for a boost." }
        if s.bumps > 0 { return "Tip: a touch costs the whole nitro meter. Pass echoes by a whisker instead." }
        if s.boosts == 0 { return "Tip: swipe up on a straight to fire the nitro." }
        return "Tip: ride the edge of the road on straights to fill the nitro."
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

    // MARK: - Echo ladder, skills, medal

    private func ladderBlock(_ s: RewardSummary) -> some View {
        HStack(spacing: 12) {
            LadderDots(rung: s.rungAfter, mastered: app.progress.tracks[def.id]?.mastered ?? false, size: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.mastered ? "Track mastered!" : (s.climbedRung ? "Echo ladder: rung \(s.rungAfter)" : "Echo ladder: rung \(s.rungAfter)"))
                    .font(Theme.rounded(.headline, .heavy))
                    .foregroundStyle(s.mastered ? Theme.gold : Theme.text)
                Text(ladderText(s)).font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.raised.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ladder")
    }

    private func ladderText(_ s: RewardSummary) -> String {
        if s.mastered { return "Five of your runs beaten with gold. Nothing left to prove here." }
        if s.rungAfter >= TrackRecord.topRung { return "Five echoes on the road. Gold here masters the track." }
        if s.climbedRung { return "New best: this run joins the road as an echo. Beat all of you next time." }
        return "Beat your best to put another echo on the road."
    }

    private var skillsRow: some View {
        let s = result.stats
        return HStack(spacing: 8) {
            SkillChip(value: s.driftBoosts, label: "drift boosts", color: Theme.driftColor(2))
            SkillChip(value: s.nearMisses, label: "near misses", color: Theme.good)
            SkillChip(value: s.boosts, label: "nitros", color: Theme.accent)
        }
        .accessibilityElement(children: .combine)
    }

    private func medalBlock(_ medal: Medal) -> some View {
        let earned = summary?.medalEarned ?? medal.isEarned(by: result.stats)
        return HStack(spacing: 12) {
            Image(systemName: earned ? "medal.fill" : "medal").font(.title).foregroundStyle(earned ? Theme.good : Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(earned ? (summary?.medalIsNew == true ? "Medal earned: \(medal.title)" : "Medal: \(medal.title) ✓") : "Medal: \(medal.title)")
                    .font(Theme.rounded(.headline, .heavy))
                Text(medal.detail).font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
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
            Button(action: primary.action) {
                Label(primary.title, systemImage: primary.icon)
                    .font(Theme.rounded(.title2, .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .primaryButtonStyle()
            .controlSize(.large)
            .accessibilityIdentifier("results" + primary.id)
            HStack(spacing: 10) {
                ForEach(secondaryActions, id: \.id) { action in
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

    private var again: Action {
        Action(id: "Again", title: "GO AGAIN", icon: "arrow.counterclockwise") { app.restart(request) }
    }

    /// GO AGAIN is always the big button: the loop is the game. A gauntlet in progress moves on instead.
    private var primary: Action {
        if case .weekly(let n) = request.kind, n < 2, result.finished {
            return Action(id: "Next", title: "Race \(n + 2) of 3", icon: "arrow.right") { app.continueWeekly(after: n) }
        }
        return again
    }

    private var secondaryActions: [Action] {
        var list: [Action] = []
        if let next = nextCareerTrack, result.finished {
            list.append(Action(id: "Next", title: "Next: \(next.label)", icon: "arrow.right") { app.play(next) })
        }
        list.append(Action(id: "Menu", title: "Menu", icon: "house.fill") { app.goHome() })
        return list
    }
}

/// A run's skill count, as a small chip.
struct SkillChip: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(Theme.rounded(.title3, .black)).foregroundStyle(color).monospacedDigit()
            Text(label).font(Theme.rounded(.caption2, .bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.raised.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }
}
