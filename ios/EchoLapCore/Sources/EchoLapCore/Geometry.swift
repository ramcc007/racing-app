import Foundation

/// Curve helpers used by the track generator and the robot's racing line.
public enum Geometry {
    /// Closed Catmull–Rom spline through the control points, `perSegment` samples between each pair.
    static func closedSpline(_ ctrl: [Vec2], perSegment: Int) -> [Vec2] {
        let n = ctrl.count
        var out: [Vec2] = []
        out.reserveCapacity(n * perSegment)
        for i in 0..<n {
            let p0 = ctrl[(i - 1 + n) % n], p1 = ctrl[i], p2 = ctrl[(i + 1) % n], p3 = ctrl[(i + 2) % n]
            for k in 0..<perSegment {
                let t = Double(k) / Double(perSegment)
                let t2 = t * t, t3 = t2 * t
                let x = 0.5 * (2 * p1.x + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
                let y = 0.5 * (2 * p1.y + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
                out.append(Vec2(x, y))
            }
        }
        return out
    }

    static func closedLength(_ pts: [Vec2]) -> Double {
        var total = 0.0
        for i in 0..<pts.count { total += pts[i].distance(to: pts[(i + 1) % pts.count]) }
        return total
    }

    /// Points every `step` units along a closed polyline.
    static func resampleClosed(_ pts: [Vec2], step: Double) -> [Vec2] {
        guard pts.count > 2 else { return pts }
        var out: [Vec2] = [pts[0]]
        var need = step
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let seg = a.distance(to: b)
            guard seg > 1e-9 else { continue }
            var pos = 0.0
            while seg - pos >= need {
                pos += need
                let t = pos / seg
                out.append(a + (b - a) * t)
                need = step
            }
            need -= seg - pos
        }
        if let last = out.last, last.distance(to: out[0]) < step * 0.5 { out.removeLast() }
        return out
    }

    /// Unit tangent at each point of a closed polyline.
    static func tangents(_ pts: [Vec2]) -> [Vec2] {
        let n = pts.count
        return (0..<n).map { (i: Int) -> Vec2 in
            let ahead: Vec2 = pts[(i + 1) % n]
            let behind: Vec2 = pts[(i - 1 + n) % n]
            return (ahead - behind).normalized
        }
    }

    /// Radius of curvature at each point, measured over ±k samples (a straight gives a huge radius).
    static func radii(_ pts: [Vec2], k: Int = 4) -> [Double] {
        let n = pts.count
        return (0..<n).map { i in
            let a = pts[(i - k + n) % n], b = pts[i], c = pts[(i + k) % n]
            let ab = a.distance(to: b), bc = b.distance(to: c), ca = c.distance(to: a)
            let area2 = abs((b - a).cross(c - a))
            return area2 < 1e-6 ? 1e6 : (ab * bc * ca) / (2 * area2)
        }
    }

    /// Moving-average smoothing of a closed polyline (cuts corners: a crude racing line).
    static func smoothClosed(_ pts: [Vec2], window: Int, passes: Int) -> [Vec2] {
        var cur = pts
        let n = pts.count
        for _ in 0..<passes {
            var next = cur
            for i in 0..<n {
                var sum = Vec2.zero
                for d in -window...window { sum += cur[(i + d + n) % n] }
                next[i] = sum / Double(2 * window + 1)
            }
            cur = next
        }
        return cur
    }

    /// Distance from p to segment ab, plus the 0...1 position of the closest point along it.
    public static func segmentDistance(_ p: Vec2, _ a: Vec2, _ b: Vec2) -> (distance: Double, t: Double) {
        let ab = b - a
        let len2 = ab.lengthSquared
        guard len2 > 1e-9 else { return (p.distance(to: a), 0) }
        let t = clamp((p - a).dot(ab) / len2, 0, 1)
        return ((a + ab * t).distance(to: p), t)
    }

    /// Whether segments p1p2 and q1q2 cross.
    static func segmentsIntersect(_ p1: Vec2, _ p2: Vec2, _ q1: Vec2, _ q2: Vec2) -> Bool {
        let d1 = (p2 - p1).cross(q1 - p1), d2 = (p2 - p1).cross(q2 - p1)
        let d3 = (q2 - q1).cross(p1 - q1), d4 = (q2 - q1).cross(p2 - q1)
        return (d1 * d2 < 0) && (d3 * d4 < 0)
    }
}
