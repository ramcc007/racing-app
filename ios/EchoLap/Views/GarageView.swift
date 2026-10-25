import SwiftUI
import EchoLapCore

/// Racers (unlocked with stars) and cosmetics (bought with Sparks, which are only ever earned by playing).
struct GarageView: View {
    @EnvironmentObject private var app: AppModel
    @State private var focusedID: String = ""
    @State private var kind: Cosmetic.Kind = .paint
    @State private var pending: Cosmetic?

    private var progress: PlayerProgress { app.progress }
    private var focused: CarSpec { Cars.car(id: focusedID.isEmpty ? progress.selectedCar : focusedID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                carPicker
                carDetail
                cosmetics
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(MenuBackground())
        .navigationTitle("Garage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CounterPill(systemImage: "sparkle", value: "\(progress.sparks)", color: Theme.spark, label: "Sparks")
            }
        }
        .onAppear { if focusedID.isEmpty { focusedID = progress.selectedCar } }
        .confirmationDialog(pending.map { "Buy \($0.name)?" } ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible, presenting: pending) { item in
            Button("Buy for \(item.price) Sparks") { buy(item) }
            Button("Not now", role: .cancel) {}
        } message: { item in
            Text("You have \(progress.sparks) Sparks. Sparks are earned by racing; there is nothing to pay for in Echo Lap.")
        }
    }

    // MARK: - Racers

