import Foundation

/// A patch of sand or ice covering part of the road width for a stretch of the lap.
/// Positions are in track terms: a range of centreline samples, and a sideways band (+ is the left of the driving direction).
public struct SurfacePatch: Hashable, Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case sand, ice }
    public let id: Int
    public let kind: Kind
    public let startIndex: Int
    public let count: Int
    public let lateralMin: Double
    public let lateralMax: Double

    func covers(index: Int, sampleCount n: Int) -> Bool {
        let d = (index - startIndex + n) % n
        return d < count
    }
}

/// A green bay beside the road: a pad (park here to hold the gate open) or a sensor (drive through to lower the bridge).
public struct Bay: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case pad, sensor }
    public let kind: Kind
    public let index: Int
    public let center: Vec2
    public let radius: Double
}

/// A straight shortcut lane across the infield, closed by a gate (pads) or a bridge (sensors) halfway along.
public struct Shortcut: Hashable, Codable, Sendable {
    public let entryIndex: Int
    public let exitIndex: Int
    public let a: Vec2
    public let b: Vec2
    public let halfWidth: Double
    public let trigger: Bay.Kind

    public var direction: Vec2 { (b - a).normalized }
    public var length: Double { a.distance(to: b) }
    public var gateCenter: Vec2 { (a + b) * 0.5 }
    /// The two ends of the gate bar, across the lane.
    public var gateEnds: (Vec2, Vec2) {
        let side = direction.perp * (halfWidth + 6)
        return (gateCenter - side, gateCenter + side)
    }
}

/// A stretch of track with a steady crosswind.
public struct WindZone: Hashable, Codable, Sendable {
    public let startIndex: Int
    public let count: Int
    /// Push in units per second², world direction.
    public let force: Vec2
}

/// A ramp across the road.
public struct Jump: Hashable, Codable, Sendable {
    public let index: Int
    public let center: Vec2
    public let direction: Vec2
}

/// Where a point is relative to the track.
public struct TrackLocation: Sendable {
    /// Nearest centreline sample.
    public let index: Int
    /// Signed sideways offset from the centreline (+ = left of the driving direction).
    public let lateral: Double
    /// Distance from the centreline.
    public let distance: Double
}

/// A finished, validated circuit. Everything is fixed once generated, so it is safe to share between threads.
public struct Track: Sendable {
    public let def: TrackDef
    public let difficulty: Difficulty
    /// Distance between centreline samples.
    public let step: Double
    public let points: [Vec2]
    public let tangents: [Vec2]
    public let radii: [Double]
    public let halfWidth: Double
    public let patches: [SurfacePatch]
    public let shortcut: Shortcut?
    public let bays: [Bay]
    public let winds: [WindZone]
    public let jumps: [Jump]
    /// Which attempt of the generator produced this track (for reproducing a bug report).
    public let attempt: Int

    public var count: Int { points.count }
    public var length: Double { Double(points.count) * step }
    public var pad: Bay? { bays.first { $0.kind == .pad } }
    public var sensor: Bay? { bays.first { $0.kind == .sensor } }

    /// Left-hand normal at a sample.
    public func normal(_ i: Int) -> Vec2 { tangents[i].perp }

    /// Arc position (distance from the start line) of a sample.
    public func s(_ index: Int) -> Double { Double(index) * step }

    public func wrap(_ i: Int) -> Int { ((i % count) + count) % count }

    /// Bounding box of the centreline, padded by `margin`.
    public func bounds(margin: Double = 0) -> (min: Vec2, max: Vec2) {
        var lo = Vec2(.infinity, .infinity), hi = Vec2(-.infinity, -.infinity)
        for p in points {
            lo = Vec2(min(lo.x, p.x), min(lo.y, p.y))
            hi = Vec2(max(hi.x, p.x), max(hi.y, p.y))
        }
        return (lo - Vec2(margin, margin), hi + Vec2(margin, margin))
    }

    /// Nearest centreline sample to `p`. With a hint (the last known index) it searches nearby first, which is what
    /// the race does every tick; without one, or if the local result is far off, it searches the whole lap.
    public func locate(_ p: Vec2, hint: Int? = nil) -> TrackLocation {
        var bestI = 0
        var bestD = Double.infinity
        if let hint {
            for d in -48...48 {
                let i = wrap(hint + d)
                let dist = (points[i] - p).lengthSquared
                if dist < bestD { bestD = dist; bestI = i }
            }
        }
        if hint == nil || bestD.squareRoot() > halfWidth * 2.5 {
            var i = 0
            while i < count {
                let dist = (points[i] - p).lengthSquared
                if dist < bestD { bestD = dist; bestI = i }
                i += 3
            }
            for d in -3...3 {
                let j = wrap(bestI + d)
                let dist = (points[j] - p).lengthSquared
                if dist < bestD { bestD = dist; bestI = j }
            }
        }
        let offset = p - points[bestI]
        return TrackLocation(index: bestI, lateral: offset.dot(normal(bestI)), distance: offset.length)
    }

    /// The patch under a point, if any (only counts on the road surface).
    public func patch(at loc: TrackLocation) -> SurfacePatch? {
        guard abs(loc.lateral) <= halfWidth else { return nil }
        return patches.first { $0.covers(index: loc.index, sampleCount: count) && loc.lateral >= $0.lateralMin && loc.lateral <= $0.lateralMax }
    }

    /// Crosswind at a sample (zero outside wind zones).
    public func wind(at index: Int) -> Vec2 {
        for zone in winds {
            let d = (index - zone.startIndex + count) % count
            if d < zone.count {
                // Ramps in and out over the first and last fifth of the zone.
                let edge = Double(zone.count) * 0.2
                let k = min(1, Double(d) / edge, Double(zone.count - d) / edge)
                return zone.force * k
            }
        }
        return .zero
    }

    /// Position on the shortcut lane: distance from it and how far along (0...1).
    public func shortcutPosition(_ p: Vec2) -> (distance: Double, t: Double)? {
        guard let sc = shortcut else { return nil }
        return Geometry.segmentDistance(p, sc.a, sc.b)
    }

    /// Outline of a patch for drawing: left edge forwards, right edge backwards.
    public func outline(of patch: SurfacePatch) -> [Vec2] {
        var left: [Vec2] = [], right: [Vec2] = []
        for k in 0...patch.count {
            let i = wrap(patch.startIndex + k)
            left.append(points[i] + normal(i) * patch.lateralMax)
            right.append(points[i] + normal(i) * patch.lateralMin)
        }
        return left + right.reversed()
    }
}
