import SwiftUI
import SpriteKit
import EchoLapCore

/// First launch only. Following Apple's guidance for games: no splash screen, no account, no permission prompts.
/// A live demo race runs behind three short cards (the controls, the rival, the echoes), then the first race
/// teaches the controls by playing.
struct IntroView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var demo: DemoRace?
    @State private var page = 0

    var body: some View {
        ZStack {
            MenuBackground()
            if let demo {
                SpriteView(scene: demo.scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
            LinearGradient(colors: [.clear, Theme.background.opacity(0.75), Theme.background], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        Haptics.tap()
                        app.startTutorial()
                    }
                    .font(Theme.rounded(.subheadline, .bold))
                    .foregroundStyle(Theme.text.opacity(0.8))
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("introSkip")
                }
                Spacer()
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { i in Capsule().fill(Theme.echo[i]).frame(width: 26, height: 7) }
                    }
                    .accessibilityHidden(true)
                    Text("ECHO LAP")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .tracking(-1)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Text("Drift past yourself.")
                        .font(Theme.rounded(.headline, .heavy)).foregroundStyle(Theme.accent)
                }
                TabView(selection: $page) {
                    ForEach(IntroCard.all) { card in
                        IntroCardView(card: card).tag(card.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 330)
                .accessibilityIdentifier("introCards")
                Button {
                    Haptics.medium()
                    if page < IntroCard.all.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        app.startTutorial()
                    }
                } label: {
                    Text(page < IntroCard.all.count - 1 ? "Next" : "Start racing")
                        .font(Theme.rounded(.title3, .heavy))
                        .frame(maxWidth: 420)
                        .padding(.vertical, 6)
                }
                .primaryButtonStyle()
                .controlSize(.large)
                .accessibilityIdentifier(page < IntroCard.all.count - 1 ? "introNext" : "startRacing")
                LinkRow()
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
        }
        .task {
            guard demo == nil else { return }
            app.prefetch([Catalog.track(id: "1-1")!])   // the first race is ready the moment "Start racing" is tapped
            let def = Catalog.track(id: "1-3")!
            let built = await app.build(def)
            let echoes = await Task.detached { AppModel.demoEchoes(for: built, count: 2) }.value
            let race = DemoRace(built: built, echoes: echoes, reduceMotion: reduceMotion)
            withAnimation(.easeIn(duration: 0.6)) { demo = race }
        }
    }
}

/// A robot racing its own echoes, for backgrounds. Never records anything, never plays sound.
@MainActor
final class DemoRace {
    let controller: RaceController
    let scene: GameScene

    init(built: BuiltTrack, echoes: [Echo], reduceMotion: Bool) {
        controller = RaceController(request: RaceRequest(def: built.track.def, kind: .career), built: built, app: nil, echoes: echoes, demo: true)
        var settings = GameSettings()
        settings.camera = .follow
        scene = GameScene(controller: controller, settings: settings, reduceMotion: reduceMotion, trail: "trail.classic", paint: "paint.factory")
    }
}

/// One intro card: a picture and two lines.
struct IntroCard: Identifiable {
    let id: Int
    let title: String
    let text: String

    static let all = [
        IntroCard(id: 0, title: "Hold the turn. Drift. Let go.",
                  text: "Your car drives itself. Drag to steer, hold a corner hard to drift, and let go for a boost. Swipe up for nitro."),
        IntroCard(id: 1, title: "Beat the rival",
                  text: "Every world has a rival with a mouth on them. Finish a sprint ahead of them for three stars. Stars open new worlds."),
        IntroCard(id: 2, title: "Your runs come back",
                  text: "Every best run joins the road as an echo car. Pass it by a whisker for nitro, touch it and you spin. Beat all five to master a track."),
    ]
}

struct IntroCardView: View {
    let card: IntroCard

