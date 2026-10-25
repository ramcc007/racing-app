import SwiftUI
import EchoLapCore

/// A track's card: shape, rules, the rival and the star times, the medal, your best and your echo ladder.
struct TrackDetailView: View {
    let def: TrackDef
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var built: BuiltTrack?

    var body: some View {
        let record = app.progress.tracks[def.id]
        let rival = def.world.rival
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: WorldStyle.of(def.world).ground).opacity(0.25))
                        if let built {
                            TrackPreview(track: built.track, lineWidth: 9).padding(18)
                        } else {
                            VStack(spacing: 10) {
                                ProgressView()
                                Text("Test-driving the track…").font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .frame(height: 230)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(def.label) · \(def.world.name)").font(Theme.rounded(.subheadline, .heavy)).foregroundStyle(Theme.worldColor(def.world))
                        Text(def.name).font(Theme.rounded(.largeTitle, .black)).accessibilityAddTraits(.isHeader)
                        Text(subtitle).font(Theme.rounded(.callout, .medium)).foregroundStyle(Theme.muted)
                    }

                    if !def.features.isEmpty || def.world != .harbour {
                        FlowChips(features: def.features.sorted { $0.rawValue < $1.rawValue }, softEchoes: def.softEchoes)
                    }

                    VStack(spacing: 0) {
                        TargetRow(stars: 3, title: "Beat \(rival.name)", time: built?.targets.gold, achieved: (record?.stars ?? 0) >= 3)
                        Divider().overlay(Theme.line)
                        TargetRow(stars: 2, title: "Silver", time: built?.targets.silver, achieved: (record?.stars ?? 0) >= 2)
                        Divider().overlay(Theme.line)
                        TargetRow(stars: 1, title: "Finish", time: nil, achieved: record != nil)
                    }
                    .padding(.horizontal, 14)
                    .glassCard(cornerRadius: 20)

                    HStack(alignment: .top, spacing: 12) {
                        LadderDots(rung: record?.rung ?? 0, mastered: record?.mastered ?? false, size: 16)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record?.mastered == true ? "Track mastered" : "Echo ladder: rung \(record?.rung ?? 0) of \(TrackRecord.topRung)")
                                .font(Theme.rounded(.headline, .heavy))
                                .foregroundStyle(record?.mastered == true ? Theme.gold : Theme.text)
                            Text(ladderText(record)).font(Theme.rounded(.callout, .medium)).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 20)
                    .accessibilityElement(children: .combine)

                    if let medal = def.medal {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: record?.medal == true ? "medal.fill" : "medal")
                                .font(.title2).foregroundStyle(record?.medal == true ? Theme.good : Theme.muted)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Medal: \(medal.title)").font(Theme.rounded(.headline, .heavy))
                                Text(medal.detail).font(Theme.rounded(.callout, .medium)).foregroundStyle(Theme.muted)
                                Text(record?.medal == true ? "Earned" : "+\(Economy.medalSparks) Sparks the first time")
                                    .font(Theme.rounded(.caption, .bold)).foregroundStyle(record?.medal == true ? Theme.good : Theme.spark)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 20)
                        .accessibilityElement(children: .combine)
                    }

                    if let record {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Your best").font(Theme.rounded(.headline, .heavy))
                                Spacer()
                                Text(TimeFormat.race(record.bestTime)).font(Theme.timer(22))
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Your best, \(TimeFormat.spoken(record.bestTime))")
                            let runs = app.savedRuns(for: def.id)
                            ForEach(Array(runs.enumerated()), id: \.offset) { i, run in
                                HStack {
                                    Circle().fill(Theme.echoColor(lap: i + 1)).frame(width: 10, height: 10)
                                    Text("Echo \(i + 1)").font(Theme.rounded(.callout, .semibold)).foregroundStyle(Theme.muted)
                                    Spacer()
                                    Text(TimeFormat.race(run.totalTime)).font(Theme.rounded(.callout, .bold)).monospacedDigit()
                                }
                                .accessibilityElement(children: .combine)
                            }
                            Text("Played \(record.plays) \(record.plays == 1 ? "time" : "times")")
                                .font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 20)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(MenuBackground(tint: Theme.worldColor(def.world)))
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    app.play(def)
                } label: {
                    Label(record == nil ? "Race" : "Race again", systemImage: "flag.checkered")
                        .font(Theme.rounded(.title3, .heavy)).frame(maxWidth: 520).padding(.vertical, 6)
                }
                .primaryButtonStyle()
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .accessibilityIdentifier("raceTrack")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("closeDetail")
                }
            }
        }
        .task { built = await app.build(def) }
    }

    private var subtitle: String {
        var parts = ["one sprint"]
        if def.kind == .boss { parts.append("boss track") }
        if def.kind == .breather { parts.append("short track") }
        parts.append("rival: \(def.world.rival.name)")
        parts.append(def.softEchoes ? "echoes are soft here" : "echoes are solid")
        return parts.joined(separator: " · ")
    }

    private func ladderText(_ record: TrackRecord?) -> String {
        guard let record else { return "Finish once and your run comes back as an echo. Every new best adds another, up to five." }
        if record.mastered { return "Five of your runs beaten with gold. Nothing left to prove here." }
        if record.rung >= TrackRecord.topRung { return "Five echoes race you here. Beat the rival to master the track." }
        return "\(record.rung) \(record.rung == 1 ? "echo races" : "echoes race") you here. A new best adds another."
    }
}

struct TargetRow: View {
    let stars: Int
    let title: String
    let time: Double?
    let achieved: Bool

    var body: some View {
        HStack {
            StarsView(count: stars, size: 13).opacity(achieved ? 1 : 0.6)
            Text(title).font(Theme.rounded(.callout, .bold))
            Spacer()
            if let time {
                Text(TimeFormat.race(time)).font(Theme.rounded(.callout, .heavy)).monospacedDigit()
            } else if stars == 1 {
                Text("Any time").font(Theme.rounded(.callout, .semibold)).foregroundStyle(Theme.muted)
            } else {
                ProgressView().controlSize(.small)
            }
            Image(systemName: achieved ? "checkmark.circle.fill" : "circle").foregroundStyle(achieved ? Theme.good : Theme.muted)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stars) \(stars == 1 ? "star" : "stars"), \(title): " + (time.map { "beat \(TimeFormat.spoken($0))" } ?? "finish the race")
                            + (achieved ? ", done" : ""))
    }
}

/// The rule chips under a track title.
struct FlowChips: View {
    let features: [Feature]
    let softEchoes: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) { chips }
        }
    }

    @ViewBuilder private var chips: some View {
        if !softEchoes { chip("Solid echoes", "car.2.fill") }
        ForEach(features, id: \.self) { f in chip(f.displayName, f.icon) }
    }

    private func chip(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(Theme.rounded(.footnote, .bold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.raised, in: Capsule())
    }
}
