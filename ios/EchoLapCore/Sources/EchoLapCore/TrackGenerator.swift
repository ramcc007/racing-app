import Foundation

/// Turns a TrackDef into a circuit. One call is one attempt with one sub-seed: it returns nil when the shape breaks a rule
/// (corner too tight, parts of the track too close, no room for a shortcut...). TrackLibrary tries attempts in order
/// and also makes the robot driver finish each candidate, so the result is identical on every device.
public enum TrackGenerator {
    public static let step = 8.0
    /// Kerb width on each side of the road, drawn by the app; the clearance rules leave room for it.
    public static let kerb = 12.0
    public static let bayRadius = 26.0

    /// Why attempts were rejected (diagnostics for tests; not used by the app).
    nonisolated(unsafe) static var rejections: [String: Int] = [:]
    static func reject(_ why: String) -> Track? {
        rejections[why, default: 0] += 1
        return nil
    }

    public static func generate(_ def: TrackDef, attempt: Int) -> Track? {
        let diff = Difficulty.of(def)
        var rng = SeededRandom(seed: def.seed &+ UInt64(attempt) &* 0x9E37_79B9_7F4A_7C15)
        let hw = diff.roadWidth / 2

        // 1. Shape: wobbly ring of control points, smoothed by a spline, sized to the target lap length.
        let n = 7 + Int((diff.wiggle * 5).rounded()) + rng.int(3)
        let wantsGate = def.features.contains(.pads) || def.features.contains(.sensors)
        // Gate tracks get bolder, kidney-like shapes so a worthwhile shortcut fits across the infield.
        let variance = 0.22 + 0.38 * diff.wiggle + (wantsGate ? 0.18 : 0)
        let stretch = rng.range(0.8, 1.25)
        var ctrl: [Vec2] = []
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi + rng.range(-0.35, 0.35) * (2 * .pi / Double(n))
            let r = 1 + rng.range(-variance, variance)
            ctrl.append(Vec2(cos(a) * r * stretch, sin(a) * r / stretch))
        }
        if rng.chance(0.5) { ctrl.reverse() }   // clockwise or anticlockwise
        var pts = sized(Geometry.closedSpline(ctrl, perSegment: 24), length: diff.lapLength)
        guard pts.count > 120 else { return reject("short") }

        // 2. Corners: relax the shape a little at a time until no corner is tighter than the curve allows. Stopping as
        //    soon as it complies keeps the tightest corner close to the limit, so harder tracks really have tight corners.
        var radii = Geometry.radii(pts)
        var minR = radii.min() ?? 0
        var relaxations = 0
        while minR < diff.minRadius && relaxations < 160 {
            pts = sized(Geometry.smoothClosed(pts, window: 2, passes: 1), length: diff.lapLength)
            radii = Geometry.radii(pts)
            minR = radii.min() ?? 0
            relaxations += 1
        }
        guard minR >= diff.minRadius else { return reject("tight") }
        if def.index > 6, def.kind != .breather, minR > diff.minRadius * 2.4 { return reject("easy") }

        // 3. No part of the track may come close to another part (room for both roads, kerbs and a gap).
        guard selfClearance(pts, minDistance: diff.roadWidth + 2 * kerb + 40, skip: Int(hw * 4 / step) + 6) else { return reject("overlap") }

        // 4. Start line on the straightest stretch, so the race starts calmly.
        let m = pts.count
        var bestStart = 0, bestScore = -1.0
        for i in 0..<m {
            var score = Double.infinity
            for d in stride(from: -20, through: 10, by: 2) { score = min(score, radii[(i + d + m) % m]) }
            if score > bestScore { bestScore = score; bestStart = i }
        }
        pts = Array(pts[bestStart...] + pts[..<bestStart])
        radii = Array(radii[bestStart...] + radii[..<bestStart])
        let tangents = Geometry.tangents(pts)

        // 5. Features. Each one reserves a stretch of the lap so they never overlap.
        var reserved: [(start: Int, count: Int)] = [(m - 22, 44)]   // the start/finish zone
        func free(_ start: Int, _ count: Int) -> Bool {
            for r in reserved {
                for k in stride(from: 0, to: count, by: 1) {
                    let i = (start + k) % m
                    if (i - r.start + m) % m < r.count { return false }
                }
            }
            return true
        }
        func normalAt(_ i: Int) -> Vec2 { tangents[i].perp }

