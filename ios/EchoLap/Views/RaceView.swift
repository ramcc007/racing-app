import SwiftUI
import SpriteKit
import EchoLapCore

/// The race screen. Builds the track (usually already cached), then shows the SpriteKit scene with a SwiftUI HUD.
struct RaceView: View {
    let request: RaceRequest
    @EnvironmentObject private var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: RaceSession?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let session {
                RaceScreen(controller: session.controller, scene: session.scene, request: request, showRule: session.showRule)
            } else {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text(request.def.mode == .career ? "\(request.def.label) · \(request.def.name)" : request.def.name)
                        .font(Theme.rounded(.headline, .heavy))
                    Text("Test-driving the track…").font(Theme.rounded(.footnote, .medium)).foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .statusBarHidden()
        .task {
            guard session == nil else { return }
            let built = await app.build(request.def)
            let world = request.def.world
            // Each world's rule is explained once, the first time a race uses it (the first race covers World 1).
            let needsRule = request.kind != .tutorial && world != .harbour && !request.def.features.isEmpty
                && !app.progress.seenRules.contains(world.rawValue) && !ScreenshotFlags.skipRuleCards
            // The echo ladder: your best runs on this track race you from the line. Screenshots get robot runs.
            var echoes = app.ladder(for: request.def.id)
            if ScreenshotFlags.scene == "race" || ScreenshotFlags.scene == "results" {
                echoes = await Task.detached { AppModel.demoEchoes(for: built, count: 3) }.value
            }
            session = RaceSession(request: request, built: built, echoes: echoes, app: app, reduceMotion: reduceMotion, showRule: needsRule)
        }
    }
}

@MainActor
final class RaceSession {
    let controller: RaceController
    let scene: GameScene
    let showRule: Bool

    init(request: RaceRequest, built: BuiltTrack, echoes: [Echo], app: AppModel, reduceMotion: Bool, showRule: Bool) {
        controller = RaceController(request: request, built: built, app: app, echoes: echoes, startPaused: showRule)
        let progress = app.progress
        scene = GameScene(controller: controller, settings: progress.settings, reduceMotion: reduceMotion, trail: progress.trail,
                          paint: progress.paint(for: controller.spec), celebration: progress.finishCelebration)
        self.showRule = showRule
    }
}

struct RaceScreen: View {
    @ObservedObject var controller: RaceController
    let scene: GameScene
    let request: RaceRequest
    @State var showRule: Bool
    @EnvironmentObject private var app: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("Race track")
                .accessibilityHint("Drag left or right to steer, hold a turn to drift, pull down to brake, swipe up for nitro.")
                .accessibilityAddTraits(.allowsDirectInteraction)
                .accessibilityIdentifier("raceScene")
            if controller.outcome == nil {
                RaceHUD(controller: controller, request: request, settings: app.progress.settings, hasGate: controller.built.track.shortcut != nil)
            }
            if showRule {
                RuleCard(world: request.def.world, features: request.def.features) {
                    app.update { $0.seenRules.insert(request.def.world.rawValue) }
                    withAnimation { showRule = false }
                    controller.resume()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if controller.isPaused && controller.outcome == nil {
                PauseMenu(controller: controller, request: request)
                    .transition(.opacity)
            }
            if let outcome = controller.outcome {
                ResultsView(outcome: outcome, request: request, rival: controller.rival)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(duration: 0.35), value: controller.outcome?.id)
        .animation(.easeInOut(duration: 0.2), value: controller.isPaused)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { controller.pause() }
        }
        .onDisappear { controller.stopSound() }
    }
}

// MARK: - HUD

struct RaceHUD: View {
    @ObservedObject var controller: RaceController
    let request: RaceRequest
    let settings: GameSettings
    let hasGate: Bool
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// iPad: the same layout, larger, so the HUD keeps its proportion on a big screen.
    private var scale: CGFloat { sizeClass == .regular ? 1.35 : 1 }

