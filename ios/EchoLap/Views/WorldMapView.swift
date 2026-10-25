import SwiftUI
import EchoLapCore

extension Feature {
    var displayName: String {
        switch self {
        case .softEchoes: return "Soft echoes"
        case .sand: return "Sand"
        case .pads: return "Echo pads"
        case .thinIce: return "Thin ice"
        case .relay: return "Relay swap"
        case .sensors: return "Sensor bridge"
        case .wind: return "Crosswind"
        case .jumps: return "Jumps"
        }
    }

    var icon: String {
        switch self {
        case .softEchoes: return "circle.dashed"
        case .sand: return "aqi.medium"
        case .pads: return "parkingsign.circle.fill"
        case .thinIce: return "snowflake"
        case .relay: return "arrow.left.arrow.right"
        case .sensors: return "sensor.fill"
        case .wind: return "wind"
        case .jumps: return "arrow.up.forward"
        }
    }
}

/// One world: its rule, its medal and its fifteen tracks.
struct WorldMapView: View {
    let world: World
    @EnvironmentObject private var app: AppModel
    @State private var detail: TrackDef?

    private var progress: PlayerProgress { app.progress }
    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12)]

    var body: some View {
        let unlocked = progress.isUnlocked(world)
        let stars = progress.stars(in: world)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WORLD \(world.rawValue)").font(Theme.rounded(.caption, .heavy)).tracking(2).foregroundStyle(Theme.worldColor(world))
                    Text(world.name).font(Theme.rounded(.largeTitle, .black)).accessibilityAddTraits(.isHeader)
                    HStack(spacing: 10) {
                        ProgressView(value: Double(stars), total: 45).tint(Theme.gold)
                        Text("\(stars) / 45 ★").font(Theme.rounded(.subheadline, .heavy)).foregroundStyle(Theme.gold).monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stars) of 45 stars")
                }
                if !unlocked {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill").font(.title2)
                        Text("Earn \(world.starsToUnlock - progress.totalStars) more stars to open \(world.name). Stars come from beating the target times on open tracks.")
                            .font(Theme.rounded(.callout, .medium))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 20, tint: Theme.worldColor(world))
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label(world.ruleTitle, systemImage: "lightbulb.fill").font(Theme.rounded(.headline, .heavy))
                    Text(world.ruleText).font(Theme.rounded(.callout, .medium)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider().overlay(Theme.line)
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("World medal: \(world.medal.title)").font(Theme.rounded(.subheadline, .heavy))
                            Text(world.medal.goal).font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
                        }
                    } icon: {
                        Image(systemName: "medal.fill").foregroundStyle(Theme.good)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 22)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Catalog.tracks(in: world)) { def in
                        TrackTile(def: def, record: progress.tracks[def.id], unlocked: progress.isUnlocked(def))
                            .onTapGesture {
                                Haptics.tap()
                                if progress.isUnlocked(def) {
                                    detail = def
                                } else if !unlocked {
                                    app.showToast("\(world.name) opens at \(world.starsToUnlock) stars.")
                                } else {
                                    app.showToast("Finish \(world.rawValue)-\(def.slot - 1) to open this track.")
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("track\(def.id)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(MenuBackground(tint: Theme.worldColor(world)))
        .navigationTitle(world.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { def in TrackDetailView(def: def) }
        .task {
            if unlocked { app.prefetch([progress.nextTrack].filter { $0.world == world }) }
        }
    }
}

struct TrackTile: View {
    let def: TrackDef
    let record: TrackRecord?
    let unlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(def.label).font(Theme.rounded(.headline, .black)).monospacedDigit()
                Spacer()
                if def.kind == .boss {
                    Image(systemName: "crown.fill").foregroundStyle(Theme.gold).accessibilityHidden(true)
                } else if def.kind == .breather {
                    Image(systemName: "leaf.fill").foregroundStyle(Theme.good).accessibilityHidden(true)
                }
            }
            Text(def.name).font(Theme.rounded(.footnote, .semibold)).foregroundStyle(Theme.muted).lineLimit(2, reservesSpace: true)
            HStack {
                if unlocked {
                    StarsView(count: record?.stars ?? 0, size: 13)
                    Spacer()
                    if record?.medal == true { Image(systemName: "medal.fill").font(.caption).foregroundStyle(Theme.good) }
                    if let record { LadderDots(rung: record.rung, mastered: record.mastered, size: 6) }
                } else {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(Theme.muted)
                    Spacer()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .glassCard(cornerRadius: 18, tint: record == nil && unlocked ? Theme.worldColor(def.world) : nil)
        .opacity(unlocked ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "Track \(def.label), \(def.name)"
        if def.kind == .boss { text += ", boss track" }
        if def.kind == .breather { text += ", short track" }
        guard unlocked else { return text + ", locked" }
        if let record {
            text += ", \(record.stars) of 3 stars, best \(TimeFormat.spoken(record.bestTime)), ladder rung \(record.rung)"
            if record.medal { text += ", medal earned" }
            if record.mastered { text += ", mastered" }
        } else {
            text += ", not raced yet"
        }
        return text
    }
}