    private var carPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Racers", trailing: "\(Cars.all.filter(progress.isUnlocked).count) / \(Cars.all.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Cars.all) { car in
                        let unlocked = progress.isUnlocked(car)
                        let isFocused = car.id == focused.id
                        VStack(spacing: 8) {
                            ZStack {
                                CarPreview(car: car, paint: progress.paint(for: car)).frame(width: 46, height: 76)
                                if !unlocked {
                                    Image(systemName: "lock.fill").font(.title3).foregroundStyle(.white)
                                        .padding(8).background(.black.opacity(0.55), in: Circle())
                                }
                            }
                            .frame(height: 84)
                            Text(car.name).font(Theme.rounded(.subheadline, .heavy)).lineLimit(1)
                            if car.id == progress.selectedCar {
                                Text("Racing").font(Theme.rounded(.caption, .heavy)).foregroundStyle(Theme.good)
                            } else if !unlocked {
                                Text("\(car.starsToUnlock) ★").font(Theme.rounded(.caption, .heavy)).foregroundStyle(Theme.gold)
                            } else {
                                Text(" ").font(Theme.rounded(.caption, .heavy))
                            }
                        }
                        .frame(width: 104)
                        .padding(.vertical, 12)
                        .glassCard(cornerRadius: 20, tint: isFocused ? Theme.accent : nil)
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(isFocused ? Theme.accent : .clear, lineWidth: 2))
                        .opacity(unlocked ? 1 : 0.7)
                        .onTapGesture { Haptics.tap(); focusedID = car.id }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(car.name), \(car.role)" + (unlocked ? "" : ", opens at \(car.starsToUnlock) stars")
                                            + (car.id == progress.selectedCar ? ", racing" : ""))
                        .accessibilityAddTraits(isFocused ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("car-\(car.id)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var carDetail: some View {
        let car = focused
        let unlocked = progress.isUnlocked(car)
        let bars = car.bars
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(car.name).font(Theme.rounded(.title, .black))
                    Text(car.role).font(Theme.rounded(.callout, .semibold)).foregroundStyle(Theme.muted)
                }
                Spacer()
                CarPreview(car: car, paint: progress.paint(for: car)).frame(width: 52, height: 86)
            }
            StatBar(label: "Speed", value: bars.speed)
            StatBar(label: "Grip", value: bars.grip)
            StatBar(label: "Pickup", value: bars.accel)
            StatBar(label: "Draft", value: bars.draft)
            if car.id == progress.selectedCar {
                Label("You race with \(car.name)", systemImage: "checkmark.circle.fill")
                    .font(Theme.rounded(.headline, .bold)).foregroundStyle(Theme.good)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else if unlocked {
                Button {
                    Haptics.success()
                    Sound.play(.unlock, volume: 0.6)
                    app.update { $0.select(car) }
                } label: {
                    Text("Race with \(car.name)").font(Theme.rounded(.headline, .heavy)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .primaryButtonStyle()
                .controlSize(.large)
                .accessibilityIdentifier("selectCar")
            } else {
                Label("Earn \(car.starsToUnlock - progress.totalStars) more stars to unlock", systemImage: "lock.fill")
                    .font(Theme.rounded(.headline, .bold)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Cosmetics

    private var cosmetics: some View {
        let items = Cosmetics.items(kind)
        let owned = Cosmetics.all.filter { progress.owned.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Style", trailing: "\(owned) / \(Cosmetics.all.count) owned")
            Picker("Style", selection: $kind) {
                Text("Paint").tag(Cosmetic.Kind.paint)
                Text("Echo trail").tag(Cosmetic.Kind.trail)
                Text("Finish").tag(Cosmetic.Kind.finish)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("styleKind")
            Text(kindHelp).font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    CosmeticTile(item: item, owned: progress.owned.contains(item.id), equipped: isEquipped(item), car: focused)
                        .onTapGesture { tap(item) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("cosmetic-\(item.id)")
                }
            }
        }
    }

    private var kindHelp: String {
        switch kind {
        case .paint: return "Paint goes on \(focused.name). Each racer keeps its own."
        case .trail: return "How your echoes' trails look on track."
        case .finish: return "What bursts out when you cross the finish line."
        }
    }

    private func isEquipped(_ item: Cosmetic) -> Bool {
        switch item.kind {
        case .paint: return progress.paint(for: focused) == item.id
        case .trail: return progress.trail == item.id
        case .finish: return progress.finishCelebration == item.id
        }
    }

    private func tap(_ item: Cosmetic) {
        Haptics.tap()
        if progress.owned.contains(item.id) {
            let car = focused
            app.update { $0.equip(item.id, car: car) }
        } else if progress.sparks >= item.price {
            pending = item
        } else {
            app.showToast("You need \(item.price - progress.sparks) more Sparks. Earn them with stars, medals and daily goals.")
        }
    }

    private func buy(_ item: Cosmetic) {
        var error: PlayerProgress.PurchaseError?
        let car = focused
        app.update { p in
            error = p.buy(item.id)
            if error == nil { p.equip(item.id, car: car) }
        }
        if error == nil {
            Sound.play(.buy)
            Haptics.success()
            app.showToast("\(item.name) is yours")
        }
    }
}

struct CosmeticTile: View {
    let item: Cosmetic
    let owned: Bool
    let equipped: Bool
    let car: CarSpec

    var body: some View {
        VStack(spacing: 8) {
            swatch.frame(height: 54)
            Text(item.name).font(Theme.rounded(.footnote, .heavy)).lineLimit(1).minimumScaleFactor(0.8)
            Group {
                if equipped {
                    Label("On", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.good)
                } else if owned {
                    Text("Owned").foregroundStyle(Theme.muted)
                } else {
                    Label("\(item.price)", systemImage: "sparkle").foregroundStyle(Theme.spark)
                }
            }
            .font(Theme.rounded(.caption, .heavy))
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 112)
        .glassCard(cornerRadius: 18)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(equipped ? Theme.good : .clear, lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name + (equipped ? ", in use" : owned ? ", owned" : ", \(item.price) Sparks"))
    }

    @ViewBuilder private var swatch: some View {
        switch item.kind {
        case .paint:
            CarPreview(car: car, paint: item.id).frame(width: 32, height: 54)
        case .trail:
            Canvas { context, size in
                var p = Path()
                p.move(to: CGPoint(x: 6, y: size.height - 8))
                p.addCurve(to: CGPoint(x: size.width - 6, y: 10), control1: CGPoint(x: size.width * 0.5, y: size.height),
                           control2: CGPoint(x: size.width * 0.4, y: 0))
                let color = item.id == "trail.rainbow" ? Theme.echo[5] : Theme.echo[1]
                let style: StrokeStyle
                switch item.id {
                case "trail.dotted": style = StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 8])
                case "trail.sparkle": style = StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 10])
                case "trail.ribbon": style = StrokeStyle(lineWidth: 12, lineCap: .round)
                case "trail.comet": style = StrokeStyle(lineWidth: 8, lineCap: .round)
                default: style = StrokeStyle(lineWidth: 5, lineCap: .round)
                }
                if item.id == "trail.neon" || item.id == "trail.comet" {
                    context.stroke(p, with: .color(color.opacity(0.35)), style: StrokeStyle(lineWidth: style.lineWidth + 8, lineCap: .round))
                }
                if item.id == "trail.rainbow" {
                    for (k, c) in Theme.echo.prefix(6).enumerated() {
                        context.stroke(p.offsetBy(dx: 0, dy: CGFloat(k) * 2 - 5), with: .color(c.opacity(0.8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                } else {
                    context.stroke(p, with: .color(color.opacity(item.id == "trail.ribbon" ? 0.5 : 0.9)), style: style)
                }
            }
            .frame(width: 80)
        case .finish:
            Image(systemName: finishIcon).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.gold)
        }
    }

    private var finishIcon: String {
        switch item.id {
        case "finish.checkered": return "flag.checkered"
        case "finish.fireworks": return "sparkles"
        case "finish.stars": return "star.fill"
        default: return "party.popper.fill"
        }
    }
}
