import Foundation

/// A 2D point or direction in world units. One car is 40 units long and 22 wide.
public struct Vec2: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, k: Double) -> Vec2 { Vec2(a.x * k, a.y * k) }
    public static func * (k: Double, a: Vec2) -> Vec2 { Vec2(a.x * k, a.y * k) }
    public static func / (a: Vec2, k: Double) -> Vec2 { Vec2(a.x / k, a.y / k) }
    public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }

    public func dot(_ b: Vec2) -> Double { x * b.x + y * b.y }
    public func cross(_ b: Vec2) -> Double { x * b.y - y * b.x }
    public var lengthSquared: Double { x * x + y * y }
    public var length: Double { lengthSquared.squareRoot() }
    public var normalized: Vec2 {
        let l = length
        return l > 1e-9 ? self / l : Vec2(1, 0)
    }
    /// Rotated 90° counter-clockwise (the left-hand normal when y points up).
    public var perp: Vec2 { Vec2(-y, x) }
    public var angle: Double { atan2(y, x) }

    public static func fromAngle(_ a: Double) -> Vec2 { Vec2(cos(a), sin(a)) }

    public func distance(to b: Vec2) -> Double { (self - b).length }
}

@inlinable
public func clamp<T: Comparable>(_ value: T, _ lo: T, _ hi: T) -> T {
    min(max(value, lo), hi)
}

/// Wraps an angle into -π...π.
public func wrapAngle(_ a: Double) -> Double {
    var r = a.truncatingRemainder(dividingBy: 2 * .pi)
    if r > .pi { r -= 2 * .pi }
    if r < -.pi { r += 2 * .pi }
    return r
}

/// Linear interpolation.
@inlinable
public func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

/// Deterministic random numbers (SplitMix64). The same seed always gives the same track on every device,
/// which is what makes the daily track identical for everyone without a server.
public struct SeededRandom: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed ^ 0x6A09_E667_F3BC_C908
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 ..< 1
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    public mutating func range(_ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * unit()
    }

    /// 0 ..< n
    public mutating func int(_ n: Int) -> Int {
        n <= 1 ? 0 : Int(next() % UInt64(n))
    }

    public mutating func chance(_ p: Double) -> Bool { unit() < p }

    public mutating func sign() -> Double { chance(0.5) ? 1 : -1 }
}

/// FNV-1a: a stable 64-bit hash of a string (Swift's own `hashValue` changes between launches).
public func stableHash(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01B3
    }
    return hash
}
