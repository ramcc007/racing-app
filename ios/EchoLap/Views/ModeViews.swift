import SwiftUI
import EchoLapCore

/// The daily track: the same circuit for everyone today, a streak, and three goals.
struct DailyView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var gameCenter = GameCenterService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var built: BuiltTrack?

    var body: some View {
        let today = app.today
        let def = Catalog.daily(today)
        let record = app.progress.daily[today.string]
        let goals = app.progress.goals?.day == today.string ? app.progress.goals : nil
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ModeHeader(built: built, def: def, eyebrow: today.shortLabel.uppercased(), title: "Daily track",
                               subtitle: "\(def.world.name) · \(def.laps) laps · \(Self.timeLeft())")
                    HStack(spacing: 12) {
                        StatTile(title: "Today's best", value: record.map { TimeFormat.race($0.bestTime) } ?? "–", icon: "stopwatch.fill")
                        StatTile(title: "Streak", value: "\(app.progress.dailyStreak) \(app.progress.dailyStreak == 1 ? "day" : "days")", icon: "flame.fill")
                    }
                    Text("First finish today pays \(Economy.dailyFirstFinishSparks) Sparks plus \(Economy.dailyStreakSparks) per streak day (up to \(Economy.dailyStreakCap) days). Best streak: \(app.progress.bestDailyStreak).")
                        .font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
                    if let goals {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(text: "Today's goals", trailing: goals.allDone ? "All done" : "+\(Economy.allGoalsBonus) bonus for all 3")
                            ForEach(goals.goals.indices, id: \.self) { i in
                                GoalRow(goal: goals.goals[i], progress: goals.progress[i], done: goals.isDone(i))
                            }
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 22)
                    }
                    if gameCenter.signedIn {
                        Button { gameCenter.openDashboard(.daily) } label: {
                            Label("Today's leaderboard", systemImage: "list.number").frame(maxWidth: .infinity)
                        }
                        .secondaryButtonStyle()
                        .controlSize(.large)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(MenuBackground(tint: Theme.worldColor(def.world)))
            .safeAreaInset(edge: .bottom) {
                RaceButton(title: record == nil ? "Race today's track" : "Race again", id: "raceDaily") {
                    dismiss()
                    app.playDaily()
                }
            }
            .toolbar { CloseToolbar { dismiss() } }
        }
        .task {
            app.update { _ = $0.goals(for: today) }
            built = await app.build(def)
        }
    }

    /// "New track in 5 h 12 min", until local midnight.
    static func timeLeft(now: Date = Date()) -> String {
        let calendar = Calendar.current
        guard let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) else { return "" }
        let minutes = max(1, Int(midnight.timeIntervalSince(now) / 60))
        return minutes >= 60 ? "new track in \(minutes / 60) h \(minutes % 60) min" : "new track in \(minutes) min"
    }
}

struct GoalRow: View {
    let goal: DailyGoal
    let progress: Int
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(done ? Theme.good : Theme.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title).font(Theme.rounded(.callout, .bold))
                if goal.target > 1 {
                    ProgressView(value: Double(min(progress, goal.target)), total: Double(goal.target)).tint(done ? Theme.good : Theme.accent)
                }
            }
            Spacer(minLength: 0)
            Label("\(Economy.goalSparks)", systemImage: "sparkle").font(Theme.rounded(.caption, .heavy)).foregroundStyle(Theme.spark)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal.title), " + (done ? "done" : "\(min(progress, goal.target)) of \(goal.target)") + ", \(Economy.goalSparks) Sparks")
    }
}

/// Echo Survival: laps never end, every lap adds a solid echo, three bumps and the run is over.
struct SurvivalView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var gameCenter = GameCenterService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var built: BuiltTrack?

    var body: some View {
        let def = Catalog.survival(app.today)
        let unlocked = app.progress.survivalUnlocked
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ModeHeader(built: built, def: def, eyebrow: "ENDLESS", title: "Echo Survival",
                               subtitle: "\(def.world.name) · track changes daily")
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Laps never end. Every lap you finish joins the track as a solid echo.", systemImage: "repeat")
                        Label("You have 3 lives. Each bump costs one.", systemImage: "heart.fill")
                        Label("\(Economy.survivalSparksPerLap) Sparks per lap, up to \(Economy.survivalSparksCap) a run.", systemImage: "sparkle")
                    }
                    .font(Theme.rounded(.callout, .semibold))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 22)
                    HStack(spacing: 12) {
                        StatTile(title: "Best run", value: "\(app.progress.survivalBest) laps", icon: "trophy.fill")
                        StatTile(title: "Runs", value: "\(app.progress.survivalRuns)", icon: "flag.checkered")
                    }
                    if gameCenter.signedIn {
                        Button { gameCenter.openDashboard(.survival) } label: {
                            Label("Survival leaderboard", systemImage: "list.number").frame(maxWidth: .infinity)
                        }
                        .secondaryButtonStyle()
                        .controlSize(.large)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(MenuBackground(tint: Theme.bad))
            .safeAreaInset(edge: .bottom) {
                if unlocked {
                    RaceButton(title: "Start a run", id: "raceSurvival") {
                        dismiss()
                        app.playSurvival()
                    }
                } else {
                    Text("Finish track \(Catalog.survivalUnlockTrack) to open Echo Survival.")
                        .font(Theme.rounded(.headline, .bold)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(.bar)
                }
            }
            .toolbar { CloseToolbar { dismiss() } }
        }
        .task { built = await app.build(def) }
    }
}

