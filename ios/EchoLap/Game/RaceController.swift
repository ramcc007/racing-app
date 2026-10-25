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
        let id: Int   // lap number
        let state: State
    }

    struct HUD: Equatable {
        var lap = 1
        var laps = 1
        var time = 0.0
        var delta: Double?
        var boost = 0.0
        var boostReady = false
        var echoes: [EchoChip] = []
        var gateOpen = false
        var docked = false
        var lives: Int?
        var countdown: Int?
        var runUp = true
        var speed = 0.0
        var swapAvailable = false
    }

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let tone: Tone
        enum Tone { case info, good, bad }
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
    @Published private(set) var hint: String?
    @Published private(set) var isPaused = false
    @Published private(set) var outcome: Outcome?

    let request: RaceRequest
    let built: BuiltTrack
    let race: Race
    let spec: CarSpec
    let ghost: Ghost?
    let isDemo: Bool
    private weak var app: AppModel?
    private var settings: GameSettings
    private var recorder = GhostRecorder()
    private var autopilot: RobotDriver?
    private var ticksPerStep = 1
    private var accumulator = 0.0
    private var frame = 0
    private var lastDriftHaptic = 0.0
    private var toastTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private var shownHints: Set<String> = []
    /// Set for one frame when a bump happens (the scene shakes the camera).
    private(set) var shakeRequested = false

    // Input
    private var touching = false
    private var touchSteer = 0.0
    private var pendingBoost = false
    private var pendingSwap = false
    private let motion = CMMotionManager()

    init(request: RaceRequest, built: BuiltTrack, app: AppModel?, demo: Bool = false, startPaused: Bool = false) {
        self.request = request
        self.built = built
        self.app = app
        self.isDemo = demo
        let progress = app?.progress ?? PlayerProgress()
        settings = progress.settings
        spec = demo ? Cars.pip : Cars.car(id: progress.selectedCar)
        let lives = request.def.mode == .survival ? 3 : nil
        race = Race(track: built.track, spec: spec, laps: demo ? Int.max : (request.def.mode == .survival ? Int.max : request.def.laps),
                    lives: lives)
        ghost = demo || !progress.settings.showGhost ? nil : app?.ghost(for: request.def.id)
        if demo {
            let driver = RobotDriver(track: built.track, plan: built.targets.plan)
            driver.weave = 0.35
            autopilot = driver
        }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if !demo && (args.contains("-EchoUITest") || args.contains("-EchoAutopilot") || args.contains("-EchoScene")) {
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
        if request.kind == .tutorial { showHint("Hold anywhere and slide left or right to steer.", key: "steer", seconds: 6) }
        publishHUD()
    }

    deinit {
        motion.stopDeviceMotionUpdates()
    }

    var difficulty: Difficulty { built.track.difficulty }

    // MARK: - Frame

    /// Called by the scene every frame with the real elapsed time.
    func advance(_ elapsed: Double) {
        shakeRequested = false
        guard !isPaused, outcome == nil else {
            SoundEngine.shared.updateEngine(speed: 0, boosting: false, running: false)
            return
        }
        accumulator += min(elapsed, 0.1) * Double(ticksPerStep)
        while accumulator >= Physics.dt && outcome == nil {
            accumulator -= Physics.dt
            race.tick(currentInput())
            recorder.capture(race)
            handleEvents()
        }
        frame += 1
        if race.car.drifting && race.time - lastDriftHaptic > 0.12 && !isDemo {
            lastDriftHaptic = race.time
            Haptics.light(0.35)
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
        var throttle = touching
        if settings.tiltSteering, let gravity = motion.deviceMotion?.gravity {
            steer = clamp(gravity.x * 2.6, -1, 1)
        }
        if let pad = GCController.current?.extendedGamepad {
            let stick = Double(pad.leftThumbstick.xAxis.value)
            let dpad = Double(pad.dpad.xAxis.value)
            if abs(stick) > 0.08 || abs(dpad) > 0.5 { steer = abs(stick) > abs(dpad) ? stick : dpad }
            if pad.buttonA.isPressed || pad.rightTrigger.value > 0.2 { throttle = true }
            if pad.buttonB.isPressed && !controllerBoostHeld { pendingBoost = true }
            controllerBoostHeld = pad.buttonB.isPressed
            if pad.buttonX.isPressed && !controllerSwapHeld { pendingSwap = true }
            controllerSwapHeld = pad.buttonX.isPressed
        }
        let input = ControlInput(throttle: throttle, steer: steer, boost: pendingBoost, swap: pendingSwap)
        pendingBoost = false
        pendingSwap = false
        return input
    }

    private var controllerBoostHeld = false
    private var controllerSwapHeld = false

    // MARK: - Input from the scene and HUD

    func touchBegan() { touching = true }

    /// Steering from the thumb's sideways travel, already scaled to -1...1 by the scene.
    func touchSteered(_ value: Double) { touchSteer = clamp(value, -1, 1) }

    func touchEnded() {
        touching = false
        touchSteer = 0
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
                if request.kind == .tutorial {
                    showHint("Lift your thumb to slow down before tight corners.", key: "lift", seconds: 5, delay: 3)
                }
            case .lap(let n, let t):
                Sound.play(.lap)
                Haptics.medium()
                if race.laps == Int.max {
                    showToast("Lap \(n) · \(TimeFormat.race(t))", .good)
                } else if n < race.laps {
                    showToast("Lap \(n) · \(TimeFormat.race(t))", .info)
                }
            case .echoSpawned(let lap):
                Sound.play(.echoJoin, volume: 0.8)
                if request.kind == .tutorial && lap == 1 {
                    showHint("Lap 2: your first lap is back as an echo. Get right behind it to fill BOOST.", key: "echo", seconds: 7)
                } else if lap == 1 {
                    showToast("Your lap 1 echo joins", .info)
                }
            case .bump:
                Sound.play(.bump)
                Haptics.heavy()
                shakeRequested = true
                if race.livesLeft == nil { showToast("Bump \u{2212}\(String(format: "%.1f", difficulty.bumpPenalty * spec.bumpFactor)) s", .bad) }
            case .lifeLost(let left):
                showToast(left > 0 ? "\(left) \(left == 1 ? "life" : "lives") left" : "Out of lives", .bad)
            case .softTouch:
                Sound.play(.softTouch)
                Haptics.light(0.5)
                if request.def.world == .harbour { showHint("World 1 echoes are soft. From World 2 on, bumping one spins you out.", key: "soft", seconds: 5) }
            case .draftStart:
                Sound.play(.draft, volume: 0.7)
                Haptics.tap()
            case .boost:
                Sound.play(.boost)
                Haptics.rigid()
            case .boostEmpty:
                Sound.play(.boostEmpty, volume: 0.6)
                showHint("Boost is empty. Slipstream right behind an echo to fill it.", key: "empty", seconds: 4)
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
                         ? "Parked: the gate is open. Swipe up to leave. Your echo will park here on later laps."
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
        if request.kind == .tutorial, race.boostCharge >= Race.boostCost, !shownHints.contains("boost") {
            showHint("Boost ready! Swipe up anywhere.", key: "boost", seconds: 5)
        }
    }

    private func finish() {
        Sound.play(.finish)
        Haptics.success()
        SoundEngine.shared.stopEngine()
        let result = race.result()
        let ghostRun = result.finished ? recorder.ghost(trackID: request.def.id, totalTime: result.totalTime) : nil
        let summary = app?.record(result, request: request, targets: request.def.mode == .career ? built.targets : nil, ghost: ghostRun)
        publishHUD()
        hint = nil
        outcome = Outcome(result: result, summary: summary, targets: request.def.mode == .career ? built.targets : nil,
                          isTutorial: request.kind == .tutorial)
    }

    // MARK: - HUD

    private func publishHUD() {
        var h = HUD()
        h.laps = race.laps == Int.max ? 0 : race.laps
        h.lap = race.currentLap
        h.time = race.time
        h.boost = race.boostCharge
        h.boostReady = race.boostCharge >= Race.boostCost
        h.gateOpen = race.gateOpen
        h.docked = race.car.docked
        h.lives = race.livesLeft
        h.countdown = race.phase == .countdown ? max(1, Int(race.countdown.rounded(.up))) : nil
        h.runUp = race.isRunUp
        h.speed = max(0, race.car.forwardSpeed) / spec.topSpeed
        h.swapAvailable = request.def.features.contains(.relay) && !race.swapUsedThisLap && race.crossedStart
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
