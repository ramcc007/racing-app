import SpriteKit
import UIKit
import EchoLapCore

/// Builds the static world of a race from a Track: ground, scenery, road with kerbs, sand and ice, the shortcut lane
/// with its gate or bridge, bays, wind markers, ramps and the start line. All vector, drawn once.
@MainActor
final class TrackArt {
    let root = SKNode()
    private(set) var gateBar: SKNode?
    private(set) var gatePosts: [SKShapeNode] = []
    private(set) var iceNodes: [Int: (crack1: SKNode, crack2: SKNode, water: SKShapeNode)] = [:]
    private(set) var padGlow: SKShapeNode?
    private let track: Track
    private let style: WorldStyle

    init(track: Track, style: WorldStyle, view: SKView?) {
        self.track = track
        self.style = style
        buildGround()
        buildScenery(view: view)
        buildShortcut()
        buildRoad()
        buildPatches()
        buildBays()
        buildWind()
        buildJumps()
        buildStartLine()
    }

    private var hw: CGFloat { CGFloat(track.halfWidth) }
    private let kerb: CGFloat = CGFloat(TrackGenerator.kerb)

    private func point(_ v: Vec2) -> CGPoint { CGPoint(x: v.x, y: v.y) }

    private func loopPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: point(track.points[0]))
        for v in track.points.dropFirst() { p.addLine(to: point(v)) }
        p.closeSubpath()
        return p
    }

    private func stroke(_ path: CGPath, width: CGFloat, color: UIColor, z: CGFloat, dash: [CGFloat]? = nil, cap: CGLineCap = .round) -> SKShapeNode {
        let drawn = dash.map { path.copy(dashingWithPhase: 0, lengths: $0) } ?? path
        let n = SKShapeNode(path: drawn)
        n.strokeColor = color
        n.lineWidth = width
        n.lineJoin = .round
        n.lineCap = dash == nil ? cap : .butt
        n.fillColor = .clear
        n.isAntialiased = true
        n.zPosition = z
        root.addChild(n)
        return n
    }

    private func buildGround() {
        let b = track.bounds(margin: 1600)
        let ground = SKSpriteNode(color: UIColor(hex: style.ground), size: CGSize(width: b.max.x - b.min.x, height: b.max.y - b.min.y))
        ground.position = CGPoint(x: (b.min.x + b.max.x) / 2, y: (b.min.y + b.max.y) / 2)
        ground.zPosition = -100
        root.addChild(ground)
    }

    private func buildRoad() {
        let path = loopPath()
        let shadow = stroke(path, width: 2 * hw + 2 * kerb + 10, color: UIColor.black.withAlphaComponent(0.22), z: -20)
        shadow.position = CGPoint(x: 7, y: -11)
        _ = stroke(path, width: 2 * hw + 2 * kerb, color: UIColor(hex: style.kerbA), z: -19)
        _ = stroke(path, width: 2 * hw + 2 * kerb, color: UIColor(hex: style.kerbB), z: -18, dash: [22, 22])
        _ = stroke(path, width: 2 * hw, color: UIColor(hex: style.asphalt), z: -17)
        _ = stroke(path, width: 2 * hw - 8, color: UIColor.white.withAlphaComponent(0.7), z: -16)
        _ = stroke(path, width: 2 * hw - 13, color: UIColor(hex: style.asphalt), z: -15)
        _ = stroke(path, width: 4, color: UIColor.white.withAlphaComponent(0.28), z: -14, dash: [26, 34])
    }

    private func buildShortcut() {
        guard let sc = track.shortcut else { return }
        let p = CGMutablePath()
        p.move(to: point(sc.a))
        p.addLine(to: point(sc.b))
        let w = CGFloat(sc.halfWidth) * 2
        let shadow = stroke(p, width: w + 2 * kerb + 10, color: UIColor.black.withAlphaComponent(0.22), z: -24, cap: .butt)
        shadow.position = CGPoint(x: 7, y: -11)
        _ = stroke(p, width: w + 2 * kerb, color: UIColor(hex: style.kerbA), z: -23, cap: .butt)
        _ = stroke(p, width: w, color: UIColor(hex: style.asphalt), z: -22, cap: .butt)
        _ = stroke(p, width: 5, color: UIColor(hex: 0xF2A93B).withAlphaComponent(0.85), z: -21, dash: [26, 22])

        // Gate (pads) or bridge (sensors) across the middle of the lane.
        let (e1, e2) = sc.gateEnds
        let dir = sc.direction
        let barPath = CGMutablePath()
        barPath.move(to: point(e1))
        barPath.addLine(to: point(e2))
        let bar = SKShapeNode(path: barPath)
        bar.lineWidth = sc.trigger == .pad ? 10 : 18
        bar.strokeColor = sc.trigger == .pad ? UIColor(hex: 0xE84D4D) : UIColor(hex: 0x8A6A4A)
        bar.lineCap = .round
        bar.zPosition = 5
        root.addChild(bar)
        gateBar = bar
        for end in [e1, e2] {
            let post = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 4)
            post.position = point(end)
            post.zRotation = CGFloat(dir.angle)
            post.fillColor = UIColor(hex: 0xE84D4D)
            post.strokeColor = .clear
            post.zPosition = 6
            root.addChild(post)
            gatePosts.append(post)
        }
        if sc.trigger == .sensor {
            // A gap under the bridge: dark water across the lane, covered while the bridge is down.
            let gap = SKShapeNode(rectOf: CGSize(width: 34, height: CGFloat(sc.halfWidth) * 2 + 8))
            gap.position = point(sc.gateCenter)
            gap.zRotation = CGFloat(dir.angle)
            gap.fillColor = UIColor(hex: 0x1F4E6E)
            gap.strokeColor = .clear
            gap.zPosition = -20.5
            root.addChild(gap)
        }
    }

    /// Opens or closes the gate drawing.
    func setGate(open: Bool, animated: Bool) {
        guard let bar = gateBar, let sc = track.shortcut else { return }
        let color = open ? UIColor(hex: 0x2FA36B) : UIColor(hex: 0xE84D4D)
        for post in gatePosts { post.fillColor = color }
        let target: CGFloat = open ? (sc.trigger == .pad ? 0 : 1) : 1
        let alpha: CGFloat = sc.trigger == .pad ? (open ? 0 : 1) : 1
        bar.removeAllActions()
        if sc.trigger == .sensor {
            // Bridge: planks lower into place (visible) when open, lift away (faint) when closed.
            let a: CGFloat = open ? 1 : 0.15
            if animated { bar.run(.fadeAlpha(to: a, duration: 0.25)) } else { bar.alpha = a }
            (bar as? SKShapeNode)?.strokeColor = open ? UIColor(hex: 0xB08A5E) : UIColor(hex: 0x8A6A4A)
        } else if animated {
            bar.run(.group([.fadeAlpha(to: alpha, duration: 0.2), .scaleX(to: target == 0 ? 0.1 : 1, duration: 0.2)]))
        } else {
            bar.alpha = alpha
        }
    }

    private func buildPatches() {
        for patch in track.patches {
            let outline = track.outline(of: patch)
            let path = CGMutablePath()
            path.addLines(between: outline.map(point))
            path.closeSubpath()
            let shape = SKShapeNode(path: path)
            shape.strokeColor = .clear
            shape.zPosition = -12
            switch patch.kind {
            case .sand:
                shape.fillColor = UIColor(hex: 0xE2C07A, alpha: 0.95)
                root.addChild(shape)
                var rng = SeededRandom(seed: UInt64(patch.id + 1) &* 7919)
                for _ in 0..<(patch.count * 2) {
                    let k = rng.int(patch.count)
                    let i = track.wrap(patch.startIndex + k)
                    let lat = rng.range(patch.lateralMin, patch.lateralMax)
                    let dot = SKShapeNode(circleOfRadius: CGFloat(rng.range(1.5, 3.5)))
                    dot.position = point(track.points[i] + track.normal(i) * clamp(lat, -track.halfWidth + 3, track.halfWidth - 3))
                    dot.fillColor = UIColor(hex: 0xB98E4A, alpha: 0.7)
                    dot.strokeColor = .clear
                    dot.zPosition = -11
                    root.addChild(dot)
                }
            case .ice:
                shape.fillColor = UIColor(hex: 0xBFE6F7, alpha: 0.95)
                root.addChild(shape)
                let water = SKShapeNode(path: path)
                water.fillColor = UIColor(hex: 0x2E79A8)
                water.strokeColor = UIColor.white.withAlphaComponent(0.6)
                water.lineWidth = 2
                water.zPosition = -10
                water.alpha = 0
                root.addChild(water)
                let crack1 = cracks(for: patch, seed: 1)
                let crack2 = cracks(for: patch, seed: 2)
                crack1.alpha = 0
                crack2.alpha = 0
                iceNodes[patch.id] = (crack1, crack2, water)
                // A few bright streaks so ice reads as ice.
                var rng = SeededRandom(seed: UInt64(patch.id + 11))
                for _ in 0..<max(2, patch.count / 4) {
                    let i = track.wrap(patch.startIndex + rng.int(patch.count))
                    let lat = rng.range(patch.lateralMin + 6, patch.lateralMax - 6)
                    let c = track.points[i] + track.normal(i) * clamp(lat, -track.halfWidth + 6, track.halfWidth - 6)
                    let streak = CGMutablePath()
                    let t = track.tangents[i] * 10
                    streak.move(to: point(c - t)); streak.addLine(to: point(c + t))
                    _ = stroke(streak, width: 2, color: UIColor.white.withAlphaComponent(0.8), z: -11)
                }
            }
        }
    }

    private func cracks(for patch: SurfacePatch, seed: UInt64) -> SKNode {
        let node = SKNode()
        node.zPosition = -10.5
        var rng = SeededRandom(seed: UInt64(patch.id) &* 31 &+ seed)
        for _ in 0..<(3 + Int(seed) * 2) {
            let i = track.wrap(patch.startIndex + rng.int(patch.count))
            let lat = rng.range(patch.lateralMin + 4, patch.lateralMax - 4)
            var c = track.points[i] + track.normal(i) * clamp(lat, -track.halfWidth + 4, track.halfWidth - 4)
            let p = CGMutablePath()
            p.move(to: point(c))
            for _ in 0..<4 {
                c += Vec2(rng.range(-9, 9), rng.range(-9, 9))
                p.addLine(to: point(c))
            }
            let line = SKShapeNode(path: p)
            line.strokeColor = UIColor(hex: 0x5A8FB0)
            line.lineWidth = 1.6
            node.addChild(line)
        }
        root.addChild(node)
        return node
    }

    /// Shows ice wear: faint cracks after one pass, more after two, water after three.
    func setIce(wear: [Int: Int]) {
        for (id, nodes) in iceNodes {
            let w = wear[id] ?? 0
            nodes.crack1.alpha = w >= 1 ? 1 : 0
            nodes.crack2.alpha = w >= 2 ? 1 : 0
            if w >= Race.iceBreakPasses && nodes.water.alpha == 0 {
                nodes.water.run(.fadeIn(withDuration: 0.25))
            }
        }
    }

    private func buildBays() {
        for bay in track.bays {
            let r = CGFloat(bay.radius)
            let base = SKShapeNode(rectOf: CGSize(width: r * 2.2, height: r * 2.2), cornerRadius: 12)
            base.position = point(bay.center)
            base.zRotation = CGFloat(track.tangents[bay.index].angle)
            base.fillColor = UIColor(hex: bay.kind == .pad ? 0x2FA36B : 0x2B8FD6)
            base.strokeColor = UIColor.white.withAlphaComponent(0.85)
            base.lineWidth = 3
            base.zPosition = -13
            root.addChild(base)
            let label = SKLabelNode(text: bay.kind == .pad ? "P" : "S")
            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 26
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.zPosition = 1
            base.addChild(label)
            if bay.kind == .pad {
                let glow = SKShapeNode(rectOf: CGSize(width: r * 2.6, height: r * 2.6), cornerRadius: 16)
                glow.strokeColor = UIColor(hex: 0x5BD08D)
                glow.lineWidth = 4
                glow.glowWidth = 6
                glow.fillColor = .clear
                glow.alpha = 0
                base.addChild(glow)
                padGlow = glow
            }
            // A short connecting apron from the road edge to the bay.
            let apron = CGMutablePath()
            let edge = track.points[bay.index] + (bay.center - track.points[bay.index]).normalized * track.halfWidth
            apron.move(to: point(edge)); apron.addLine(to: point(bay.center))
            _ = stroke(apron, width: r * 1.6, color: UIColor(hex: style.asphalt), z: -13.5, cap: .butt)
        }
    }

    func setPadOccupied(_ occupied: Bool) {
        guard let glow = padGlow else { return }
        let target: CGFloat = occupied ? 1 : 0
        if glow.alpha != target { glow.run(.fadeAlpha(to: target, duration: 0.2)) }
    }

    private func buildWind() {
        for zone in track.winds {
            let dir = zone.force.normalized
            for k in stride(from: 6, to: zone.count - 6, by: 10) {
                let i = track.wrap(zone.startIndex + k)
                for side in [-0.5, 0.0, 0.5] {
                    let c = track.points[i] + track.normal(i) * (side * track.halfWidth)
                    let chevron = CGMutablePath()
                    let back = c - dir * 7, perp = dir.perp * 7
                    chevron.move(to: point(back + perp)); chevron.addLine(to: point(c + dir * 3)); chevron.addLine(to: point(back - perp))
                    let n = stroke(chevron, width: 3, color: UIColor.white.withAlphaComponent(0.55), z: -9)
                    n.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.6), .fadeAlpha(to: 0.6, duration: 0.6)])))
                }
            }
        }
    }

    private func buildJumps() {
        for jump in track.jumps {
            let ramp = SKShapeNode(rectOf: CGSize(width: 22, height: 2 * hw + 6), cornerRadius: 4)
            ramp.position = point(jump.center)
            ramp.zRotation = CGFloat(jump.direction.angle)
            ramp.fillColor = UIColor(hex: 0xF2C94C)
            ramp.strokeColor = UIColor(hex: 0x1B2430)
            ramp.lineWidth = 3
            ramp.zPosition = -9
            root.addChild(ramp)
            for k in -1...1 {
                let c = jump.center + jump.direction.perp * (Double(k) * track.halfWidth * 0.55)
                let ch = CGMutablePath()
                let d = jump.direction, p = d.perp * 6
                ch.move(to: point(c - d * 5 + p)); ch.addLine(to: point(c + d * 4)); ch.addLine(to: point(c - d * 5 - p))
                _ = stroke(ch, width: 3, color: UIColor(hex: 0x1B2430), z: -8.5)
            }
        }
    }

    private func buildStartLine() {
        let c = track.points[0], t = track.tangents[0], n = track.normal(0)
        let cells = 8
        let cellW = (2 * track.halfWidth) / Double(cells)
        for row in 0..<2 {
            for k in 0..<cells {
                let sq = SKShapeNode(rectOf: CGSize(width: 10, height: cellW))
                let lat = -track.halfWidth + cellW * (Double(k) + 0.5)
                sq.position = point(c + n * lat + t * (Double(row) * 10 - 5))
                sq.zRotation = CGFloat(t.angle)
                sq.fillColor = (row + k) % 2 == 0 ? .white : UIColor(hex: 0x111111)
                sq.strokeColor = .clear
                sq.zPosition = -13
                root.addChild(sq)
            }
        }
    }

    // MARK: - Scenery

    private func buildScenery(view: SKView?) {
        let b = track.bounds(margin: 500)
        let area = (b.max.x - b.min.x) * (b.max.y - b.min.y)
        let count = min(260, Int(area / 32000))
        var rng = SeededRandom(seed: track.def.seed &+ 99)
        var placed = 0
        var tries = 0
        let lanes = track.shortcut
        while placed < count && tries < count * 12 {
            tries += 1
            let p = Vec2(rng.range(b.min.x, b.max.x), rng.range(b.min.y, b.max.y))
            if track.locate(p).distance < track.halfWidth + 70 { continue }
            if let sc = lanes, Geometry.segmentDistance(p, sc.a, sc.b).distance < sc.halfWidth + 60 { continue }
            if track.bays.contains(where: { $0.center.distance(to: p) < 90 }) { continue }
            let node = Scenery.node(style.scenery, rng: &rng)
            node.position = point(p)
            node.zRotation = CGFloat(rng.range(0, 2 * .pi))
            node.zPosition = -50
            root.addChild(node)
            placed += 1
        }
        // Ground detail blotches.
        for _ in 0..<(count / 2) {
            let p = Vec2(rng.range(b.min.x, b.max.x), rng.range(b.min.y, b.max.y))
            let blot = SKShapeNode(ellipseOf: CGSize(width: rng.range(60, 220), height: rng.range(40, 140)))
            blot.position = point(p)
            blot.zRotation = CGFloat(rng.range(0, .pi))
            blot.fillColor = UIColor(hex: style.groundDetail, alpha: 0.6)
            blot.strokeColor = .clear
            blot.zPosition = -90
            root.addChild(blot)
        }
    }
}

