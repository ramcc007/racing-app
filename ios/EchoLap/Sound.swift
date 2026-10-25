import AVFoundation

/// Every sound in the game, synthesised in code at launch: no audio files, nothing to license.
enum SoundEffect: Hashable {
    case countdown, go, lap, echoJoin, draft, boost, boostEmpty, bump, softTouch, gateOpen, gateClose, gateHit
    case dock, undock, iceCrack, iceBreak, splash, swap, jump, land, finish, star(Int), tap, buy, unlock
    case drift, driftTier(Int), driftBoost, nearMiss, edge
}

/// Pre-renders each effect once and plays it on one of several player nodes, plus a looping engine note whose pitch
/// follows the car's speed. Uses the ambient category: respects the silent switch and never stops the player's music.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    var enabled = true {
        didSet { if !enabled { stopEngine() } }
    }
    private let sampleRate = 44100.0
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private let motor = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var next = 0
    private var prepared = false
    private var motorRunning = false
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    private var silent: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-EchoScene") || ProcessInfo.processInfo.arguments.contains("-EchoUITest") { return true }
        #endif
        return !enabled
    }

    func play(_ effect: SoundEffect, volume: Float = 1) {
        guard !silent else { return }
        prepare()
        guard prepared else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning, let buffer = buffer(for: effect) else { return }
        let node = players[next]
        next = (next + 1) % players.count
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    /// Engine note: speed 0...1 of top speed, boosting raises the pitch a little more.
    func updateEngine(speed: Double, boosting: Bool, running: Bool) {
        guard !silent, running else {
            stopEngine()
            return
        }
        prepare()
        guard prepared else { return }
        if !engine.isRunning { try? engine.start() }
        if !motorRunning, let loop = motorLoop() {
            motor.scheduleBuffer(loop, at: nil, options: .loops)
            motor.play()
            motorRunning = true
        }
        let s = Float(max(0, min(1.3, speed)))
        varispeed.rate = 0.55 + 1.05 * s + (boosting ? 0.25 : 0)
        motor.volume = 0.10 + 0.14 * s
    }

    func stopEngine() {
        guard motorRunning else { return }
        motor.stop()
        motorRunning = false
    }

    private func prepare() {
        guard !prepared else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        for _ in 0..<6 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }
        engine.attach(motor)
        engine.attach(varispeed)
        engine.connect(motor, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
        prepared = true
    }

    private func buffer(for effect: SoundEffect) -> AVAudioPCMBuffer? {
        if let cached = buffers[effect] { return cached }
        let made = render(effect)
        buffers[effect] = made
        return made
    }

    // MARK: - Synthesis

    private func note(_ f: Double, at t: Double, decay: Double, volume: Double = 1) -> Double {
        guard t >= 0 else { return 0 }
        let attack = 1 - exp(-t * 500)
        return (sin(2 * .pi * f * t) + 0.3 * sin(4 * .pi * f * t) * exp(-t * decay * 0.6)) * attack * exp(-t * decay) * volume
    }

    private func noise(_ i: Int) -> Double {
        var x = UInt32(truncatingIfNeeded: i &* 2_654_435_761)
        x ^= x << 13; x ^= x >> 17; x ^= x << 5
        return Double(x % 20001) / 10000.0 - 1.0
    }

    private func make(_ duration: Double, _ sample: (Int, Double) -> Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { channel[i] = Float(max(-0.95, min(0.95, sample(i, Double(i) / sampleRate)))) }
        return buffer
    }

    /// One second of a buzzy two-stroke note (55 Hz with harmonics and a little grit), seamless when looped.
    private func motorLoop() -> AVAudioPCMBuffer? {
        make(1.0) { [self] i, t in
            let f = 55.0
            var v = 0.0
            for h in 1...6 { v += sin(2 * .pi * f * Double(h) * t) / Double(h) * (h % 2 == 0 ? 0.6 : 1) }
            return v * 0.35 + noise(i) * 0.04
        }
    }

    private func render(_ effect: SoundEffect) -> AVAudioPCMBuffer? {
        switch effect {
        case .countdown: return make(0.18) { [self] _, t in note(660, at: t, decay: 18, volume: 0.6) }
        case .go: return make(0.45) { [self] _, t in 0.6 * (note(990, at: t, decay: 7) + note(1320, at: t, decay: 9, volume: 0.5)) }
        case .lap: return make(0.5) { [self] _, t in 0.5 * (note(784, at: t, decay: 8) + note(1046.5, at: t - 0.08, decay: 8)) }
        case .echoJoin:
            return make(0.6) { [self] i, t in
                let sweep = sin(2 * .pi * (300 + 500 * t) * t) * exp(-t * 5) * 0.35
                return sweep + note(1318.5, at: t - 0.12, decay: 9, volume: 0.25) + noise(i) * exp(-t * 30) * 0.05
            }
        case .draft: return make(0.12) { [self] _, t in note(1760, at: t, decay: 40, volume: 0.25) }
        case .boost:
            return make(0.7) { [self] i, t in
                let whoosh = noise(i) * exp(-pow(t - 0.18, 2) * 40) * 0.5
                return whoosh + sin(2 * .pi * (180 + 900 * t) * t) * exp(-t * 4) * 0.25
            }
        case .boostEmpty: return make(0.12) { [self] _, t in note(220, at: t, decay: 30, volume: 0.4) }
        case .bump:
            return make(0.35) { [self] i, t in
                sin(2 * .pi * (70 + 90 * exp(-t * 25)) * t) * exp(-t * 14) * 0.9 + noise(i) * exp(-t * 60) * 0.4
            }
        case .softTouch: return make(0.15) { [self] i, t in noise(i) * exp(-t * 40) * 0.2 + note(440, at: t, decay: 30, volume: 0.15) }
        case .gateOpen: return make(0.4) { [self] _, t in 0.5 * (note(523.25, at: t, decay: 8) + note(783.99, at: t - 0.07, decay: 8)) }
        case .gateClose: return make(0.3) { [self] _, t in 0.5 * (note(392, at: t, decay: 10) + note(261.6, at: t - 0.06, decay: 10)) }
        case .gateHit: return make(0.3) { [self] i, t in sin(2 * .pi * 110 * t) * exp(-t * 12) * 0.7 + noise(i) * exp(-t * 50) * 0.3 }
        case .dock: return make(0.3) { [self] i, t in note(330, at: t, decay: 14, volume: 0.6) + noise(i) * exp(-t * 80) * 0.2 }
        case .undock: return make(0.3) { [self] _, t in sin(2 * .pi * (200 + 600 * t) * t) * exp(-t * 8) * 0.4 }
        case .iceCrack:
            return make(0.25) { [self] i, t in
                var v = 0.0
                for k in 0..<4 { let tk = t - Double(k) * 0.045; if tk > 0 { v += noise(i * (k + 3)) * exp(-tk * 90) } }
                return v * 0.5
            }
        case .iceBreak:
            return make(0.7) { [self] i, t in noise(i) * exp(-t * 6) * 0.6 + note(1600, at: t, decay: 12, volume: 0.2) }
        case .splash:
            return make(0.8) { [self] i, t in
                let n = (noise(i) + noise(i + 1) + noise(i + 2)) / 3
                return n * exp(-t * 4) * 0.8 + sin(2 * .pi * 90 * t) * exp(-t * 10) * 0.3
            }
        case .swap:
            return make(0.4) { [self] _, t in
                sin(2 * .pi * (1200 - 900 * t) * t) * exp(-t * 7) * 0.35 + note(1568, at: t - 0.15, decay: 10, volume: 0.25)
            }
        case .jump: return make(0.45) { [self] _, t in sin(2 * .pi * (240 + 500 * t) * t) * exp(-t * 4) * 0.35 }
        case .land: return make(0.25) { [self] i, t in sin(2 * .pi * 80 * t) * exp(-t * 16) * 0.7 + noise(i) * exp(-t * 70) * 0.25 }
        case .finish:
            return make(1.2) { [self] _, t in
                0.4 * (note(523.25, at: t, decay: 4) + note(659.25, at: t - 0.12, decay: 4) + note(783.99, at: t - 0.24, decay: 4)
                       + note(1046.5, at: t - 0.36, decay: 3))
            }
        case .star(let k):
            let f = [783.99, 987.77, 1174.66][max(0, min(2, k))]
            return make(0.45) { [self] _, t in note(f, at: t, decay: 7, volume: 0.6) }
        case .tap: return make(0.05) { [self] _, t in note(1400, at: t, decay: 120, volume: 0.25) }
        case .drift:
            // A short tyre squeal: filtered noise with a falling whine.
            return make(0.3) { [self] i, t in noise(i) * exp(-t * 9) * 0.22 + sin(2 * .pi * (900 - 300 * t) * t) * exp(-t * 10) * 0.12 }
        case .driftTier(let k):
            let f = [0.0, 880, 1108.7, 1318.5][max(0, min(3, k))]
            return make(0.2) { [self] _, t in note(f, at: t, decay: 16, volume: 0.45) + note(f * 1.5, at: t - 0.05, decay: 18, volume: 0.25) }
        case .driftBoost:
            return make(0.5) { [self] i, t in
                noise(i) * exp(-pow(t - 0.1, 2) * 60) * 0.35 + sin(2 * .pi * (300 + 1200 * t) * t) * exp(-t * 5) * 0.3
            }
        case .nearMiss:
            // A fast whoosh past the ear.
            return make(0.35) { [self] i, t in noise(i) * exp(-pow(t - 0.12, 2) * 120) * 0.7 + note(2200, at: t - 0.1, decay: 20, volume: 0.2) }
        case .edge: return make(0.12) { [self] i, t in noise(i) * exp(-t * 50) * 0.18 + note(1760, at: t, decay: 35, volume: 0.15) }
        case .buy:
            return make(0.6) { [self] _, t in 0.4 * (note(880, at: t, decay: 6) + note(1318.5, at: t - 0.08, decay: 6) + note(1760, at: t - 0.16, decay: 6)) }
        case .unlock:
            return make(0.9) { [self] _, t in
                0.35 * (note(659.25, at: t, decay: 5) + note(830.6, at: t - 0.07, decay: 5) + note(987.8, at: t - 0.14, decay: 5)
                        + note(1318.5, at: t - 0.21, decay: 4))
            }
        }
    }
}

/// Call sites use `Sound.play(.lap)`, like `Haptics`.
@MainActor
enum Sound {
    static var enabled: Bool {
        get { SoundEngine.shared.enabled }
        set { SoundEngine.shared.enabled = newValue }
    }

    static func play(_ effect: SoundEffect, volume: Float = 1) { SoundEngine.shared.play(effect, volume: volume) }
}
