import SwiftUI
import SpriteKit
import EchoLapCore

/// First launch only. Following Apple's guidance for games: no splash screen, no account, no permission prompts.
/// A live demo race runs behind the title so the idea is visible straight away, and one tap starts the first race,
/// which teaches the controls by playing.
struct IntroView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var demo: DemoRace?

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
            VStack(spacing: 18) {
                Spacer()
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { i in Capsule().fill(Theme.echo[i]).frame(width: 26, height: 7) }
                    }
                    .accessibilityHidden(true)
                    Text("ECHO LAP")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .tracking(-1)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Text("Every lap you drive stays on the track.")
                        .font(Theme.rounded(.title3, .semibold))
                        .foregroundStyle(Theme.text.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Each lap becomes an echo car beside you", systemImage: "repeat")
                    Label("Slipstream it, park it on a switch, swap with it", systemImage: "wind")
                    Label("One thumb · plays offline · no account", systemImage: "hand.point.up.left")
                }
                .font(Theme.rounded(.callout, .medium))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 8)
                Button {
                    Haptics.medium()
                    app.startTutorial()
                } label: {
                    Text("Start racing")
                        .font(Theme.rounded(.title3, .heavy))
                        .frame(maxWidth: 420)
                        .padding(.vertical, 6)
                }
                .primaryButtonStyle()
                .controlSize(.large)
                .accessibilityIdentifier("startRacing")
                LinkRow()
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
        }
        .task {
            guard demo == nil else { return }
            let def = Catalog.track(id: "1-3")!
            let built = await app.build(def)
            let race = DemoRace(built: built, reduceMotion: reduceMotion)
            withAnimation(.easeIn(duration: 0.6)) { demo = race }
        }
    }
}

/// A robot racing its own echoes, for backgrounds. Never records anything, never plays sound.
@MainActor
final class DemoRace {
    let controller: RaceController
    let scene: GameScene

    init(built: BuiltTrack, reduceMotion: Bool) {
        controller = RaceController(request: RaceRequest(def: built.track.def, kind: .career), built: built, app: nil, demo: true)
        var settings = GameSettings()
        settings.camera = .follow
        scene = GameScene(controller: controller, settings: settings, reduceMotion: reduceMotion, trail: "trail.classic", paint: "paint.factory")
    }
}
