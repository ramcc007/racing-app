import SpriteKit
import UIKit
import EchoLapCore

/// Draws the six original racers in code (same shapes as the concept art) and turns them into textures once,
/// so each car on track is a single sprite. Nothing here is modelled on a real car.
@MainActor
enum CarArt {
    private static var cache: [String: SKTexture] = [:]

    /// A car pointing along +x, sized to the physics body (40 × 22 units, a little wider for wheels).
    static func texture(shape: String, body: UIColor, stripe: UIColor? = nil, in view: SKView) -> SKTexture {
        let key = "\(shape)-\(body.hexString)-\(stripe?.hexString ?? "-")"
        if let hit = cache[key] { return hit }
        let node = makeNode(shape: shape, body: body, stripe: stripe)
        let texture = view.texture(from: node, crop: CGRect(x: -46, y: -28, width: 92, height: 56)) ?? SKTexture()
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }

    /// Size of the sprite in world units (the drawing is 92 × 56 at 1 unit = 1 point, scaled so the body is 40 long).
    static let spriteSize = CGSize(width: 92 * scale, height: 56 * scale)
    static let scale: CGFloat = 40.0 / 74.0

    static func makeNode(shape: String, body: UIColor, stripe: UIColor?) -> SKNode {
        let root = SKNode()
        func add(_ path: CGPath, _ color: UIColor) {
            let n = SKShapeNode(path: path)
            n.fillColor = color
            n.strokeColor = .clear
            n.isAntialiased = true
            root.addChild(n)
        }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
            CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: min(r, w / 2), cornerHeight: min(r, h / 2), transform: nil)
        }
        let tyre = UIColor(hex: 0x1C1E22)
        let canopy = UIColor(hex: 0x16263A)
        for (x, y) in [(-22.0, -24.0), (14, -24), (-22, 16), (14, 16)] { add(rect(x, y, 18, 8, 3), tyre) }
        switch shape {
        case "wedge":
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -34, y: -18)); p.addLine(to: CGPoint(x: 10, y: -18)); p.addLine(to: CGPoint(x: 42, y: -4))
            p.addLine(to: CGPoint(x: 42, y: 4)); p.addLine(to: CGPoint(x: 10, y: 18)); p.addLine(to: CGPoint(x: -34, y: 18)); p.closeSubpath()
            add(p, body)
            let c = CGMutablePath()
            c.move(to: CGPoint(x: -8, y: -10)); c.addLine(to: CGPoint(x: 14, y: -8)); c.addLine(to: CGPoint(x: 24, y: 0))
            c.addLine(to: CGPoint(x: 14, y: 8)); c.addLine(to: CGPoint(x: -8, y: 10)); c.closeSubpath()
            add(c, canopy)
        case "buggy":
            add(rect(-28, -14, 60, 28, 14), body)
            let cage = SKShapeNode(rect: CGRect(x: -12, y: -18, width: 26, height: 36), cornerRadius: 6)
            cage.strokeColor = tyre; cage.lineWidth = 4; cage.fillColor = .clear
            root.addChild(cage)
            add(CGPath(ellipseIn: CGRect(x: -6, y: -8, width: 16, height: 16), transform: nil), canopy)
        case "brick":
            add(rect(-34, -20, 74, 40, 9), body)
            add(rect(-10, -15, 30, 30, 5), canopy)
            add(rect(34, -16, 6, 32, 2), UIColor.white.withAlphaComponent(0.7))
        case "needle":
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -36, y: -10)); p.addQuadCurve(to: CGPoint(x: -30, y: -14), control: CGPoint(x: -36, y: -14))
            p.addLine(to: CGPoint(x: 20, y: -8)); p.addQuadCurve(to: CGPoint(x: 46, y: 0), control: CGPoint(x: 46, y: -3))
            p.addQuadCurve(to: CGPoint(x: 20, y: 8), control: CGPoint(x: 46, y: 3)); p.addLine(to: CGPoint(x: -30, y: 14))
            p.addQuadCurve(to: CGPoint(x: -36, y: 10), control: CGPoint(x: -36, y: 14)); p.closeSubpath()
            add(p, body)
            add(rect(-40, -22, 10, 44, 3), body.withAlphaComponent(0.85))
            add(CGPath(ellipseIn: CGRect(x: -12, y: -6, width: 20, height: 12), transform: nil), canopy)
        case "hover":
            add(CGPath(ellipseIn: CGRect(x: -38, y: -22, width: 80, height: 44), transform: nil), body)
            let ring = SKShapeNode(ellipseIn: CGRect(x: -38, y: -22, width: 80, height: 44))
            ring.strokeColor = UIColor.white.withAlphaComponent(0.6); ring.lineWidth = 3; ring.fillColor = .clear
            root.addChild(ring)
            add(CGPath(ellipseIn: CGRect(x: -7, y: -10, width: 26, height: 20), transform: nil), canopy)
        default: // pod
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -34, y: -12)); p.addQuadCurve(to: CGPoint(x: -24, y: -20), control: CGPoint(x: -34, y: -20))
            p.addLine(to: CGPoint(x: 18, y: -18)); p.addQuadCurve(to: CGPoint(x: 40, y: 0), control: CGPoint(x: 38, y: -14))
            p.addQuadCurve(to: CGPoint(x: 18, y: 18), control: CGPoint(x: 38, y: 14)); p.addLine(to: CGPoint(x: -24, y: 20))
            p.addQuadCurve(to: CGPoint(x: -34, y: 12), control: CGPoint(x: -34, y: 20)); p.closeSubpath()
            add(p, body)
            add(rect(-30, -5, 60, 10, 4), UIColor.white.withAlphaComponent(0.22))
            add(CGPath(ellipseIn: CGRect(x: -10, y: -9, width: 24, height: 18), transform: nil), canopy)
            add(CGPath(ellipseIn: CGRect(x: 0, y: -6, width: 10, height: 6), transform: nil), UIColor.white.withAlphaComponent(0.55))
        }
        if let stripe { add(rect(-30, -3, 64, 6, 3), stripe) }
        if shape != "hover" {
            add(rect(33, -12, 7, 7, 3), UIColor(hex: 0xFFE9A8))
            add(rect(33, 5, 7, 7, 3), UIColor(hex: 0xFFE9A8))
            add(rect(-40, -18, 8, 36, 3), tyre.withAlphaComponent(0.9))
        }
        return root
    }

    /// Body colour for a racer with a paint applied.
    static func colors(for car: CarSpec, paint: String) -> (UIColor, UIColor?) {
        guard let item = Cosmetics.item(paint), let first = item.colors.first else { return (UIColor(hex: car.color), nil) }
        return (UIColor(hex: first), item.colors.count > 1 ? UIColor(hex: item.colors[1]) : nil)
    }
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }
}
