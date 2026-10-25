import Foundation
import SwiftUI
import GameController
import CoreMotion
import EchoLapCore

/// Runs one race: steps the simulation at a fixed 120 Hz, turns player input into controls, plays sound and haptics
/// for race events, and publishes a light HUD snapshot about 20 times a second for the SwiftUI overlay.
@MainActor
final class RaceController: ObservableObject {
    struct EchoChip: Equatable, Identifiable {
        enum State: Equatable { case ghost, solid, parked, done }
        let id: Int   // rung (or lap number in Survival)
        let state: State
    }

    struct HUD: Equatable {
        var lap = 1
        var laps = 1
        var time = 0.0
        /// Seconds ahead (negative) or behind the rival's pace.
        var delta: Double?
        var boost = 0.0
        var boostReady = false
        var boosting = false
        var echoes: [EchoChip] = []
        var gateOpen = false
        var docked = false
        var lives: Int?
        var countdown: Int?
        var runUp = true
        var speed = 0.0
        var swapAvailable = false
        /// Driving the wrong way round (shown as a big warning).
        var wrongWay = false
        var drifting = false
        var driftTier = 0
        var onEdge = false
    }

    /// The first race teaches by doing: each step waits until the player has done it once.
    enum TutorialStep: Equatable {
        case steer, drift, release, nitro, done
    }

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let tone: Tone
        enum Tone { case info, good, bad }
    }

    /// A big, short-lived word in the middle of the screen: NEAR MISS, DRIFT BOOST, EDGE.
    struct Popup: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let detail: String?
        let color: Color
    }

    struct Outcome: Identifiable {
        let id = UUID()
        let result: RaceResult
        let summary: RewardSummary?
        let targets: Targets?
        let isTutorial: Bool
    }

    @Published private(set) var hud = HUD()
    @Published private(set) var toast: Toast?
    @Published private(set) var popup: Popup?
    @Published private(set) var hint: String?
    @Published private(set) var isPaused = false
    @Published private(set) var outcome: Outcome?
    @Published private(set) var tutorialStep: TutorialStep?

    let request: RaceRequest
    let built: BuiltTrack
    let race: Race
    let spec: CarSpec
    let isDemo: Bool
    /// The line the rival drives (also where the direction arrows sit).
    let racingLine: RacingLine
    /// The world's rival: their pace is the gold time.
    let rival: Rival
    /// What this race asks of the player, shown before the start.
    let goal: String
    private weak var app: AppModel?
    private var settings: GameSettings
    private var autopilot: RobotDriver?
    private var ticksPerStep = 1
    private var accumulator = 0.0
    private var frame = 0
    private var lastDriftHaptic = 0.0
    private var slowMoLeft = 0.0
    private var toastTask: Task<Void, Never>?
    private var popupTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private var shownHints: Set<String> = []
    private var tutorialHeld = 0.0
    private var nitroGranted = false
    /// Set for one frame when something hits (the scene shakes the camera), flashes (near miss) or punches (nitro).
    private(set) var shakeRequested = false
    private(set) var flashRequested = false
    private(set) var punchRequested = false

    // Input
    private var touching = false
    private var touchSteer = 0.0
    private var touchBrake = false
    private var pendingBoost = false
    private var pendingSwap = false
    private let motion = CMMotionManager()

    /// `echoes` are the player's saved runs on this track (the ladder), already picked by the app.
    init(request: RaceRequest, built: BuiltTrack, app: AppModel?, echoes: [Echo] = [], demo: Bool = false, startPaused: Bool = false) {
        self.request = request
        self.built = built
        self.app = app
        self.isDemo = demo
        let progress = app?.progress ?? PlayerProgress()
        settings = progress.settings
        spec = demo ? Cars.pip : Cars.car(id: progress.selectedCar)
        let lives = request.def.mode == .survival ? 3 : nil
        let laps = demo ? Int.max : (request.def.mode == .survival ? Int.max : request.def.laps)
        // The first go gets the full 3-2-1; GO AGAIN starts in a second.
        let countdown = demo ? 0.5 : (request.attempt > 0 ? 1.0 : 3.0)
        race = Race(track: built.track, spec: spec, laps: laps, lives: lives, echoes: echoes, countdown: countdown)
        racingLine = RacingLine(track: built.track)
        rival = request.def.world.rival
        switch request.def.mode {
        case .career: goal = "Beat \(rival.name) for \u{2605}\u{2605}\u{2605}"
        case .daily: goal = "Same track for everyone today. Set your best time."
        case .weekly: goal = "Three tracks back to back. Your total time counts."
        case .survival: goal = "Laps never end. Dodge your echoes: three bumps and you're out."
        }
        if demo {
            let driver = RobotDriver(track: built.track, plan: built.targets.plan)
            driver.weave = 0.35
            autopilot = driver
        }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if !demo && !args.contains("-EchoManual") && (args.contains("-EchoUITest") || args.contains("-EchoAutopilot") || args.contains("-EchoScene")) {
            let driver = RobotDriver(track: built.track, plan: built.targets.plan, spec: spec)
            driver.weave = args.contains("-EchoUITest") ? 0 : 0.3
            autopilot = driver
        }
        if args.contains("-EchoUITest") { ticksPerStep = 6 }
        if let i = args.firstIndex(of: "-EchoFastForward"), i + 1 < args.count, let n = Int(args[i + 1]) { ticksPerStep = n }
        #endif
        isPaused = startPaused
        if settings.tiltSteering && motion.isDeviceMotionAvailable && !demo {
            motion.deviceMotionUpdateInterval = 1.0 / 60
            motion.startDeviceMotionUpdates()
        }
        if request.kind == .tutorial && autopilot == nil {
            tutorialStep = .steer
        }
        publishHUD()
    }

    deinit {
        motion.stopDeviceMotionUpdates()
    }

    var difficulty: Difficulty { built.track.difficulty }
    var calm: Bool { settings.calmEffects }

    // MARK: - Frame

    /// Called by the scene every frame with the real elapsed time.
    func advance(_ elapsed: Double) {
        shakeRequested = false
        flashRequested = false
        punchRequested = false
        guard !isPaused, outcome == nil else {
            SoundEngine.shared.updateEngine(speed: 0, boosting: false, running: false)
            return
        }
        let real = min(elapsed, 0.1)
        var scale = 1.0
        if slowMoLeft > 0 {
            slowMoLeft -= real
            scale = 0.3
        }
        accumulator += real * Double(ticksPerStep) * scale
        while accumulator >= Physics.dt && outcome == nil {
            accumulator -= Physics.dt
            race.tick(currentInput())
            handleEvents()
        }
        frame += 1
        tutorialTick(real)
        if race.car.drifting && race.time - lastDriftHaptic > 0.1 && !isDemo {
            lastDriftHaptic = race.time
            Haptics.light(0.3 + 0.2 * Double(race.car.driftTier))
        }
        if !isDemo {
            SoundEngine.shared.updateEngine(speed: max(0, race.car.forwardSpeed) / spec.topSpeed, boosting: race.car.boostTime > 0,
                                            running: race.phase == .racing)
        }
        if frame % 3 == 0 { publishHUD() }
    }

    private func currentInput() -> ControlInput {
        if let autopilot {
            var input = autopilot.input(for: race)
            if race.boostCharge >= 0.99 { input.boost = true }
            return input
        }
        var steer = touchSteer
        var brake = touchBrake
        if settings.tiltSteering, let gravity = motion.deviceMotion?.gravity, !touching {
            steer = clamp(gravity.x * 2.6, -1, 1)
        }
        if let pad = GCController.current?.extendedGamepad {
            let stick = Double(pad.leftThumbstick.xAxis.value)
            let dpad = Double(pad.dpad.xAxis.value)
            if abs(stick) > 0.08 || abs(dpad) > 0.5 { steer = abs(stick) > abs(dpad) ? stick : dpad }
            if pad.buttonA.isPressed || pad.leftTrigger.value > 0.2 { brake = true }
            if (pad.buttonB.isPressed || pad.rightTrigger.value > 0.5) && !controllerBoostHeld { pendingBoost = true }
            controllerBoostHeld = pad.buttonB.isPressed || pad.rightTrigger.value > 0.5
            if pad.buttonX.isPressed && !controllerSwapHeld { pendingSwap = true }
            controllerSwapHeld = pad.buttonX.isPressed
        }
        let input = ControlInput(steer: steer, brake: brake, boost: pendingBoost, swap: pendingSwap)
        pendingBoost = false
        pendingSwap = false
        return input
    }

    // MARK: - Tutorial

    /// Moves the first race's lessons on as the player does each thing.
    private func tutorialTick(_ elapsed: Double) {
        guard let step = tutorialStep, step != .done, race.phase == .racing else { return }
        switch step {
        case .steer:
            tutorialHeld = abs(touchSteer) > 0.5 ? tutorialHeld + elapsed : tutorialHeld
            if tutorialHeld >= 0.35 {
                tutorialHeld = 0
                lessonDone(.drift)
            }
        case .nitro:
            // Make sure the nitro lesson can happen even on a run with few drifts.
            if race.crossedStart && race.lapTime > 6 && race.boostCharge < Race.boostCost && !nitroGranted {
                nitroGranted = true
                race.addBoost(Race.boostCost - race.boostCharge)
            }
        default:
            break
        }
    }

    private func lessonDone(_ next: TutorialStep) {
        Haptics.success()
        Sound.play(.unlock, volume: 0.45)
        tutorialStep = next
    }

    private var controllerBoostHeld = false
    private var controllerSwapHeld = false

    // MARK: - Input from the scene and HUD

    func touchBegan() { touching = true }

    /// Steering from the thumb's sideways travel, already scaled to -1...1 by the scene.
    func touchSteered(_ value: Double) { touchSteer = clamp(value, -1, 1) }

    /// The thumb pulled down past the brake line (or back up).
    func touchBraked(_ braking: Bool) { touchBrake = braking }

    func touchEnded() {
        touching = false
        touchSteer = 0
        touchBrake = false
    }

    func requestBoost() { pendingBoost = true }
    func requestSwap() { pendingSwap = true }

    func pause() {
        guard outcome == nil, !isDemo else { return }
        isPaused = true
        Haptics.tap()
        SoundEngine.shared.stopEngine()
    }

    func resume() {
        isPaused = false
        accumulator = 0
    }

    func stopSound() { SoundEngine.shared.stopEngine() }

    /// Settings changed from the pause menu (hints; sound and haptics are global).
    func apply(_ newSettings: GameSettings) {
        settings.showHints = newSettings.showHints
        if !settings.showHints && request.kind != .tutorial { hint = nil }
    }

    // MARK: - Events

    private func handleEvents() {
        let events = race.events
        race.events.removeAll(keepingCapacity: true)
        guard !isDemo else { return }
        for event in events {
            switch event {
            case .countdown(let n):
                Sound.play(.countdown)
                Haptics.light()
                hud.countdown = n
            case .go:
                Sound.play(.go)
                Haptics.medium()
                hud.countdown = nil
            case .lap(let n, let t):
                Sound.play(.lap)
                Haptics.medium()
                if race.laps == Int.max { showToast("Lap \(n) · \(TimeFormat.race(t))", .good) }
            case .echoSpawned(let lap):
                Sound.play(.echoJoin, volume: 0.8)
                if lap == 1 { showToast("Your lap 1 echo joins", .info) }
            case .bump:
                Sound.play(.bump)
                Haptics.heavy()
                shakeRequested = true
                if race.livesLeft == nil { showPopup("SPIN", detail: "Nitro lost", color: Theme.bad) }
            case .lifeLost(let left):
                showToast(left > 0 ? "\(left) \(left == 1 ? "life" : "lives") left" : "Out of lives", .bad)
            case .softTouch:
                Sound.play(.softTouch)
                Haptics.light(0.5)
                if request.def.world == .harbour { showHint("World 1 echoes are soft. From World 2 on, touching one spins you out.", key: "soft", seconds: 5) }
            case .draftStart:
                Sound.play(.draft, volume: 0.7)
                Haptics.tap()
                showPopup("SLIPSTREAM", detail: nil, color: .white)
            case .boost:
                Sound.play(.boost)
                Haptics.rigid()
                punchRequested = true
                showPopup("NITRO", detail: nil, color: Theme.accent)
                if tutorialStep == .nitro { lessonDone(.done); showHint("That's everything. Beat \(rival.name).", key: "done", seconds: 4) }
            case .boostEmpty:
                Sound.play(.boostEmpty, volume: 0.6)
                showHint("Nitro is empty. Drift, ride the edge or pass an echo close to fill it.", key: "empty", seconds: 4)
            case .driftStart:
                Sound.play(.drift, volume: 0.6)
            case .driftTier(let tier):
                Sound.play(.driftTier(tier), volume: 0.7)
                Haptics.medium()
                if tier == 1 && tutorialStep == .drift { lessonDone(.release) }
            case .driftBoost(let tier):
                if tier > 0 {
                    Sound.play(.driftBoost, volume: 0.9)
                    Haptics.rigid()
                    punchRequested = true
                    showPopup(tier >= 3 ? "ULTRA DRIFT" : (tier == 2 ? "SUPER DRIFT" : "DRIFT BOOST"), detail: nil, color: Theme.driftColor(tier))
                    if tutorialStep == .release { lessonDone(.nitro) }
                }
            case .nearMiss:
                Sound.play(.nearMiss)
                Haptics.heavy()
                flashRequested = true
                if !calm { slowMoLeft = 0.22 }
                showPopup("NEAR MISS", detail: "+ nitro", color: Theme.good)
            case .edgeStart:
                Sound.play(.edge, volume: 0.5)
                showPopup("EDGE", detail: nil, color: .white)
            case .edgeEnd:
                break
            case .wallHit:
                Sound.play(.gateHit, volume: 0.7)
                Haptics.medium()
                shakeRequested = true
            case .gateOpened:
                Sound.play(.gateOpen, volume: 0.6)
            case .gateClosed:
                Sound.play(.gateClose, volume: 0.5)
            case .gateHit:
                Sound.play(.gateHit)
                Haptics.medium()
                showToast("Gate closed", .bad)
            case .dock:
                Sound.play(.dock)
                Haptics.medium()
                showHint(built.track.shortcut?.trigger == .pad
                         ? "Parked: the gate is open. Swipe up to leave. Your echo will park here on later runs."
                         : "Swipe up to leave.", key: "dock", seconds: 6)
            case .undock:
                Sound.play(.undock)
            case .iceCrack:
                Sound.play(.iceCrack, volume: 0.7)
                Haptics.light(0.6)
            case .iceBreak:
                Sound.play(.iceBreak)
                showToast("The ice broke", .info)
            case .splash:
                Sound.play(.splash)
                Haptics.heavy()
                shakeRequested = true
                showToast("Splash!", .bad)
            case .swap:
                Sound.play(.swap)
                Haptics.rigid()
            case .swapUnavailable:
                if request.def.features.contains(.relay) { Haptics.warning() }
            case .jump:
                Sound.play(.jump)
            case .land:
                Sound.play(.land)
                Haptics.medium()
            case .finished:
                finish()
            }
        }
    }

    private func finish() {
        Sound.play(.finish)
        Haptics.success()
        SoundEngine.shared.stopEngine()
        let result = race.result()
        let run = result.finished ? SavedRun(race: race) : nil
        let summary = app?.record(result, request: request, targets: request.def.mode == .career ? built.targets : nil, run: run)
        publishHUD()
        hint = nil
        popup = nil
        tutorialStep = nil
        outcome = Outcome(result: result, summary: summary, targets: request.def.mode == .career ? built.targets : nil,
                          isTutorial: request.kind == .tutorial)
    }

    // MARK: - Rival

    /// Where the rival is: they drive the racing line at exactly the gold pace, so finishing ahead of them is 3 stars.
    var rivalPose: (position: Vec2, heading: Double)? {
        guard request.def.mode == .career, race.crossedStart, outcome == nil,
              let progress = built.targets.goldProgress(atTime: race.time, goldSlack: difficulty.goldSlack),
              progress < Double(race.laps) * race.track.length else { return nil }
        return racingLine.pose(atProgress: progress)
    }

    // MARK: - HUD

    private func publishHUD() {
        var h = HUD()
        h.laps = race.laps == Int.max ? 0 : race.laps
        h.lap = race.currentLap
        h.time = race.time
        h.boost = race.boostCharge
        h.boostReady = race.boostCharge >= Race.boostCost
        h.boosting = race.car.boostTime > 0
        h.gateOpen = race.gateOpen
        h.docked = race.car.docked
        h.lives = race.livesLeft
        h.countdown = race.phase == .countdown ? max(1, Int(race.countdown.rounded(.up))) : nil
        h.runUp = race.isRunUp
        h.speed = max(0, race.car.forwardSpeed) / spec.topSpeed
        h.swapAvailable = request.def.features.contains(.relay) && !race.swapUsedThisLap && race.crossedStart
        h.drifting = race.car.drifting
        h.driftTier = race.car.driftTier
        h.onEdge = race.onEdge
        let car = race.car
        h.wrongWay = race.phase == .racing && !car.docked && !car.isSpinning && car.forwardSpeed > 40
            && car.forward.dot(race.track.tangents[race.location.index]) < -0.3
        if request.def.mode == .career, race.crossedStart,
           let pace = built.targets.goldPaceTime(atProgress: race.totalProgress, goldSlack: difficulty.goldSlack) {
            h.delta = race.time - pace
        }
        let poses = race.echoPoses()
        h.echoes = race.echoes.enumerated().map { i, echo in
            guard let pose = poses[i] else { return EchoChip(id: echo.lap, state: .done) }
            return EchoChip(id: echo.lap, state: pose.docked ? .parked : (echo.solid && !race.track.def.softEchoes ? .solid : .ghost))
        }
        if h != hud { hud = h }
    }

    func showToast(_ text: String, _ tone: Toast.Tone) {
        toast = Toast(text: text, tone: tone)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    func showPopup(_ text: String, detail: String?, color: Color) {
        popup = Popup(text: text, detail: detail, color: color)
        popupTask?.cancel()
        popupTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.9))
            if !Task.isCancelled { self?.popup = nil }
        }
    }

    /// Coaching hints: each shown once per race, only while hints are on.
    func showHint(_ text: String, key: String, seconds: Double, delay: Double = 0) {
        guard settings.showHints || request.kind == .tutorial, !shownHints.contains(key) else { return }
        shownHints.insert(key)
        hintTask?.cancel()
        hintTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            self?.hint = text
            UIAccessibility.post(notification: .announcement, argument: text)
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { self?.hint = nil }
        }
    }
}