    var body: some View {
        let hud = controller.hud
        let step = controller.tutorialStep
        let showingCard = step != nil && step != .done
        ZStack {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        controller.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 18, weight: .heavy))
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.45), in: Circle())
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Pause")
                    .accessibilityIdentifier("pause")
                    Spacer(minLength: 0)
                    TimingPanel(hud: hud, rival: controller.rival.name)
                        .scaleEffect(scale, anchor: .top)
                        .padding(.bottom, (scale - 1) * 90)
                    Spacer(minLength: 0)
                    Group {
                        if let lives = hud.lives {
                            LivesView(lives: lives)
                        } else {
                            Button {
                                controller.stopSound()
                                app.restart(request)
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .heavy))
                                    .frame(width: 48, height: 48)
                                    .background(.black.opacity(0.45), in: Circle())
                                    .foregroundStyle(.white)
                            }
                            .accessibilityLabel("Go again")
                            .accessibilityHint("Restarts this sprint straight away")
                            .accessibilityIdentifier("goAgain")
                        }
                    }
                    .frame(width: 48, height: 48)
                }
                if !hud.echoes.isEmpty {
                    EchoChips(chips: hud.echoes, survival: request.def.mode == .survival).allowsHitTesting(false)
                }
                if let toast = controller.toast {
                    ToastPill(toast: toast).allowsHitTesting(false)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if hud.wrongWay {
                    Label("Wrong way! Turn around", systemImage: "arrow.uturn.backward")
                        .font(Theme.rounded(.title3, .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Theme.bad, in: Capsule())
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("wrongWay")
                }
                if let step, step != .done, hud.countdown == nil {
                    TutorialCard(step: step)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                if let hint = controller.hint, !showingCard {
                    Text(hint)
                        .font(Theme.rounded(.callout, .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .solidCard(cornerRadius: 18, fill: Color.black.opacity(0.72))
                        .frame(maxWidth: 460)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .accessibilityIdentifier("hint")
                }
                if hud.countdown != nil || (hud.runUp && !showingCard) {
                    GoalPanel(goal: controller.goal, def: controller.request.def, rival: controller.rival, firstGo: request.attempt == 0)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                Spacer()
                if hasGate || hud.docked {
                    StatusPill(open: hud.gateOpen, docked: hud.docked).allowsHitTesting(false)
                }
                ControlsRow(controller: controller, hud: hud, boostOnLeft: settings.boostButtonOnLeft, scale: scale)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .animation(.easeOut(duration: 0.2), value: controller.toast)
            .animation(.easeOut(duration: 0.25), value: controller.hint)
            .animation(.spring(duration: 0.3), value: controller.tutorialStep)
            .animation(.easeOut(duration: 0.3), value: hud.runUp)

            if let popup = controller.popup {
                PopupWord(popup: popup)
                    .offset(y: -60 * scale)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityIdentifier("popup")
            }
            if let n = hud.countdown {
                Text("\(n)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 12)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: n)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Starting in \(n)")
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0.4), value: controller.popup?.id)
    }
}

/// A big word in the middle of the screen for a moment: NEAR MISS, SUPER DRIFT, NITRO.
struct PopupWord: View {
    let popup: RaceController.Popup

    var body: some View {
        VStack(spacing: 2) {
            Text(popup.text)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(popup.color)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
            if let detail = popup.detail {
                Text(detail).font(Theme.rounded(.headline, .heavy)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// What this race is for, shown before the start, with the rival's taunt and the controls in one line.
struct GoalPanel: View {
    let goal: String
    let def: TrackDef
    let rival: Rival
    let firstGo: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(def.mode == .career ? "\(def.label) \u{00B7} \(def.name)" : def.name)
                .font(Theme.rounded(.subheadline, .bold)).foregroundStyle(.white.opacity(0.8))
            Text(goal)
                .font(Theme.rounded(.title3, .heavy)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if def.mode == .career {
                Text("\(rival.name): \u{201C}\(rival.taunt)\u{201D}")
                    .font(Theme.rounded(.footnote, .bold)).italic().foregroundStyle(Color(hex: rival.color))
            }
            if firstGo {
                Text("Drag to steer \u{00B7} hold the turn to drift \u{00B7} swipe up for nitro")
                    .font(Theme.rounded(.footnote, .semibold)).foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .solidCard(cornerRadius: 20, fill: Color.black.opacity(0.72))
        .frame(maxWidth: 460)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goalPanel")
    }
}

/// A lesson in the first race that waits for the player to do it.
struct TutorialCard: View {
    let step: RaceController.TutorialStep

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(Theme.rounded(.title2, .black)).foregroundStyle(.white)
            Text(detail).font(Theme.rounded(.callout, .semibold)).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .solidCard(cornerRadius: 22, fill: Theme.accent.opacity(0.92))
        .frame(maxWidth: 440)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tutorialCard")
    }

    private var title: String {
        switch step {
        case .steer: return "Drag left or right to STEER"
        case .drift: return "Hold the turn hard to DRIFT"
        case .release: return "Let go for a BOOST"
        case .nitro: return "Nitro is ready: swipe up!"
        case .done: return ""
        }
    }

    private var detail: String {
        switch step {
        case .steer: return "Anywhere on the screen. Your car drives by itself."
        case .drift: return "Keep pushing through a corner until the sparks fly."
        case .release: return "The longer the drift, the bigger the boost."
        case .nitro: return "Or tap NITRO. Drifts, near misses and the road's edge fill it."
        case .done: return ""
        }
    }
}

struct TimingPanel: View {
    let hud: RaceController.HUD
    let rival: String

    var body: some View {
        VStack(spacing: 2) {
            if hud.laps == 0 {
                Text("LAP \(hud.lap)").font(Theme.rounded(.caption, .heavy)).tracking(1.5).foregroundStyle(.white.opacity(0.85))
            }
            Text(hud.runUp && hud.time == 0 ? "0.00" : TimeFormat.race(hud.time))
                .font(Theme.timer(30))
                .foregroundStyle(.white)
            if let delta = hud.delta {
                Text(String(format: delta <= 0 ? "%.2f s ahead of %@" : "%.2f s behind %@", abs(delta), rival))
                    .font(Theme.rounded(.caption, .heavy)).monospacedDigit()
                    .foregroundStyle(delta <= 0 ? Theme.good : Theme.bad)
            } else if hud.runUp && hud.countdown == nil {
                Text("Timing starts at the line").font(Theme.rounded(.caption2, .bold)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TimeFormat.spoken(hud.time))
        .accessibilityValue(hud.delta.map { $0 <= 0 ? "ahead of \(rival)" : "behind \(rival)" } ?? "")
        .accessibilityIdentifier("timing")
    }
}

struct LivesView: View {
    let lives: Int
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < lives ? "heart.fill" : "heart")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(i < lives ? Theme.bad : .white.opacity(0.4))
            }
        }
        .frame(width: 48, height: 48)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lives) \(lives == 1 ? "life" : "lives") left")
    }
}

/// One chip per echo: its rung (or lap) and colour (never colour alone), filled when solid, P when parked.
struct EchoChips: View {
    let chips: [RaceController.EchoChip]
    let survival: Bool
    var body: some View {
        HStack(spacing: 6) {
            Text(survival ? "LAPS" : "ECHOES").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.7))
            ForEach(chips.suffix(8)) { chip in
                let color = Theme.echoColor(lap: chip.id)
                HStack(spacing: 3) {
                    if chip.state == .parked { Image(systemName: "parkingsign").font(.system(size: 10, weight: .black)) }
                    Text("\(chip.id)").font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundStyle(chip.state == .solid || chip.state == .parked ? Color.black : color)
                .frame(minWidth: 26, minHeight: 22)
                .padding(.horizontal, 4)
                .background {
                    Capsule().fill(chip.state == .solid || chip.state == .parked ? color : Color.black.opacity(0.45))
                    Capsule().strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: chip.state == .ghost ? [3, 2] : []))
                }
                .opacity(chip.state == .done ? 0.35 : 1)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.black.opacity(0.3), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chips.filter { $0.state != .done }.count) echoes on track")
    }
}

struct ToastPill: View {
    let toast: RaceController.Toast
    private var color: Color {
        switch toast.tone {
        case .good: return Theme.good
        case .bad: return Theme.bad
        case .info: return .white
        }
    }

    var body: some View {
        Text(toast.text)
            .font(Theme.rounded(.subheadline, .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.6), in: Capsule())
            .accessibilityIdentifier("raceToast")
    }
}

struct StatusPill: View {
    let open: Bool
    let docked: Bool
    var body: some View {
        Label(docked ? "Parked · swipe up to leave" : (open ? "Gate open" : "Gate closed"),
              systemImage: docked ? "parkingsign.circle.fill" : (open ? "lock.open.fill" : "lock.fill"))
            .font(Theme.rounded(.footnote, .heavy))
            .foregroundStyle(docked || open ? Theme.good : .white.opacity(0.75))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.5), in: Capsule())
    }
}

struct ControlsRow: View {
    @ObservedObject var controller: RaceController
    let hud: RaceController.HUD
    let boostOnLeft: Bool
    var scale: CGFloat = 1

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            if boostOnLeft { boost; Spacer(); drift; swap } else { swap; drift; Spacer(); boost }
        }
    }

    /// Three pips that light up as a drift builds: the boost it will give when the thumb lets go.
    private var drift: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                ForEach(1...3, id: \.self) { tier in
                    Capsule()
                        .fill(hud.driftTier >= tier ? Theme.driftColor(tier) : Color.white.opacity(hud.drifting ? 0.35 : 0.18))
                        .frame(width: 18 * scale, height: 8 * scale)
                }
            }
            Text(hud.drifting ? (hud.driftTier >= 3 ? "ULTRA" : (hud.driftTier == 2 ? "SUPER" : "DRIFT")) : "DRIFT")
                .font(.system(size: 10 * scale, weight: .black, design: .rounded))
                .foregroundStyle(hud.drifting ? Theme.driftColor(max(1, hud.driftTier)) : .white.opacity(0.55))
        }
        .padding(.horizontal, 10 * scale).padding(.vertical, 8 * scale)
        .background(.black.opacity(hud.drifting ? 0.55 : 0.35), in: Capsule())
        .scaleEffect(hud.drifting ? 1.08 : 1)
        .animation(.spring(duration: 0.2), value: hud.drifting)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Drift")
        .accessibilityValue(hud.drifting ? "drifting, tier \(hud.driftTier) of 3" : "not drifting")
        .accessibilityIdentifier("driftMeter")
    }

    @ViewBuilder private var swap: some View {
        if controller.request.def.features.contains(.relay) {
            Button {
                controller.requestSwap()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 20 * scale, weight: .heavy))
                    Text("SWAP").font(.system(size: 10 * scale, weight: .black, design: .rounded))
                }
                .foregroundStyle(hud.swapAvailable ? Color.black : .white.opacity(0.5))
                .frame(width: 68 * scale, height: 68 * scale)
                .background(hud.swapAvailable ? Theme.echo[1] : Color.black.opacity(0.45), in: Circle())
            }
            .disabled(!hud.swapAvailable)
            .accessibilityLabel("Relay swap")
            .accessibilityValue(hud.swapAvailable ? "ready" : "used")
            .accessibilityIdentifier("swap")
        }
    }

    private var boost: some View {
        Button {
            controller.requestBoost()
        } label: {
            ZStack {
                Circle().fill(hud.boostReady || hud.docked ? Theme.accent : Color.black.opacity(0.45))
                Circle().trim(from: 0, to: hud.boost).stroke(hud.boostReady ? Color.white : Theme.accent,
                                                              style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                // The notch marks how much one nitro costs.
                Circle().trim(from: Race.boostCost - 0.008, to: Race.boostCost + 0.008).stroke(Color.white.opacity(0.9), lineWidth: 10)
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                VStack(spacing: 0) {
                    Image(systemName: hud.docked ? "arrow.up.circle.fill" : "bolt.fill").font(.system(size: 24 * scale, weight: .heavy))
                    Text(hud.docked ? "LEAVE" : "NITRO").font(.system(size: 11 * scale, weight: .black, design: .rounded))
                }
                .foregroundStyle(hud.boostReady || hud.docked ? Color.black : .white.opacity(0.75))
            }
            .frame(width: 84 * scale, height: 84 * scale)
            .scaleEffect(hud.boosting ? 1.1 : 1)
            .animation(.spring(duration: 0.2), value: hud.boosting)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hud.docked ? "Leave the bay" : "Nitro")
        .accessibilityValue("\(Int(hud.boost * 100)) percent charged" + (hud.boostReady ? ", ready" : ""))
        .accessibilityIdentifier("boost")
    }
}

