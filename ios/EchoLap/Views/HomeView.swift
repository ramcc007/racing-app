import SwiftUI
import EchoLapCore

enum HomeDestination: Hashable {
    case world(World)
    case garage
    case trophies
    case settings
}

/// The menu hub: navigation stack for worlds, garage, trophies and settings.
struct HomeRoot: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .world(let world): WorldMapView(world: world)
                    case .garage: GarageView()
                    case .trophies: TrophiesView()
                    case .settings: SettingsView()
                    }
                }
        }
        .onAppear {
            GameCenterService.shared.showAccessPoint(true)
            #if DEBUG
            if let destination = ScreenshotScene.pendingDestination {
                ScreenshotScene.pendingDestination = nil
                path.append(destination)
            }
            #endif
        }
        .onDisappear { GameCenterService.shared.showAccessPoint(false) }
    }
}

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var path: NavigationPath
    @State private var detail: TrackDef?
    @State private var showDaily = false
    @State private var showSurvival = false
    @State private var showWeekly = false
    @State private var nextBuilt: BuiltTrack?

    private var progress: PlayerProgress { app.progress }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                continueCard
                modes
                worlds
                HStack(spacing: 12) {
                    menuButton("Garage", "car.side.fill", .garage, id: "garage")
                    menuButton("Trophies", "trophy.fill", .trophies, id: "trophies")
                }
                LinkRow()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(MenuBackground(tint: Theme.worldColor(progress.nextTrack.world)))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { path.append(HomeDestination.settings) } label: { Image(systemName: "gearshape.fill") }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settings")
            }
        }
        .navigationTitle("")
        .sheet(item: $detail) { def in TrackDetailView(def: def) }
        .sheet(isPresented: $showDaily) { DailyView() }
        .sheet(isPresented: $showSurvival) { SurvivalView() }
        .sheet(isPresented: $showWeekly) { WeeklyView() }
        .onAppear {
            #if DEBUG
            if ScreenshotScene.pendingDaily {
                ScreenshotScene.pendingDaily = false
                showDaily = true
            }
            #endif
        }
        .task(id: progress.nextTrack.id) {
            nextBuilt = await app.build(progress.nextTrack)
            app.prefetch([Catalog.daily(app.today)] + (Catalog.next(after: progress.nextTrack).map { [$0] } ?? []))
        }
    }

    // MARK: - Pieces

    private var header: some View {
        let level = progress.level
        let start = Economy.xpForLevel(level), end = Economy.xpForLevel(level + 1)
        let fraction = Double(progress.xp - start) / Double(max(1, end - start))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.2))
                    Text("\(level)").font(Theme.rounded(.title2, .black)).foregroundStyle(Theme.accent)
                }
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Economy.title(forLevel: level)).font(Theme.rounded(.headline, .heavy))
                    ProgressView(value: fraction).tint(Theme.accent)
                    Text("\(progress.xp - start) / \(end - start) XP to level \(level + 1)")
                        .font(Theme.rounded(.caption, .medium)).foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Driver level \(level), \(Economy.title(forLevel: level)). \(end - progress.xp) XP to the next level.")
            }
            HStack(spacing: 10) {
                CounterPill(systemImage: "star.fill", value: "\(progress.totalStars)", color: Theme.gold, label: "stars")
                CounterPill(systemImage: "sparkle", value: "\(progress.sparks)", color: Theme.spark, label: "Sparks")
                CounterPill(systemImage: "medal.fill", value: "\(progress.medalCount)", color: Theme.good, label: "medals")
                CounterPill(systemImage: "chart.bar.fill", value: "\(progress.masteredCount)", color: Theme.echo[1], label: "mastered")
            }
        }
        .padding(.top, 6)
    }

    private var continueCard: some View {
        let def = progress.nextTrack
        let record = progress.tracks[def.id]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record == nil ? "NEXT UP" : "IMPROVE").font(Theme.rounded(.caption, .heavy)).tracking(2).foregroundStyle(Theme.worldColor(def.world))
                    Text(def.name).font(Theme.rounded(.title, .black))
                    Text("\(def.label) · \(def.world.name) · rival \(def.world.rival.name)").font(Theme.rounded(.subheadline, .medium)).foregroundStyle(Theme.muted)
                    if let record {
                        HStack(spacing: 10) {
                            StarsView(count: record.stars, size: 16)
                            LadderDots(rung: record.rung, mastered: record.mastered, size: 10)
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer()
                Group {
                    if let nextBuilt, nextBuilt.track.def.id == def.id {
                        TrackPreview(track: nextBuilt.track, lineWidth: 5)
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 110, height: 90)
            }
            Button {
                app.play(def)
            } label: {
                Label(record == nil ? "Race" : "Beat your best", systemImage: "flag.checkered").font(Theme.rounded(.title3, .heavy)).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .primaryButtonStyle()
            .controlSize(.large)
            .accessibilityIdentifier("continueRace")
        }
        .padding(18)
        .glassCard(cornerRadius: 26, tint: Theme.worldColor(def.world))
        .contentShape(Rectangle())
        .onTapGesture { detail = def }
        .accessibilityElement(children: .contain)
    }

    private var modes: some View {
        let today = app.today
        let daily = progress.daily[today.string]
        let goals = progress.goals?.day == today.string ? progress.goals : nil
        let goalsDone = goals.map { g in g.goals.indices.filter { g.isDone($0) }.count } ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Play")
            ModeCard(title: "Daily track", subtitle: daily.map { "Best \(TimeFormat.race($0.bestTime))" } ?? "Same track for everyone today",
                     detail: "Streak \(progress.dailyStreak) · goals \(goalsDone)/3", icon: "calendar", color: Theme.accent, locked: false) {
                showDaily = true
            }
            .accessibilityIdentifier("dailyCard")
            let layout = sizeClass == .regular ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))
            layout {
                ModeCard(title: "Echo Survival", subtitle: progress.survivalUnlocked ? "Best \(progress.survivalBest) laps" : "Finish 1-5 to open",
                         detail: nil, icon: "heart.fill", color: Theme.bad, locked: !progress.survivalUnlocked) { showSurvival = true }
                    .accessibilityIdentifier("survivalCard")
                ModeCard(title: "Gauntlet", subtitle: progress.weeklyUnlocked ? "3 tracks · this week" : "Opens at \(Catalog.weeklyUnlockStars)★",
                         detail: nil, icon: "flag.2.crossed.fill", color: Color(hex: 0x56B4E9), locked: !progress.weeklyUnlocked) { showWeekly = true }
                    .accessibilityIdentifier("weeklyCard")
            }
        }
    }

    private var worlds: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Worlds", trailing: "\(progress.totalStars) / 360 ★")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(World.allCases) { world in
                        WorldTile(world: world, stars: progress.stars(in: world), unlocked: progress.isUnlocked(world))
                            .onTapGesture {
                                Haptics.tap()
                                path.append(HomeDestination.world(world))
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("world\(world.rawValue)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func menuButton(_ title: String, _ icon: String, _ destination: HomeDestination, id: String) -> some View {
        Button {
            Haptics.tap()
            path.append(destination)
        } label: {
            Label(title, systemImage: icon).font(Theme.rounded(.headline, .bold)).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .secondaryButtonStyle()
        .controlSize(.large)
        .accessibilityIdentifier(id)
    }
}

struct ModeCard: View {
    let title: String
    let subtitle: String
    let detail: String?
    let icon: String
    let color: Color
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 12) {
                Image(systemName: locked ? "lock.fill" : icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(locked ? Theme.muted : color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.rounded(.headline, .heavy)).foregroundStyle(Theme.text)
                    Text(subtitle).font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted).lineLimit(2)
                    if let detail { Text(detail).font(Theme.rounded(.caption, .semibold)).foregroundStyle(color) }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .glassCard(cornerRadius: 20)
            .opacity(locked ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }
}

struct WorldTile: View {
    let world: World
    let stars: Int
    let unlocked: Bool

    var body: some View {
        let style = WorldStyle.of(world)
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(hex: style.ground))
                Canvas { context, size in
                    var p = Path()
                    p.move(to: CGPoint(x: -10, y: size.height * 0.75))
                    p.addCurve(to: CGPoint(x: size.width + 10, y: size.height * 0.3),
                               control1: CGPoint(x: size.width * 0.3, y: size.height * 0.1), control2: CGPoint(x: size.width * 0.6, y: size.height * 1.0))
                    context.stroke(p, with: .color(Color(hex: style.kerbB)), lineWidth: 16)
                    context.stroke(p, with: .color(Color(hex: style.asphalt)), lineWidth: 12)
                }
                if !unlocked {
                    Color.black.opacity(0.45)
                    Image(systemName: "lock.fill").font(.title2).foregroundStyle(.white)
                }
            }
            .frame(width: 150, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("\(world.rawValue). \(world.name)").font(Theme.rounded(.subheadline, .heavy)).lineLimit(1)
            Text(unlocked ? "\(stars) / 45 ★" : "Opens at \(world.starsToUnlock) ★")
                .font(Theme.rounded(.caption, .semibold)).foregroundStyle(unlocked ? Theme.gold : Theme.muted)
        }
        .frame(width: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("World \(world.rawValue), \(world.name). " + (unlocked ? "\(stars) of 45 stars" : "Locked, opens at \(world.starsToUnlock) stars"))
    }
}
