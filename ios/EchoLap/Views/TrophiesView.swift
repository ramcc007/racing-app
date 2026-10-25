import SwiftUI
import EchoLapCore

/// Achievements, records and (when signed in) Game Center leaderboards.
struct TrophiesView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var gameCenter = GameCenterService.shared
    @State private var tab = 0

    private var progress: PlayerProgress { app.progress }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Show", selection: $tab) {
                    Text("Achievements").tag(0)
                    Text("Records").tag(1)
                }
                .pickerStyle(.segmented)
                if gameCenter.signedIn {
                    HStack(spacing: 10) {
                        Button { gameCenter.openDashboard(.daily) } label: {
                            Label("Leaderboards", systemImage: "list.number").font(Theme.rounded(.subheadline, .bold)).frame(maxWidth: .infinity)
                        }
                        Button { gameCenter.openDashboard() } label: {
                            Label("Game Center", systemImage: "gamecontroller.fill").font(Theme.rounded(.subheadline, .bold)).frame(maxWidth: .infinity)
                        }
                    }
                    .secondaryButtonStyle()
                    .controlSize(.large)
                }
                if tab == 0 { achievements } else { records }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(MenuBackground(tint: Theme.gold))
        .navigationTitle("Trophies")
    }

    private var achievements: some View {
        let unlocked = Achievement.all.filter { progress.achievements.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Achievements", trailing: "\(unlocked) / \(Achievement.all.count)")
            ForEach(Achievement.all) { a in
                let done = progress.achievements.contains(a.id)
                HStack(spacing: 12) {
                    Image(systemName: done ? "trophy.fill" : "trophy")
                        .font(.title3)
                        .foregroundStyle(done ? Theme.gold : Theme.muted.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .background((done ? Theme.gold : Theme.muted).opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.title).font(Theme.rounded(.headline, .heavy)).foregroundStyle(done ? Theme.text : Theme.muted)
                        Text(a.detail).font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .glassCard(cornerRadius: 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(a.title), \(a.detail)" + (done ? ", unlocked" : ", locked"))
            }
        }
    }

    private var records: some View {
        let s = progress.stats
        let rows: [(String, String, String)] = [
            ("star.fill", "Stars", "\(progress.totalStars) / 360"),
            ("medal.fill", "Medals", "\(progress.medalCount) / 120"),
            ("crown.fill", "Gold finishes", "\(s.golds)"),
            ("flag.checkered", "Races finished", "\(s.finishes) of \(s.races)"),
            ("repeat", "Laps driven", "\(s.laps)"),
            ("road.lanes", "Distance", String(format: "%.1f km", s.distance / 10_000)),   // a car is 40 units long, about 4 m
            ("wind", "Slipstreams", "\(s.drafts)"),
            ("bolt.fill", "Boosts", "\(s.boosts)"),
            ("arrow.left.arrow.right", "Relay swaps", "\(s.swaps)"),
            ("lock.open.fill", "Echo-held gates", "\(s.echoGatePasses)"),
            ("arrow.up.forward", "Jumps", "\(s.jumps)"),
            ("snowflake", "Ice broken", "\(s.iceBreaks)"),
            ("heart.fill", "Best survival", "\(progress.survivalBest) laps"),
            ("flame.fill", "Best daily streak", "\(progress.bestDailyStreak) days"),
            ("sparkle", "Sparks earned", "\(progress.sparksEarnedTotal)"),
            ("person.fill", "Driver level", "\(progress.level) · \(Economy.title(forLevel: progress.level))"),
        ]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack {
                    Label(row.1, systemImage: row.0).font(Theme.rounded(.callout, .semibold))
                    Spacer()
                    Text(row.2).font(Theme.rounded(.callout, .heavy)).monospacedDigit()
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                if i < rows.count - 1 { Divider().overlay(Theme.line) }
            }
        }
        .padding(.horizontal, 16)
        .glassCard(cornerRadius: 22)
    }
}
