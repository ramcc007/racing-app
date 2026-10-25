import Foundation

/// Every reward number in one place. Sparks are earned only (never bought) and spent only on looks.
public enum Economy {
    /// Sparks for reaching each star level on a track for the first time (1★, 2★, 3★): 20, then +15, then +15.
    public static let starSparks = [0, 20, 35, 50]
    public static let medalSparks = 40
    /// Each rung climbed on a track's echo ladder (a new best with more echoes on the road), and mastering a track.
    public static let rungSparks = 15
    public static let masteredSparks = 60
    /// Any finish that earns nothing new still pays a little.
    public static let replaySparks = 10
    public static let dailyFirstFinishSparks = 60
    /// Extra Sparks per day of daily streak, up to 7 days.
    public static let dailyStreakSparks = 10
    public static let dailyStreakCap = 7
    public static let weeklyCompleteSparks = 150
    public static let weeklyReplaySparks = 15
    public static let survivalSparksPerLap = 5
    public static let survivalSparksCap = 100
    public static let goalSparks = 30
    public static let allGoalsBonus = 50
    public static let levelUpSparks = 100

    // XP
    public static let finishXP = 40
    public static let starXP = 15
    public static let medalXP = 25
    public static let rungXP = 10
    public static let masteredXP = 60
    public static let dailyXP = 30
    public static let survivalLapXP = 10
    public static let unfinishedXP = 10

    /// Total XP needed to reach a driver level: 30 × L × (L − 1). Level 2 at 60 XP, level 10 at 2,700, level 50 at 73,500.
    /// A full career (all gold, all medals) lands in the low twenties; mastering every ladder, dailies, the gauntlet
    /// and Survival carry you further.
    public static func xpForLevel(_ level: Int) -> Int { 30 * level * (level - 1) }

    public static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpForLevel(level + 1) <= xp { level += 1 }
        return level
    }

    public static func title(forLevel level: Int) -> String {
        switch level {
        case ..<5: return "Rookie"
        case 5..<10: return "Club Racer"
        case 10..<15: return "Pro"
        case 15..<20: return "Ace"
        case 20..<30: return "Champion"
        case 30..<40: return "Legend"
        default: return "Echo Master"
        }
    }
}

/// Something to buy with Sparks: a paint for any racer, an echo-trail style, or a finish celebration.
public struct Cosmetic: Hashable, Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case paint, trail, finish }
    public let id: String
    public let kind: Kind
    public let name: String
    public let price: Int
    /// One colour, or two for gradients (hex RGB). Empty for the factory paint (each racer's own colour).
    public let colors: [UInt32]
}

public enum Cosmetics {
    public static let all: [Cosmetic] = [
        Cosmetic(id: "paint.factory", kind: .paint, name: "Factory", price: 0, colors: []),
        Cosmetic(id: "paint.mint", kind: .paint, name: "Mint", price: 200, colors: [0x5FE3B0]),
        Cosmetic(id: "paint.coral", kind: .paint, name: "Coral", price: 250, colors: [0xFF7F6B]),
        Cosmetic(id: "paint.sky", kind: .paint, name: "Sky", price: 250, colors: [0x5EC8FF]),
        Cosmetic(id: "paint.lemon", kind: .paint, name: "Lemon", price: 300, colors: [0xFFE45C]),
        Cosmetic(id: "paint.grape", kind: .paint, name: "Grape", price: 350, colors: [0x9B7BFF]),
        Cosmetic(id: "paint.rose", kind: .paint, name: "Rose", price: 350, colors: [0xFF8FC8]),
        Cosmetic(id: "paint.carbon", kind: .paint, name: "Carbon", price: 500, colors: [0x2B2F36]),
        Cosmetic(id: "paint.chrome", kind: .paint, name: "Chrome", price: 600, colors: [0xC9D2DC]),
        Cosmetic(id: "paint.lime", kind: .paint, name: "Neon Lime", price: 600, colors: [0xB7F23B]),
        Cosmetic(id: "paint.lava", kind: .paint, name: "Lava", price: 800, colors: [0xFF5A1F]),
        Cosmetic(id: "paint.aurora", kind: .paint, name: "Aurora", price: 1200, colors: [0x5EF2C4, 0x8F7BFF]),
        Cosmetic(id: "paint.galaxy", kind: .paint, name: "Galaxy", price: 1500, colors: [0x1B1446, 0xB49BFF]),
        Cosmetic(id: "trail.classic", kind: .trail, name: "Classic", price: 0, colors: []),
        Cosmetic(id: "trail.dotted", kind: .trail, name: "Dotted", price: 300, colors: []),
        Cosmetic(id: "trail.ribbon", kind: .trail, name: "Ribbon", price: 500, colors: []),
        Cosmetic(id: "trail.neon", kind: .trail, name: "Neon", price: 800, colors: []),
        Cosmetic(id: "trail.sparkle", kind: .trail, name: "Sparkle", price: 1100, colors: []),
        Cosmetic(id: "trail.comet", kind: .trail, name: "Comet", price: 1400, colors: []),
        Cosmetic(id: "trail.rainbow", kind: .trail, name: "Rainbow", price: 2000, colors: []),
        Cosmetic(id: "finish.confetti", kind: .finish, name: "Confetti", price: 0, colors: []),
        Cosmetic(id: "finish.checkered", kind: .finish, name: "Chequered flags", price: 450, colors: []),
        Cosmetic(id: "finish.fireworks", kind: .finish, name: "Fireworks", price: 700, colors: []),
        Cosmetic(id: "finish.stars", kind: .finish, name: "Star shower", price: 900, colors: []),
    ]

    public static let freeIDs: Set<String> = Set(all.filter { $0.price == 0 }.map(\.id))

    public static func item(_ id: String) -> Cosmetic? { all.first { $0.id == id } }

    public static func items(_ kind: Cosmetic.Kind) -> [Cosmetic] { all.filter { $0.kind == kind } }

    /// Sparks needed to own everything (shown as "collection" progress).
    public static var totalPrice: Int { all.reduce(0) { $0 + $1.price } }
}
