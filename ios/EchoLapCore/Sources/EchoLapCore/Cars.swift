import Foundation

/// One of the six original racers. Stats differ a little in each direction, so no racer is simply better.
/// Racers are unlocked with stars only and are never sold.
public struct CarSpec: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let role: String
    /// Top speed, units per second.
    public let topSpeed: Double
    /// Acceleration, units per second².
    public let accel: Double
    /// Turn rate at low speed, radians per second.
    public let steer: Double
    /// How fast sideways sliding dies away (higher = more grip).
    public let grip: Double
    /// Speed lost while sliding sideways.
    public let scrub: Double
    /// Slipstream gain multiplier.
    public let draft: Double
    /// Multiplier on the time lost when bumping an echo.
    public let bumpFactor: Double
    /// How much sand, mud and grass slow this car (1 = normal, lower = less slowdown).
    public let roughPenalty: Double
    /// Grip kept on ice (fraction of normal grip).
    public let iceGrip: Double
    /// Total stars needed to unlock.
    public let starsToUnlock: Int
    /// Body shape drawn by the app.
    public let shape: String
    /// Factory paint, as a hex colour.
    public let color: UInt32

    /// 1...5 bars for the garage screen.
    public var bars: (speed: Int, grip: Int, accel: Int, draft: Int) {
        func scale(_ v: Double, _ lo: Double, _ hi: Double) -> Int { clamp(Int(((v - lo) / (hi - lo) * 4).rounded()) + 1, 1, 5) }
        return (scale(topSpeed, 330, 365), scale(grip, 6.5, 10.5), scale(accel, 380, 470), scale(draft, 0.8, 1.6))
    }
}

public enum Cars {
    public static let pip = CarSpec(id: "pip", name: "Pip", role: "All-rounder", topSpeed: 340, accel: 430, steer: 3.0, grip: 9,
                                    scrub: 0.9, draft: 1.0, bumpFactor: 1.0, roughPenalty: 1.0, iceGrip: 0.4,
                                    starsToUnlock: 0, shape: "pod", color: 0xF5F7FA)
    public static let wedge = CarSpec(id: "wedge", name: "Wedge", role: "Top speed, wide turns", topSpeed: 362, accel: 405, steer: 2.75,
                                      grip: 8.2, scrub: 0.95, draft: 0.9, bumpFactor: 1.0, roughPenalty: 1.05, iceGrip: 0.38,
                                      starsToUnlock: 30, shape: "wedge", color: 0xE05A47)
    public static let hopper = CarSpec(id: "hopper", name: "Dune Hopper", role: "Grip on sand and mud", topSpeed: 334, accel: 440,
                                       steer: 3.0, grip: 10.5, scrub: 0.85, draft: 1.0, bumpFactor: 1.0, roughPenalty: 0.45,
                                       iceGrip: 0.45, starsToUnlock: 75, shape: "buggy", color: 0xE3B341)
    public static let brick = CarSpec(id: "brick", name: "Brick", role: "Heavy: shrugs off bumps", topSpeed: 345, accel: 385, steer: 2.85,
                                      grip: 9.5, scrub: 0.9, draft: 0.8, bumpFactor: 0.55, roughPenalty: 0.9, iceGrip: 0.42,
                                      starsToUnlock: 120, shape: "brick", color: 0x3F8FD2)
    public static let needle = CarSpec(id: "needle", name: "Needle", role: "Light: huge slipstream gain", topSpeed: 348, accel: 468,
                                       steer: 3.1, grip: 8.0, scrub: 0.95, draft: 1.6, bumpFactor: 1.25, roughPenalty: 1.1,
                                       iceGrip: 0.36, starsToUnlock: 180, shape: "needle", color: 0x4CB28B)
    public static let drifter = CarSpec(id: "drifter", name: "Drifter", role: "Slides for ever; ice expert", topSpeed: 352, accel: 440,
                                        steer: 3.3, grip: 6.5, scrub: 0.5, draft: 1.2, bumpFactor: 1.0, roughPenalty: 1.0,
                                        iceGrip: 0.85, starsToUnlock: 250, shape: "hover", color: 0xB49BFF)

    public static let all: [CarSpec] = [pip, wedge, hopper, brick, needle, drifter]

    public static func car(id: String) -> CarSpec { all.first { $0.id == id } ?? pip }
}