/// The weekly gauntlet: three tracks back to back, total time counts.
struct WeeklyView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var gameCenter = GameCenterService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var built: [String: BuiltTrack] = [:]

    var body: some View {
        let week = app.today.week
        let tracks = Catalog.weekly(week)
        let record = app.progress.weekly[week.string]
        let unlocked = app.progress.weeklyUnlocked
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THIS WEEK").font(Theme.rounded(.caption, .heavy)).tracking(2).foregroundStyle(Theme.echo[1])
                        Text("Gauntlet").font(Theme.rounded(.largeTitle, .black)).accessibilityAddTraits(.isHeader)
                        Text("Three tracks back to back. Your total time counts. New tracks every Monday.")
                            .font(Theme.rounded(.callout, .medium)).foregroundStyle(Theme.muted)
                    }
                    ForEach(Array(tracks.enumerated()), id: \.offset) { i, def in
                        HStack(spacing: 14) {
                            Group {
                                if let b = built[def.id] { TrackPreview(track: b.track, lineWidth: 4) } else { ProgressView() }
                            }
                            .frame(width: 84, height: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Race \(i + 1)").font(Theme.rounded(.headline, .heavy))
                                Text("\(def.world.name) · \(def.laps) laps").font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
                                if !def.features.isEmpty {
                                    Text(def.features.sorted { $0.rawValue < $1.rawValue }.map(\.displayName).joined(separator: ", "))
                                        .font(Theme.rounded(.caption, .bold)).foregroundStyle(Theme.worldColor(def.world))
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .glassCard(cornerRadius: 20)
                        .accessibilityElement(children: .combine)
                    }
                    HStack(spacing: 12) {
                        StatTile(title: "Best total", value: record?.bestTotal.map { TimeFormat.race($0) } ?? "–", icon: "stopwatch.fill")
                        StatTile(title: "Reward", value: record?.bestTotal == nil ? "\(Economy.weeklyCompleteSparks) Sparks" : "\(Economy.weeklyReplaySparks) Sparks",
                                 icon: "sparkle")
                    }
                    if gameCenter.signedIn {
                        Button { gameCenter.openDashboard(.weekly) } label: {
                            Label("This week's leaderboard", systemImage: "list.number").frame(maxWidth: .infinity)
                        }
                        .secondaryButtonStyle()
                        .controlSize(.large)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(MenuBackground(tint: Theme.echo[1]))
            .safeAreaInset(edge: .bottom) {
                if unlocked {
                    RaceButton(title: "Start the gauntlet", id: "raceWeekly") {
                        dismiss()
                        app.startWeekly()
                    }
                } else {
                    Text("Opens at \(Catalog.weeklyUnlockStars) stars (you have \(app.progress.totalStars)).")
                        .font(Theme.rounded(.headline, .bold)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(.bar)
                }
            }
            .toolbar { CloseToolbar { dismiss() } }
        }
        .task {
            for def in tracks { built[def.id] = await app.build(def) }
        }
    }
}

// MARK: - Shared pieces

struct ModeHeader: View {
    let built: BuiltTrack?
    let def: TrackDef
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: WorldStyle.of(def.world).ground).opacity(0.25))
                if let built { TrackPreview(track: built.track, lineWidth: 8).padding(18) } else { ProgressView() }
            }
            .frame(height: 200)
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow).font(Theme.rounded(.caption, .heavy)).tracking(2).foregroundStyle(Theme.worldColor(def.world))
                Text(title).font(Theme.rounded(.largeTitle, .black)).accessibilityAddTraits(.isHeader)
                Text(subtitle).font(Theme.rounded(.callout, .medium)).foregroundStyle(Theme.muted)
            }
            if !def.features.isEmpty {
                FlowChips(features: def.features.sorted { $0.rawValue < $1.rawValue }, softEchoes: def.softEchoes)
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(Theme.rounded(.caption, .bold)).foregroundStyle(Theme.muted)
            Text(value).font(Theme.rounded(.title3, .black)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}

struct RaceButton: View {
    let title: String
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "flag.checkered").font(Theme.rounded(.title3, .heavy)).frame(maxWidth: 520).padding(.vertical, 6)
        }
        .primaryButtonStyle()
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .accessibilityIdentifier(id)
    }
}

struct CloseToolbar: ToolbarContent {
    let action: () -> Void
    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: action)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("closeSheet")
        }
    }
}
