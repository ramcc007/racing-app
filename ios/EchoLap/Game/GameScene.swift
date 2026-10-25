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
    private var ghostNode: SKSpriteNode?
    private var skids: [SKShapeNode] = []
    private var skidIndex = 0
    private var lastTime: TimeInterval?
    private var camAngle: CGFloat = 0
    private var gateWasOpen = false
    private var celebrated = false
    private let trailStyle: String
    private let paintID: String

    // Touch state (UIKit points)
    private var steerTouch: UITouch?
    private var anchorX: CGFloat = 0
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
            p.move(to: CGPoint(x: -20, y: -7)); p.addLine(to: CGPoint(x: -46, y: 0)); p.addLine(to: CGPoint(x: -20, y: 7)); p.closeSubpath()
            return p
        }())
        boostFlame.fillColor = UIColor(hex: 0xFFB547)
        boostFlame.strokeColor = UIColor(hex: 0xFF7A1A)
        boostFlame.lineWidth = 2
        boostFlame.glowWidth = 4
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

        if let ghost = controller.ghost, ghost.frameCount > 1 {
            let g = SKSpriteNode(texture: CarArt.texture(shape: controller.spec.shape, body: .white, in: view), size: CarArt.spriteSize)
            g.alpha = 0.3
            g.zPosition = 12
            world.addChild(g)
            ghostNode = g
        }
        for _ in 0..<160 {
            let s = SKShapeNode(rectOf: CGSize(width: 9, height: 4), cornerRadius: 2)
            s.fillColor = UIColor.black.withAlphaComponent(0.28)
            s.strokeColor = .clear
            s.zPosition = -12.5
            s.alpha = 0
            world.addChild(s)
            skids.append(s)
        }
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
        if !boostFlame.isHidden { boostFlame.xScale = 0.8 + 0.4 * CGFloat.random(in: 0...1) }
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
        let speedZoom = calm ? 1 : 1 + 0.06 * CGFloat(max(0, min(1, car.forwardSpeed / controller.spec.topSpeed)))
        cam.setScale(zoom * speedZoom)
        if controller.shakeRequested && !calm {
            cam.run(.sequence([.moveBy(x: 7, y: -5, duration: 0.04), .moveBy(x: -12, y: 8, duration: 0.05), .moveBy(x: 5, y: -3, duration: 0.04)]))
        }

        syncEchoes()
        if let ghostNode, let pose = controller.ghost?.pose(at: race.time), race.crossedStart {
            ghostNode.isHidden = false
            ghostNode.position = CGPoint(x: pose.position.x, y: pose.position.y)
            ghostNode.zRotation = CGFloat(pose.heading)
        } else {
            ghostNode?.isHidden = true
        }

        if race.gateOpen != gateWasOpen || immediate {
            art.setGate(open: race.gateOpen, animated: !immediate)
            gateWasOpen = race.gateOpen
        }
        if !race.iceWear.isEmpty { art.setIce(wear: race.iceWear) }
        art.setPadOccupied(race.gateOpen && race.track.shortcut?.trigger == .pad)

        if car.drifting && !car.isAirborne && Int(race.time * 120) % 3 == 0 {
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
            nodes.car.alpha = solid ? 0.92 : 0.55
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

    // MARK: - Touches

    private var fullLock: CGFloat { 70 / CGFloat(settings.steeringSensitivity) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        for touch in touches {
            let p = touch.location(in: view)
            if steerTouch == nil {
                steerTouch = touch
                anchorX = p.x
                swipeStartY = p.y
                swipeStartTime = touch.timestamp
                touchStart = (p, touch.timestamp)
                if touch.timestamp - lastTapEnd < 0.3 { controller.requestSwap() }
                controller.touchBegan()
            } else {
                // A second finger boosts (the iPad two-thumb layout, or anyone who prefers tapping).
                controller.requestBoost()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = steerTouch, touches.contains(touch) else { return }
        let p = touch.location(in: view)
        var dx = p.x - anchorX
        if abs(dx) > fullLock {
            // Drag the anchor along so moving back straightens immediately.
            anchorX = p.x - (dx > 0 ? fullLock : -fullLock)
            dx = dx > 0 ? fullLock : -fullLock
        }
        let v = Double(dx / fullLock)
        controller.touchSteered(v >= 0 ? pow(v, 1.15) : -pow(-v, 1.15))
        // Swipe up (quick upward flick) boosts, or leaves the pad bay.
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
