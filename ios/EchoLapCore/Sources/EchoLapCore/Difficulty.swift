import Foundation

/// The difficulty curve from track 1 to track 120 (see concept/concept-brief.md, "Difficulty curve").
/// Every number the generator and the star targets use comes from here.
public struct Difficulty: Equatable, Sendable {
    /// Road width in world units (a car is 22 wide).
    public let roadWidth: Double
    /// Target centreline length of one lap, in world units.
    public let lapLength: Double
    /// Tightest corner allowed, as a radius in world units (a car is 40 long).
    public let minRadius: Double
    /// Shape complexity 0...1: more and wilder control points on later tracks.
    public let wiggle: Double
    /// Gold time = robot time × (1 + goldSlack). Silver likewise.
    public let goldSlack: Double
    public let silverSlack: Double
    /// Seconds lost spinning after bumping a solid echo (0 when echoes are soft).
    public let bumpPenalty: Double

    /// Average speed the generator assumes when sizing a lap (units per second). The robot's real lap time is tested.
    public static let assumedLapSpeed = 300.0

    public static func of(_ def: TrackDef) -> Difficulty {
        let t = Double(clamp(def.index, 1, 120) - 1) / 119
        let breather = def.kind == .breather
        let boss = def.kind == .boss
        let widthCars = 3.3 - 0.9 * t + (breather ? 0.3 : 0)
        // One sprint: about 20 seconds on track 1 up to about 40 on track 120; breathers shorter, bosses longer.
        let lapSeconds = (20 + 0.17 * Double(def.index - 1)) * (breather ? 0.8 : (boss ? 1.15 : 1))
        // Tight enough from the first track that the hairpins ask for a drift; the last tracks need a brake as well.
        let minRadiusCars = 3.0 - 1.0 * t
        let slackBonus = breather ? 0.03 : 0
        return Difficulty(
            roadWidth: widthCars * Physics.carWidth,
            lapLength: lapSeconds * assumedLapSpeed,
            minRadius: minRadiusCars * Physics.carLength,
            wiggle: t,
            goldSlack: 0.06 - 0.04 * t + slackBonus,
            silverSlack: 0.16 - 0.08 * t + slackBonus,
            bumpPenalty: def.softEchoes ? 0 : (0.6 + 0.4 * Double(max(0, def.index - 16)) / 104)
        )
    }
}