// MARK: - Rule card and pause menu

/// Explains a world's new rule the first time a race uses it. The race waits behind it.
struct RuleCard: View {
    let world: World
    let features: Set<Feature>
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("NEW RULE · WORLD \(world.rawValue)").font(Theme.rounded(.caption, .heavy)).tracking(2).foregroundStyle(Theme.worldColor(world))
                Text(world.ruleTitle).font(Theme.rounded(.title, .black)).accessibilityAddTraits(.isHeader)
                Text(world.ruleText).font(Theme.rounded(.body, .medium)).foregroundStyle(Theme.text.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                if !features.isEmpty {
                    FlowChips(features: features.sorted { $0.rawValue < $1.rawValue }, softEchoes: false)
                }
                Button(action: onDone) {
                    Text("Got it, let's race").font(Theme.rounded(.headline, .heavy)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .primaryButtonStyle()
                .controlSize(.large)
                .accessibilityIdentifier("ruleDone")
            }
            .padding(22)
            .frame(maxWidth: 480)
            .solidCard(cornerRadius: 28)
            .padding(20)
        }
    }
}

struct PauseMenu: View {
    @ObservedObject var controller: RaceController
    let request: RaceRequest
    @EnvironmentObject private var app: AppModel
    @State private var confirmQuit = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Paused").font(Theme.rounded(.largeTitle, .black)).accessibilityAddTraits(.isHeader)
                Text(request.def.mode == .career ? "\(request.def.label) · \(request.def.name)" : request.def.name)
                    .font(Theme.rounded(.subheadline, .semibold)).foregroundStyle(Theme.muted)
                if let medal = request.def.medal, request.def.mode == .career {
                    Label(medal.detail, systemImage: "medal")
                        .font(Theme.rounded(.footnote, .semibold)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.leading)
                }
                Button {
                    controller.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill").font(Theme.rounded(.headline, .heavy)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .primaryButtonStyle()
                .controlSize(.large)
                .accessibilityIdentifier("resume")
                Button {
                    controller.stopSound()
                    app.restart(request)
                } label: {
                    Label(isWeekly ? "Restart gauntlet" : "Go again", systemImage: "arrow.counterclockwise")
                        .font(Theme.rounded(.headline, .bold)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .secondaryButtonStyle()
                .controlSize(.large)
                .accessibilityIdentifier("restart")
                HStack(spacing: 10) {
                    toggle("Sound", on: "speaker.wave.2.fill", off: "speaker.slash.fill", value: app.progress.settings.sound) {
                        app.update { $0.settings.sound.toggle() }
                        app.applySettings()
                    }
                    toggle("Haptics", on: "iphone.radiowaves.left.and.right", off: "iphone.slash", value: app.progress.settings.haptics) {
                        app.update { $0.settings.haptics.toggle() }
                        app.applySettings()
                    }
                    toggle("Hints", on: "lightbulb.fill", off: "lightbulb.slash", value: app.progress.settings.showHints) {
                        app.update { $0.settings.showHints.toggle() }
                        controller.apply(app.progress.settings)
                    }
                }
                Button(role: .destructive) {
                    confirmQuit = true
                } label: {
                    Text(isWeekly ? "Quit gauntlet" : "Quit race").font(Theme.rounded(.headline, .bold)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.bad)
                .frame(minHeight: 44)
                .accessibilityIdentifier("quit")
            }
            .padding(22)
            .frame(maxWidth: 420)
            .solidCard(cornerRadius: 28)
            .padding(20)
        }
        .confirmationDialog("Quit this race?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Quit to menu", role: .destructive) {
                controller.stopSound()
                app.goHome()
            }
            Button("Keep racing", role: .cancel) {}
        } message: {
            Text("This race won't count.")
        }
    }

    private var isWeekly: Bool { if case .weekly = request.kind { return true } else { return false } }

    private func toggle(_ title: String, on: String, off: String, value: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: value ? on : off).font(.system(size: 18, weight: .bold))
                Text(title).font(Theme.rounded(.caption, .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(value ? Theme.text : Theme.muted)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value ? "on" : "off")
    }
}