        var shortcut: Shortcut?
        var bays: [Bay] = []
        if wantsGate {
            let trigger: Bay.Kind = def.features.contains(.sensors) ? .sensor : .pad
            guard let found = placeShortcut(pts: pts, hw: hw, trigger: trigger, rng: &rng) else { return reject("shortcut") }
            shortcut = found
            let back = trigger == .pad ? rng.range(260, 460) : rng.range(110, 190)
            let bayIndex = found.entryIndex - Int(back / step)
            guard bayIndex > 24,
                  let bay = placeBay(pts: pts, normals: tangents.map(\.perp), index: bayIndex, hw: hw, kind: trigger, lane: found)
            else { return reject("bay") }
            bays.append(bay)
            reserved.append((bayIndex - 24, found.exitIndex - bayIndex + 48))
        }

        var jumps: [Jump] = []
        if def.features.contains(.jumps) {
            let want = 2 + rng.int(2)
            for _ in 0..<80 where jumps.count < want {
                let i = 24 + rng.int(max(1, m - 48))
                guard free(i - 6, 46) else { continue }
                var straight = true
                for d in stride(from: -16, through: 36, by: 4) where radii[(i + d + m) % m] < 420 { straight = false; break }
                guard straight else { continue }
                jumps.append(Jump(index: i, center: pts[i], direction: tangents[i]))
                reserved.append((i - 6, 46))
            }
            guard jumps.count >= 2 else { return reject("jumps") }
        }

        var patches: [SurfacePatch] = []
        func addPatches(_ kind: SurfacePatch.Kind, want: Int, lengths: ClosedRange<Double>) -> Bool {
            var placed = 0
            for _ in 0..<80 where placed < want {
                let len = Int(rng.range(lengths.lowerBound, lengths.upperBound) / step)
                let start = 24 + rng.int(max(1, m - 48 - len))
                guard free(start - 4, len + 8) else { continue }
                let left = rng.chance(0.5)
                // Covers one side of the road; the other side stays clean and at least a car and a half wide.
                let clean = max(0.9 * hw, 1.45 * Physics.carWidth)
                let band = left ? (-hw + clean, hw + 2) : (-hw - 2, hw - clean)
                patches.append(SurfacePatch(id: patches.count, kind: kind, startIndex: start, count: len,
                                            lateralMin: band.0, lateralMax: band.1))
                reserved.append((start - 4, len + 8))
                placed += 1
            }
            return placed == want
        }
        let late = def.slot >= 11 || def.kind == .boss
        if def.features.contains(.thinIce) {
            guard addPatches(.ice, want: 2 + (late ? 2 : rng.int(2)), lengths: 80...150) else { return reject("ice") }
        }
        if def.features.contains(.sand) {
            guard addPatches(.sand, want: 1 + (late ? 2 : rng.int(2)), lengths: 70...140) else { return reject("sand") }
        }

        var winds: [WindZone] = []
        if def.features.contains(.wind) {
            let want = 2 + rng.int(2)
            let strength = 130 + 70 * diff.wiggle
            for _ in 0..<60 where winds.count < want {
                let len = Int(rng.range(300, 560) / step)
                let start = 24 + rng.int(max(1, m - 48 - len))
                let overlaps = winds.contains { z in abs(z.startIndex - start) < z.count + len }
                guard !overlaps else { continue }
                let mid = (start + len / 2) % m
                let direction: Double = rng.sign()
                let side: Vec2 = normalAt(mid)
                let k: Double = direction * strength
                let push = Vec2(side.x * k, side.y * k)
                winds.append(WindZone(startIndex: start, count: len, force: push))
            }
            guard winds.count >= 2 else { return reject("wind") }
        }

