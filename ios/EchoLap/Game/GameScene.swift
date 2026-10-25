import SpriteKit
import UIKit
import EchoLapCore

/// Draws a race. The simulation lives in RaceController/Race; this scene only mirrors it and reads touches.
/// Scale mode .resizeFill and a zoom based on the shorter side keep it right on every iPhone, iPad window and fold.
@MainActor
final class GameScene: SKScene {
    private let controller: RaceController
    private let style: WorldStyle
    private let settings: GameSettings
    private let calm: Bool
    private var art: TrackArt!
    private let cam = SKCameraNode()
    private let world = SKNode()
    private var player: SKSpriteNode!
    private var playerShadow: SKSpriteNode!
    private var boostFlame: SKShapeNode!
    private var draftLines: SKNode!
    private var echoNodes: [Int: (car: SKSpriteNode, label: SKLabelNode, trail: SKShapeNode)] = [:]
    private var rivalNode: SKSpriteNode?
    private var skids: [SKShapeNode] = []
    private var skidIndex = 0
    private var sparks: [SKShapeNode] = []
    private var sparkIndex = 0
    private var speedLines: [SKShapeNode] = []
    private var flash: SKSpriteNode!
    private var lastTime: TimeInterval?
    private var camAngle: CGFloat = 0
    private var punch: CGFloat = 0
    private var gateWasOpen = false
    private var celebrated = false
    private let trailStyle: String
    private let paintID: String

    // Touch state (UIKit points)
    private var steerTouch: UITouch?
    private var anchor: CGPoint = .zero
    private var swipeStartY: CGFloat = 0
    private var swipeStartTime: TimeInterval = 0
    private var touchStart: (CGPoint, TimeInterval) = (.zero, 0)
    private var lastTapEnd: TimeInterval = 0

    private let celebration: String