/// Code-drawn scenery for each world.
@MainActor
enum Scenery {
    static func node(_ kind: WorldStyle.Scenery, rng: inout SeededRandom) -> SKNode {
        let root = SKNode()
        func shape(_ path: CGPath, _ color: UIColor, _ z: CGFloat = 0) {
            let n = SKShapeNode(path: path)
            n.fillColor = color
            n.strokeColor = .clear
            n.zPosition = z
            root.addChild(n)
        }
        func shadowed(_ path: CGPath, _ color: UIColor) {
            let s = SKShapeNode(path: path)
            s.fillColor = UIColor.black.withAlphaComponent(0.2)
            s.strokeColor = .clear
            s.position = CGPoint(x: 6, y: -8)
            root.addChild(s)
            shape(path, color, 1)
        }
        switch kind {
        case .harbour:
            if rng.chance(0.6) {
                let colors: [UInt32] = [0xE07A3F, 0x3F8FD2, 0xE3B341, 0x4CB28B, 0xC9544B]
                let c = UIColor(hex: colors[rng.int(colors.count)])
                shadowed(CGPath(rect: CGRect(x: -55, y: -20, width: 110, height: 40), transform: nil), c)
                for k in 1..<6 {
                    let line = SKShapeNode(rect: CGRect(x: -55 + CGFloat(k) * 18, y: -17, width: 2, height: 34))
                    line.fillColor = UIColor.black.withAlphaComponent(0.15); line.strokeColor = .clear; line.zPosition = 2
                    root.addChild(line)
                }
            } else {
                tree(root, rng: &rng, colors: (0x2F8F4E, 0x46AE62))
            }
        case .canyon:
            if rng.chance(0.5) {
                let r = CGFloat(rng.range(40, 90))
                shadowed(CGPath(ellipseIn: CGRect(x: -r, y: -r * 0.6, width: 2 * r, height: 1.2 * r), transform: nil), UIColor(hex: 0xB5653B))
                shape(CGPath(ellipseIn: CGRect(x: -r * 0.6, y: -r * 0.3, width: 1.2 * r, height: 0.7 * r), transform: nil), UIColor(hex: 0xC97A4A), 2)
            } else {
                shadowed(CGPath(roundedRect: CGRect(x: -5, y: -18, width: 10, height: 36), cornerWidth: 5, cornerHeight: 5, transform: nil), UIColor(hex: 0x4F7A3A))
                shape(CGPath(roundedRect: CGRect(x: -16, y: -2, width: 32, height: 8), cornerWidth: 4, cornerHeight: 4, transform: nil), UIColor(hex: 0x4F7A3A), 2)
            }
        case .neon:
            let w = CGFloat(rng.range(50, 110))
            shadowed(CGPath(roundedRect: CGRect(x: -w / 2, y: -w / 2, width: w, height: w), cornerWidth: 8, cornerHeight: 8, transform: nil), UIColor(hex: 0x2C2950))
            let glow = SKShapeNode(rect: CGRect(x: -w / 2 + 7, y: -w / 2 + 7, width: w - 14, height: w - 14), cornerRadius: 5)
            glow.strokeColor = UIColor(hex: [0x43E0FF, 0xE84DD1, 0xF7E14B][rng.int(3)])
            glow.lineWidth = 3; glow.glowWidth = 3; glow.fillColor = .clear; glow.zPosition = 2
            root.addChild(glow)
        case .glacier:
            let p = CGMutablePath()
            let r = rng.range(30, 70)
            p.addLines(between: (0..<6).map { k -> CGPoint in
                let a = Double(k) / 6 * 2 * .pi + rng.range(-0.3, 0.3)
                let rr = r * rng.range(0.6, 1.1)
                return CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            })
            p.closeSubpath()
            shadowed(p, .white)
        case .jungle:
            if rng.chance(0.8) { tree(root, rng: &rng, colors: (0x245F2E, 0x3E8E4A)) }
            else { shadowed(CGPath(rect: CGRect(x: -40, y: -26, width: 80, height: 52), transform: nil), UIColor(hex: 0x9C9A86)) }
        case .foundry:
            if rng.chance(0.4) {
                let p = CGMutablePath()
                p.addEllipse(in: CGRect(x: -60, y: -30, width: 120, height: 60))
                shape(p, UIColor(hex: 0xFF7A1A))
                shape(CGPath(ellipseIn: CGRect(x: -36, y: -14, width: 72, height: 28), transform: nil), UIColor(hex: 0xFFD166), 1)
            } else {
                shadowed(CGPath(rect: CGRect(x: -32, y: -32, width: 64, height: 64), transform: nil), UIColor(hex: 0x46403C))
                shape(CGPath(ellipseIn: CGRect(x: -14, y: -14, width: 28, height: 28), transform: nil), UIColor(hex: 0x2B2523), 2)
            }
        case .sky:
            for k in 0..<3 {
                let r = CGFloat(rng.range(24, 42))
                shape(CGPath(ellipseIn: CGRect(x: CGFloat(k) * 34 - 50 - r / 2, y: -r / 2 + (k == 1 ? 10 : 0), width: r * 1.6, height: r * 1.3), transform: nil),
                      UIColor.white.withAlphaComponent(0.92))
            }
        case .space:
            for _ in 0..<6 {
                let r = CGFloat(rng.range(1, 3))
                shape(CGPath(ellipseIn: CGRect(x: CGFloat(rng.range(-60, 60)), y: CGFloat(rng.range(-60, 60)), width: r, height: r), transform: nil),
                      UIColor.white.withAlphaComponent(CGFloat(rng.range(0.4, 1))))
            }
            if rng.chance(0.15) {
                shape(CGPath(ellipseIn: CGRect(x: -40, y: -40, width: 80, height: 80), transform: nil), UIColor(hex: 0x6B5BD6))
                let ring = SKShapeNode(ellipseOf: CGSize(width: 130, height: 26))
                ring.strokeColor = UIColor(hex: 0xB49BFF); ring.lineWidth = 4; ring.fillColor = .clear; ring.zPosition = 2
                root.addChild(ring)
            }
        }
        return root
    }

    private static func tree(_ root: SKNode, rng: inout SeededRandom, colors: (UInt32, UInt32)) {
        let r = CGFloat(rng.range(22, 40))
        let shadow = SKShapeNode(circleOfRadius: r)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.18); shadow.strokeColor = .clear; shadow.position = CGPoint(x: 8, y: -10)
        root.addChild(shadow)
        let crown = SKShapeNode(circleOfRadius: r)
        crown.fillColor = UIColor(hex: colors.0); crown.strokeColor = .clear; crown.zPosition = 1
        root.addChild(crown)
        let light = SKShapeNode(circleOfRadius: r * 0.55)
        light.fillColor = UIColor(hex: colors.1); light.strokeColor = .clear; light.position = CGPoint(x: -r * 0.3, y: r * 0.3); light.zPosition = 2
        root.addChild(light)
    }
}