        return Track(def: def, difficulty: diff, step: step, points: pts, tangents: tangents, radii: radii, halfWidth: hw,
                     patches: patches, shortcut: shortcut, bays: bays, winds: winds, jumps: jumps, attempt: attempt)
    }

    /// Scales a closed polyline about its centre to the given length and resamples it every `step` units.
    static func sized(_ raw: [Vec2], length: Double) -> [Vec2] {
        var center = Vec2.zero
        for p in raw { center += p }
        center = center / Double(raw.count)
        let k = length / Geometry.closedLength(raw)
        return Geometry.resampleClosed(raw.map { center + ($0 - center) * k }, step: step)
    }

    /// True when no two samples further apart than `skip` along the lap are closer than `minDistance` (spatial hash).
    static func selfClearance(_ pts: [Vec2], minDistance: Double, skip: Int) -> Bool {
        let m = pts.count
        let cell = minDistance
        var grid: [Int: [Int]] = [:]
        func key(_ cx: Int, _ cy: Int) -> Int { cx &* 73_856_093 ^ cy &* 19_349_663 }
        for (i, p) in pts.enumerated() {
            grid[key(Int((p.x / cell).rounded(.down)), Int((p.y / cell).rounded(.down))), default: []].append(i)
        }
        let min2 = minDistance * minDistance
        for (i, p) in pts.enumerated() {
            let cx = Int((p.x / cell).rounded(.down)), cy = Int((p.y / cell).rounded(.down))
            for dx in -1...1 {
                for dy in -1...1 {
                    for j in grid[key(cx + dx, cy + dy)] ?? [] where j > i {
                        let gap = min(j - i, m - (j - i))
                        if gap > skip, (pts[j] - p).lengthSquared < min2 { return false }
                    }
                }
            }
        }
        return true
    }

    /// Finds a straight shortcut lane that saves real distance and stays clear of every other part of the track.
    static func placeShortcut(pts: [Vec2], hw: Double, trigger: Bay.Kind, rng: inout SeededRandom) -> Shortcut? {
        let m = pts.count
        let laneHW = hw * 0.9
        let skipEnds = Int(hw * 3 / step) + 3
        var best: (Shortcut, Double)?
        let tangents = Geometry.tangents(pts)
        let lapLength = Double(m) * step
        for _ in 0..<400 {
            let i = 60 + rng.int(max(1, m - 120))
            let k = Int(rng.range(0.2, 0.5) * Double(m))
            let j = i + k
            guard j < m - 26 else { continue }
            let a = pts[i], b = pts[j]
            let chord = a.distance(to: b), arc = Double(k) * step
            // Worth taking: saves at least a tenth of a lap. Flowing: the lane leaves and rejoins the road at an easy angle.
            guard chord > 160, arc - chord > max(420, 0.10 * lapLength), arc / chord > 1.45 else { continue }
            let dir = (b - a).normalized
            guard tangents[i].dot(dir) > 0.3, tangents[j].dot(dir) > 0.3 else { continue }
            var clear = true
            for q in 0..<m {
                let di = min(abs(q - i), m - abs(q - i)), dj = min(abs(q - j), m - abs(q - j))
                if di < skipEnds || dj < skipEnds { continue }
                if Geometry.segmentDistance(pts[q], a, b).distance < hw + laneHW + 2 * kerb + 10 { clear = false; break }
            }
            guard clear else { continue }
            let score = (arc - chord) * rng.range(0.8, 1.2)
            if best == nil || score > best!.1 {
                best = (Shortcut(entryIndex: i, exitIndex: j, a: a, b: b, halfWidth: laneHW, trigger: trigger), score)
            }
        }
        return best?.0
    }

    /// Puts a bay just outside the road edge at `index`, on whichever side has room.
    static func placeBay(pts: [Vec2], normals: [Vec2], index: Int, hw: Double, kind: Bay.Kind, lane: Shortcut) -> Bay? {
        let m = pts.count
        let skip = Int((hw * 3 + bayRadius) / step) + 4
        var options: [(Bay, Double)] = []
        for side in [1.0, -1.0] {
            let center = pts[index] + normals[index] * (side * (hw + bayRadius + 4))
            var nearest = Double.infinity
            for q in 0..<m {
                let d = min(abs(q - index), m - abs(q - index))
                if d < skip { continue }
                nearest = min(nearest, pts[q].distance(to: center))
            }
            let laneGap = Geometry.segmentDistance(center, lane.a, lane.b).distance
            guard nearest > hw + bayRadius + 2 * kerb + 16, laneGap > lane.halfWidth + bayRadius + 20 else { continue }
            options.append((Bay(kind: kind, index: index, center: center, radius: bayRadius), nearest))
        }
        return options.max { $0.1 < $1.1 }?.0
    }
}