    init(controller: RaceController, settings: GameSettings, reduceMotion: Bool, trail: String, paint: String,
         celebration: String = "finish.confetti") {
        self.controller = controller
        self.celebration = celebration
        self.paintID = controller.isDemo ? "paint.factory" : paint
        self.style = WorldStyle.of(controller.request.def.world)
        self.settings = settings
        self.calm = reduceMotion || settings.calmEffects
        self.trailStyle = trail
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(hex: style.ground)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 120
        view.ignoresSiblingOrder = true
        guard art == nil else { return }
        addChild(world)
        addChild(cam)
        camera = cam
        art = TrackArt(track: controller.built.track, style: style, view: view)
        world.addChild(art.root)

        let (body, stripe) = CarArt.colors(for: controller.spec, paint: paintID)
        let texture = CarArt.texture(shape: controller.spec.shape, body: body, stripe: stripe, in: view)
        playerShadow = SKSpriteNode(texture: texture, size: CarArt.spriteSize)
        playerShadow.color = .black
        playerShadow.colorBlendFactor = 1
        playerShadow.alpha = 0.3
        playerShadow.zPosition = 9
        world.addChild(playerShadow)
        player = SKSpriteNode(texture: texture, size: CarArt.spriteSize)
        player.zPosition = 20
        world.addChild(player)

        boostFlame = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -20, y: -7)); p.addLine(to: CGPoint(x: -52, y: 0)); p.addLine(to: CGPoint(x: -20, y: 7)); p.closeSubpath()
            return p
        }())
        boostFlame.fillColor = UIColor(hex: 0xFFB547)
        boostFlame.strokeColor = UIColor(hex: 0xFF7A1A)
        boostFlame.lineWidth = 2
        boostFlame.glowWidth = 6
        boostFlame.zPosition = -1
        boostFlame.isHidden = true
        player.addChild(boostFlame)

        draftLines = SKNode()
        for side in [-1.0, 1.0] {
            for k in 0..<2 {
                let line = SKShapeNode(rectOf: CGSize(width: 22, height: 2.5), cornerRadius: 1.2)
                line.fillColor = UIColor.white.withAlphaComponent(0.75)
                line.strokeColor = .clear
                line.position = CGPoint(x: 28 + CGFloat(k) * 16, y: CGFloat(side) * (15 + CGFloat(k) * 3))
                draftLines.addChild(line)
            }
        }
        draftLines.isHidden = true
        player.addChild(draftLines)

        if controller.request.def.mode == .career && !controller.isDemo {
            // The rival: drives the racing line at exactly the gold pace. Finish ahead of them for three stars.
            let rival = controller.rival
            let r = SKSpriteNode(texture: CarArt.texture(shape: rival.shape, body: UIColor(hex: rival.color), stripe: UIColor.white.withAlphaComponent(0.5), in: view),
                                 size: CarArt.spriteSize)
            r.alpha = 0.6
            r.zPosition = 13
            let tag = SKLabelNode(text: rival.name.uppercased())
            tag.fontName = "AvenirNext-Heavy"
            tag.fontSize = 12
            tag.fontColor = UIColor(hex: rival.color)
            tag.verticalAlignmentMode = .center
            tag.position = CGPoint(x: 0, y: 0)
            tag.name = "tag"
            let plate = SKShapeNode(rectOf: CGSize(width: CGFloat(rival.name.count) * 9 + 14, height: 16), cornerRadius: 8)
            plate.fillColor = UIColor.black.withAlphaComponent(0.55)
            plate.strokeColor = .clear
            plate.zPosition = -0.5
            tag.addChild(plate)
            r.addChild(tag)
            r.isHidden = true
            world.addChild(r)
            rivalNode = r
        }
        if settings.showGuide && !controller.isDemo { addDirectionArrows() }
        for _ in 0..<160 {
            let s = SKShapeNode(rectOf: CGSize(width: 9, height: 4), cornerRadius: 2)
            s.fillColor = UIColor.black.withAlphaComponent(0.28)
            s.strokeColor = .clear
            s.zPosition = -12.5
            s.alpha = 0
            world.addChild(s)
            skids.append(s)
        }
        for _ in 0..<90 {
            let s = SKShapeNode(rectOf: CGSize(width: 5, height: 2.5), cornerRadius: 1)
            s.fillColor = .white
            s.strokeColor = .clear
            s.zPosition = 19
            s.alpha = 0
            world.addChild(s)
            sparks.append(s)
        }
        // Speed lines live on the camera: thin streaks near the edges of the screen at high speed.
        for k in 0..<14 {
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: 60 + CGFloat(k % 4) * 30), cornerRadius: 1)
            line.fillColor = UIColor.white.withAlphaComponent(0.55)
            line.strokeColor = .clear
            line.zPosition = 50
            line.alpha = 0
            cam.addChild(line)
            speedLines.append(line)
        }
        flash = SKSpriteNode(color: .white, size: CGSize(width: 4000, height: 4000))
        flash.zPosition = 60
        flash.alpha = 0
        cam.addChild(flash)
        sync(immediate: true)
    }

    // MARK: - Frame

    override func update(_ currentTime: TimeInterval) {
        let elapsed = lastTime.map { currentTime - $0 } ?? 0
        lastTime = currentTime
        controller.advance(elapsed)
        sync(immediate: false)
    }

    private var zoom: CGFloat {
        // About 470 world units across the shorter side on phones, up to 780 on big iPad windows.
        let short = max(1, min(size.width, size.height))
        let visible = min(max(short * 1.2, 470), 780)
        return visible / short
    }

    private func sync(immediate: Bool) {
        guard let player else { return }
        let race = controller.race
        let car = race.car
        player.position = CGPoint(x: car.position.x, y: car.position.y)
        player.zRotation = CGFloat(car.heading)
        let lift: CGFloat = car.isAirborne ? 1.25 : 1
        player.setScale(lift)
        playerShadow.position = CGPoint(x: car.position.x + (car.isAirborne ? 16 : 5), y: car.position.y - (car.isAirborne ? 22 : 7))
        playerShadow.zRotation = player.zRotation
        boostFlame.isHidden = car.boostTime <= 0
        if !boostFlame.isHidden { boostFlame.xScale = 0.8 + 0.5 * CGFloat.random(in: 0...1) }
        draftLines.isHidden = !race.drafting || calm
        player.alpha = car.isSpinning && Int(race.time * 12) % 2 == 0 ? 0.6 : 1

        // Camera: follows a little ahead; in Follow mode it turns so the car drives up the screen.
        let ahead = car.forward * Double(size.height * zoom * 0.2)
        let target = CGPoint(x: car.position.x + ahead.x, y: car.position.y + ahead.y)
        let follow = settings.camera == .follow && !calm
        let wantAngle = follow ? CGFloat(car.heading) - .pi / 2 : 0
        if immediate {
            cam.position = target
            camAngle = wantAngle
        } else {
            cam.position = CGPoint(x: cam.position.x + (target.x - cam.position.x) * 0.25, y: cam.position.y + (target.y - cam.position.y) * 0.25)
            let diff = CGFloat(wrapAngle(Double(wantAngle - camAngle)))
            camAngle += diff * (follow ? 0.12 : 1)
        }
        cam.zRotation = camAngle
        if controller.punchRequested && !calm { punch = 1 }
        punch = max(0, punch - 0.06)
        let speedFraction = CGFloat(max(0, min(1.3, car.forwardSpeed / controller.spec.topSpeed)))
        let speedZoom = calm ? 1 : 1 + 0.09 * speedFraction - 0.05 * punch
        cam.setScale(zoom * speedZoom)
        if controller.shakeRequested && !calm {
            cam.run(.sequence([.moveBy(x: 7, y: -5, duration: 0.04), .moveBy(x: -12, y: 8, duration: 0.05), .moveBy(x: 5, y: -3, duration: 0.04)]))
        }
        if controller.flashRequested && !calm {
            flash.removeAllActions()
            flash.alpha = 0.35
            flash.run(.fadeOut(withDuration: 0.25))
        }

        syncEchoes()
        syncRival()
        syncSpeedLines(speedFraction: speedFraction, boosting: car.boostTime > 0)
        syncSparks(car: car, race: race)

        if race.gateOpen != gateWasOpen || immediate {
            art.setGate(open: race.gateOpen, animated: !immediate)
            gateWasOpen = race.gateOpen
        }
        if !race.iceWear.isEmpty { art.setIce(wear: race.iceWear) }
        art.setPadOccupied(race.gateOpen && race.track.shortcut?.trigger == .pad)

        if car.drifting && !car.isAirborne && Int(race.time * 120) % 2 == 0 {
            let back = car.position - car.forward * 14
            for side in [-1.0, 1.0] {
                let p = back + car.forward.perp * (side * 9)
                let s = skids[skidIndex]
                skidIndex = (skidIndex + 1) % skids.count
                s.removeAllActions()
                s.position = CGPoint(x: p.x, y: p.y)
                s.zRotation = CGFloat(car.heading)
                s.alpha = 1
                s.run(.fadeOut(withDuration: 2.5))
            }
        }
        if race.isFinished && !celebrated && !controller.isDemo {
            celebrated = true
            celebrate(at: player.position)
        }
    }

    private func syncRival() {
        guard let rivalNode else { return }
        if let pose = controller.rivalPose {
            rivalNode.isHidden = false
            rivalNode.position = CGPoint(x: pose.position.x, y: pose.position.y)
            rivalNode.zRotation = CGFloat(pose.heading)
            rivalNode.childNode(withName: "tag")?.zRotation = camAngle - CGFloat(pose.heading)
        } else {
            rivalNode.isHidden = true
        }
    }

    /// Streaks at the screen edges when going fast, brighter while boosting.
    private func syncSpeedLines(speedFraction: CGFloat, boosting: Bool) {
        guard !calm else { return }
        let strength = boosting ? 1 : max(0, (speedFraction - 0.82) / 0.3)
        let w = size.width * zoom, h = size.height * zoom
        for (k, line) in speedLines.enumerated() {
            guard strength > 0 else { line.alpha = 0; continue }
            if line.alpha <= 0.01 || Int.random(in: 0..<10) == 0 {
                let side: CGFloat = k % 2 == 0 ? -1 : 1
                line.position = CGPoint(x: side * (w * 0.5 - CGFloat.random(in: 6...60)), y: CGFloat.random(in: -h * 0.5 ... h * 0.5))
            }
            line.position.y -= 40 * strength
            if line.position.y < -h * 0.5 { line.position.y = h * 0.5 }
            line.alpha = 0.25 + 0.5 * strength
        }
    }

    /// Drift sparks at the rear wheels (coloured by tier) and small white sparks when riding the edge.
    private func syncSparks(car: CarState, race: Race) {
        guard !calm, !car.isAirborne else { return }
        if car.drifting && Int(race.time * 120) % 2 == 0 {
            let color = Theme.driftUI[clamp(car.driftTier, 0, 3)]
            let back = car.position - car.forward * 16
            for _ in 0..<2 {
                let side = Double.random(in: 0...1) < 0.5 ? -1.0 : 1.0
                spark(at: back + car.forward.perp * (side * 10), color: color,
                      velocity: car.forward * -Double.random(in: 60...160) + car.forward.perp * (side * Double.random(in: 20...80)))
            }
        }
        if race.onEdge && Int(race.time * 120) % 4 == 0 {
            let outward = race.location.lateral > 0 ? race.track.normal(race.location.index) : race.track.normal(race.location.index) * -1
            spark(at: car.position + outward * 12 - car.forward * 8, color: .white,
                  velocity: outward * Double.random(in: 40...90) - car.forward * Double.random(in: 60...120))
        }
    }

    private func spark(at p: Vec2, color: UIColor, velocity: Vec2) {
        let s = sparks[sparkIndex]
        sparkIndex = (sparkIndex + 1) % sparks.count
        s.removeAllActions()
        s.fillColor = color
        s.position = CGPoint(x: p.x, y: p.y)
        s.zRotation = CGFloat(velocity.angle)
        s.alpha = 1
        s.setScale(CGFloat.random(in: 0.8...1.6))
        let d = 0.3
        s.run(.group([.moveBy(x: velocity.x * d, y: velocity.y * d, duration: d), .fadeOut(withDuration: d)]))
    }

    /// White chevrons painted on the road, pointing the way round.
    private func addDirectionArrows() {
        let track = controller.built.track
        let spacing = 240.0
        let every = max(1, Int(spacing / track.step))
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -9, y: 13)); path.addLine(to: CGPoint(x: 9, y: 0)); path.addLine(to: CGPoint(x: -9, y: -13))
        for i in stride(from: every / 2, to: track.count, by: every) {
            let p = track.points[i]
            let lateral = controller.racingLine.lateral[i]
            let c = p + track.normal(i) * (lateral * 0.5)
            let arrow = SKShapeNode(path: path)
            arrow.strokeColor = UIColor.white.withAlphaComponent(0.42)
            arrow.lineWidth = 5
            arrow.lineCap = .round
            arrow.lineJoin = .round
            arrow.position = CGPoint(x: c.x, y: c.y)
            arrow.zRotation = CGFloat(track.tangents[i].angle)
            arrow.zPosition = -11.8
            world.addChild(arrow)
        }
    }

    private func syncEchoes() {
        let race = controller.race
        let poses = race.echoPoses()
        var seen = Set<Int>()
        for (i, echo) in race.echoes.enumerated() {
            let lap = echo.lap
            seen.insert(lap)
            let nodes = echoNodes[lap] ?? makeEcho(lap: lap)
            guard let pose = poses[i] else {
                nodes.car.isHidden = true
                nodes.trail.isHidden = true
                continue
            }
            nodes.car.isHidden = false
            nodes.trail.isHidden = false
            nodes.car.position = CGPoint(x: pose.position.x, y: pose.position.y)
            nodes.car.zRotation = CGFloat(pose.heading)
            nodes.car.setScale(pose.airborne ? 1.25 : 1)
            let solid = echo.solid && !race.track.def.softEchoes
            nodes.car.alpha = solid ? 0.92 : 0.5
            nodes.label.zRotation = camAngle - CGFloat(pose.heading)
            let frame = race.lapTick - 1
            let points = echo.trail(from: frame - 70, to: frame, every: 3)
            if points.count > 1 {
                let path = CGMutablePath()
                path.addLines(between: points.map { CGPoint(x: $0.x, y: $0.y) })
                nodes.trail.path = trailPath(path)
            }
        }
        for (lap, nodes) in echoNodes where !seen.contains(lap) {
            nodes.car.removeFromParent()
            nodes.trail.removeFromParent()
            echoNodes[lap] = nil
        }
    }

    private func trailPath(_ path: CGPath) -> CGPath {
        switch trailStyle {
        case "trail.dotted": return path.copy(dashingWithPhase: 0, lengths: [4, 10])
        case "trail.sparkle": return path.copy(dashingWithPhase: 0, lengths: [2, 14])
        default: return path
        }
    }

    private func makeEcho(lap: Int) -> (car: SKSpriteNode, label: SKLabelNode, trail: SKShapeNode) {
        let color = Theme.echoUI[(lap - 1) % Theme.echoUI.count]
        let texture = view.map { CarArt.texture(shape: controller.spec.shape, body: color, in: $0) } ?? SKTexture()
        let car = SKSpriteNode(texture: texture, size: CarArt.spriteSize)
        car.zPosition = 15
        let badge = SKShapeNode(circleOfRadius: 7)
        badge.fillColor = UIColor.black.withAlphaComponent(0.55)
        badge.strokeColor = .clear
        badge.position = CGPoint(x: -6, y: 0)
        car.addChild(badge)
        let label = SKLabelNode(text: "\(lap)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 10
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        badge.addChild(label)
        let trail = SKShapeNode()
        trail.strokeColor = color.withAlphaComponent(trailStyle == "trail.ribbon" ? 0.35 : 0.55)
        trail.lineWidth = trailStyle == "trail.ribbon" ? 18 : (trailStyle == "trail.comet" ? 12 : 9)
        trail.lineCap = .round
        trail.lineJoin = .round
        trail.glowWidth = (trailStyle == "trail.neon" || trailStyle == "trail.comet") ? 6 : 0
        if trailStyle == "trail.rainbow" { trail.strokeColor = Theme.echoUI[(lap + 2) % Theme.echoUI.count].withAlphaComponent(0.6) }
        trail.zPosition = 14
        world.addChild(trail)
        world.addChild(car)
        let nodes = (car, label, trail)
        echoNodes[lap] = nodes
        return nodes
    }

    /// The finish celebration the player chose in the garage. Off with Reduce Motion or calm effects.
    private func celebrate(at p: CGPoint) {
        guard !calm else { return }
        switch celebration {
        case "finish.checkered": burst(at: p, count: 36, size: CGSize(width: 14, height: 14), colors: [.white, UIColor(hex: 0x1C1E22)], spin: 2)
        case "finish.fireworks":
            for k in 0..<4 {
                let a = Double(k) * .pi / 2 + .pi / 4
                let c = CGPoint(x: p.x + cos(a) * 90, y: p.y + sin(a) * 90)
                run(.sequence([.wait(forDuration: 0.18 * Double(k)), .run { [weak self] in
                    self?.burst(at: c, count: 28, size: CGSize(width: 4, height: 4), colors: [Theme.echoUI[k * 2 % Theme.echoUI.count], .white], spin: 0)
                }]))
            }
        case "finish.stars":
            burst(at: p, count: 40, size: CGSize(width: 10, height: 10), colors: [UIColor(hex: 0xF2C94C), UIColor(hex: 0xFFE9A8)], spin: 1, star: true)
        default:
            burst(at: p, count: 60, size: CGSize(width: 6, height: 10), colors: Theme.echoUI + [UIColor(hex: 0xF2C94C), .white], spin: 4)
        }
    }

    private func burst(at p: CGPoint, count: Int, size: CGSize, colors: [UIColor], spin: Double, star: Bool = false) {
        for k in 0..<count {
            let bit: SKShapeNode
            if star {
                let path = CGMutablePath()
                for i in 0..<10 {
                    let r = i % 2 == 0 ? size.width / 2 : size.width / 4.5
                    let a = Double(i) * .pi / 5 + .pi / 2
                    let q = CGPoint(x: cos(a) * r, y: sin(a) * r)
                    if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
                }
                path.closeSubpath()
                bit = SKShapeNode(path: path)
            } else {
                bit = SKShapeNode(rectOf: size, cornerRadius: min(size.width, size.height) * 0.2)
            }
            bit.fillColor = colors[k % colors.count]
            bit.strokeColor = .clear
            bit.position = p
            bit.zPosition = 40
            world.addChild(bit)
            let a = Double.random(in: 0...(2 * .pi)), d = Double.random(in: 60...220)
            bit.run(.sequence([
                .group([.moveBy(x: cos(a) * d, y: sin(a) * d, duration: 1.1), .rotate(byAngle: .pi * spin, duration: 1.1),
                        .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.5)])]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: - Touches: one thumb anywhere. Drag sideways to steer, pull down to brake, flick up for nitro.

    private var fullLock: CGFloat { 70 / CGFloat(settings.steeringSensitivity) }
    private let brakeLine: CGFloat = 48

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches {
            let p = touch.location(in: view)
            if steerTouch == nil {
                steerTouch = touch
                anchor = p
                swipeStartY = p.y
                swipeStartTime = touch.timestamp
                touchStart = (p, touch.timestamp)
                if touch.timestamp - lastTapEnd < 0.3 { controller.requestSwap() }
                controller.touchBegan()
            } else {
                // A second finger fires the nitro (the iPad two-thumb layout, or anyone who prefers tapping).
                controller.requestBoost()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = steerTouch, touches.contains(touch) else { return }
        let p = touch.location(in: view)
        var dx = p.x - anchor.x
        if abs(dx) > fullLock {
            // Drag the anchor along so moving back straightens immediately.
            anchor.x = p.x - (dx > 0 ? fullLock : -fullLock)
            dx = dx > 0 ? fullLock : -fullLock
        }
        let v = Double(dx / fullLock)
        controller.touchSteered(v >= 0 ? pow(v, 1.15) : -pow(-v, 1.15))
        // Pull down past the brake line to brake; the anchor follows upward moves so the brake is always a pull.
        let dy = p.y - anchor.y
        if dy < 0 { anchor.y = p.y }
        controller.touchBraked(dy > brakeLine)
        // Swipe up (quick upward flick) fires the nitro, or leaves the pad bay.
        if swipeStartY - p.y > 55 && touch.timestamp - swipeStartTime < 0.3 {
            controller.requestBoost()
            swipeStartY = p.y
            swipeStartTime = touch.timestamp
        } else if touch.timestamp - swipeStartTime > 0.3 || p.y > swipeStartY {
            swipeStartY = p.y
            swipeStartTime = touch.timestamp
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = steerTouch, touches.contains(touch) else { return }
        let p = touch.location(in: view)
        let moved = hypot(p.x - touchStart.0.x, p.y - touchStart.0.y)
        if touch.timestamp - touchStart.1 < 0.22 && moved < 12 { lastTapEnd = touch.timestamp }
        steerTouch = nil
        controller.touchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        steerTouch = nil
        controller.touchEnded()
    }
}