    var body: some View {
        VStack(spacing: 14) {
            IntroPicture(kind: card.id)
                .frame(height: 150)
                .accessibilityHidden(true)
            Text(card.title)
                .font(Theme.rounded(.title2, .black))
                .multilineTextAlignment(.center)
            Text(card.text)
                .font(Theme.rounded(.callout, .medium))
                .foregroundStyle(Theme.text.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .solidCard(cornerRadius: 26, fill: Theme.surface.opacity(0.92))
        .padding(.horizontal, 4)
        .padding(.bottom, 36)
        .accessibilityElement(children: .combine)
    }
}

/// Code-drawn pictures for the intro cards: a road with the player, a drift, the rival and echoes.
struct IntroPicture: View {
    let kind: Int

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            // A strip of road across the card.
            let road = Path(roundedRect: CGRect(x: 0, y: h * 0.2, width: w, height: h * 0.6), cornerRadius: 18)
            context.fill(road, with: .color(Color(hex: 0x3B3F47)))
            var lane = Path()
            lane.move(to: CGPoint(x: 10, y: h / 2)); lane.addLine(to: CGPoint(x: w - 10, y: h / 2))
            context.stroke(lane, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 3, dash: [12, 12]))
            for x in stride(from: w * 0.12, to: w, by: w * 0.28) {
                var a = Path()
                a.move(to: CGPoint(x: x, y: h * 0.32)); a.addLine(to: CGPoint(x: x + 10, y: h * 0.38)); a.addLine(to: CGPoint(x: x, y: h * 0.44))
                context.stroke(a, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            func car(_ x: CGFloat, _ y: CGFloat, _ color: Color, label: String? = nil, alpha: Double = 1, angle: Double = 0) {
                var ctx = context
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: .degrees(angle))
                let body = Path(roundedRect: CGRect(x: -26, y: -13, width: 52, height: 26), cornerRadius: 9)
                ctx.fill(body, with: .color(color.opacity(alpha)))
                ctx.fill(Path(ellipseIn: CGRect(x: -6, y: -7, width: 16, height: 14)), with: .color(Color(hex: 0x16263A).opacity(alpha)))
                if let label {
                    context.draw(Text(label).font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(.white),
                                 at: CGPoint(x: x, y: y - 26))
                }
            }
            switch kind {
            case 0:
                // A drifting car with sparks and a boost flame.
                car(w * 0.5, h * 0.5, .white, label: "YOU", angle: -28)
                for k in 0..<9 {
                    let a = Double(k) * 0.35 + 2.4
                    let r = CGFloat(18 + (k % 3) * 9)
                    let c = CGPoint(x: w * 0.5 - 20 + cos(a) * r, y: h * 0.5 + 8 + sin(a) * r)
                    context.fill(Path(ellipseIn: CGRect(x: c.x - 2.5, y: c.y - 2.5, width: 5, height: 5)),
                                 with: .color([Theme.driftColor(1), Theme.driftColor(2), Theme.driftColor(3)][k % 3]))
                }
                context.draw(Text("DRIFT").font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(Theme.driftColor(2)),
                             at: CGPoint(x: w * 0.78, y: h * 0.3))
            case 1:
                car(w * 0.62, h * 0.62, Theme.gold, label: "SKIP", alpha: 0.85)
                car(w * 0.36, h * 0.38, .white, label: "YOU")
                var flag = Path()
                flag.addRect(CGRect(x: w * 0.88, y: h * 0.2, width: 6, height: h * 0.6))
                context.fill(flag, with: .color(.white.opacity(0.8)))
            default:
                car(w * 0.22, h * 0.62, Theme.echo[1], label: "2", alpha: 0.6)
                car(w * 0.44, h * 0.38, Theme.echo[0], label: "1", alpha: 0.6)
                car(w * 0.72, h * 0.62, .white, label: "YOU")
                context.draw(Text("NEAR MISS").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(Theme.good),
                             at: CGPoint(x: w * 0.6, y: h * 0.88))
            }
        }
    }
}
