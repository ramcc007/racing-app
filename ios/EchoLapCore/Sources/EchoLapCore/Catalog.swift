import Foundation

/// A rule a track can use on top of the echoes everyone always has.
public enum Feature: String, Codable, CaseIterable, Sendable {
    /// Echoes don't spin you out; you pass through with a small slowdown (World 1 only).
    case softEchoes
    /// Sand or mud patches on part of the road: slower and less grip. There is always a clean line.
    case sand
    /// A shortcut behind a gate. The gate opens while any car is parked in the green bay before it.
    case pads
    /// Fast, slippery ice on part of the road. Every pass by any car cracks it; three passes and it breaks into water.
    case thinIce
    /// Once a lap you can swap places with the echo just ahead of you.
    case relay
    /// A shortcut behind a bridge. Driving through the sensor bay lowers the bridge for a few seconds.
    case sensors
    /// Crosswind zones push you sideways; an echo just ahead shelters you.
    case wind
    /// Ramps that launch you into a low-gravity jump: no steering in the air, and you fly over echoes.
    case jumps
}

/// The eight worlds. Each one adds one new rule that works with your echoes.
public enum World: Int, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case harbour = 1, canyon, neon, glacier, jungle, foundry, skyport, orbit

    public var id: Int { rawValue }
    public static func < (a: World, b: World) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .harbour: return "Harbour"
        case .canyon: return "Red Canyon"
        case .neon: return "Neon City"
        case .glacier: return "Glacier"
        case .jungle: return "Jungle Ruins"
        case .foundry: return "Foundry"
        case .skyport: return "Sky Port"
        case .orbit: return "Orbit Ring"
        }
    }

    /// The rule this world introduces, as a short title.
    public var ruleTitle: String {
        switch self {
        case .harbour: return "Echoes and slipstream"
        case .canyon: return "Echoes turn solid"
        case .neon: return "Switch pads and gates"
        case .glacier: return "Thin ice"
        case .jungle: return "Relay swap"
        case .foundry: return "Sensor bridges"
        case .skyport: return "Crosswinds"
        case .orbit: return "Low-gravity jumps"
        }
    }

    /// One or two sentences that teach the rule.
    public var ruleText: String {
        switch self {
        case .harbour:
            return "Every lap you finish stays on the track as an echo. Tuck in right behind one to fill your boost. Here, echoes are soft: you pass through them."
        case .canyon:
            return "From now on echoes are solid. Touch one and you spin out, so choose lines your next laps can use. Sand slows you down."
        case .neon:
            return "Park in the green bay and the shortcut gate opens. Your parked echo keeps it open on later laps."
        case .glacier:
            return "Ice is fast but slippery. Every pass by any car cracks it, and after three passes it breaks into water."
        case .jungle:
            return "Once a lap, double-tap to swap places with the echo just ahead of you."
        case .foundry:
            return "Drive through the sensor bay to lower the bridge on the shortcut for a few seconds. Echoes trigger it too."
        case .skyport:
            return "Crosswinds push you sideways. An echo just ahead of you shelters you from the wind."
        case .orbit:
            return "Ramps launch you into long, low-gravity jumps. You can't steer in the air, but you fly over echoes. Every rule comes back here."
        }
    }

    /// Total stars needed to open this world. Each world holds 45 stars (15 tracks × 3); a player averaging two stars
    /// per track (30 a world) can always open the next world, so silver play is enough to see the whole game.
    public var starsToUnlock: Int {
        [0, 20, 50, 80, 110, 140, 170, 200][rawValue - 1]
    }

    /// The new rule of this world.
    public var primaryFeatures: Set<Feature> {
        switch self {
        case .harbour: return [.softEchoes]
        case .canyon: return [.sand]
        case .neon: return [.pads]
        case .glacier: return [.thinIce]
        case .jungle: return [.relay, .sand]
        case .foundry: return [.sensors]
        case .skyport: return [.wind]
        case .orbit: return [.jumps]
        }
    }

    /// An earlier rule mixed in on the later tracks of the world (slots 6–15).
    public var secondaryFeatures: Set<Feature> {
        switch self {
        case .harbour: return []
        case .canyon: return []
        case .neon: return [.sand]
        case .glacier: return [.pads]
        case .jungle: return [.thinIce]
        case .foundry: return [.sand]
        case .skyport: return [.thinIce]
        case .orbit: return [.pads, .wind, .relay]
        }
    }

    /// The optional per-track challenge ("echo medal") for this world.
    public var medal: Medal {
        switch self {
        case .harbour: return .draftTrain
        case .canyon: return .clean
        case .neon: return .gatekeeper
        case .glacier: return .iceDancer
        case .jungle: return .relay
        case .foundry: return .bridgeTimer
        case .skyport: return .shelter
        case .orbit: return .echoMaster
        }
    }

    /// Track names, slot 1...15. Original names; none is the name of another game.
    public var trackNames: [String] {
        switch self {
        case .harbour:
            return ["First Light", "Quay Street", "Bollard Bend", "Crane Row", "Tug Break", "Pier Pressure", "Container Maze",
                    "Salt Spray", "Dock Loop", "Lighthouse Rest", "Ferry Run", "Anchor Point", "Dry Dock", "Night Tide", "Harbour Master"]
        case .canyon:
            return ["Dust Line", "Mesa Run", "Rattle Gap", "Coyote Turn", "Sun Rest", "Dust Devil", "Red Hairpins", "Sandstone S",
                    "Dry Creek", "Oasis Break", "Arch Rush", "Rimrock", "Mirage Mile", "Canyon Echo", "Red Giant"]
        case .neon:
            return ["Neon Gate", "Arcade Alley", "Signal Street", "Glowline", "Night Café", "Neon Alley", "Pad Lock",
                    "Midnight Merge", "Hologram Hill", "Rooftop Rest", "Laser Lane", "Night Shift", "Pixel Plaza", "Overdrive", "Neon Crown"]
        case .glacier:
            return ["First Frost", "Crack Line", "Snowdrift", "Blue Ice", "Igloo Rest", "Polar Bend", "Thin Ice", "Frost Bite",
                    "Aurora Run", "Cocoa Break", "Iceberg Alley", "Floe Motion", "Whiteout", "Shatter Point", "Frozen Crown"]
        case .jungle:
            return ["Vine Line", "Temple Steps", "Mud Slide", "Parrot Pass", "River Rest", "Relay Ruins", "Monkey Bend",
                    "Fern Hollow", "Canopy Dash", "Waterfall Break", "Idol Gate", "Root Maze", "Moss Mile", "Lost Lap", "Jungle Crown"]
        case .foundry:
            return ["Spark Line", "Rivet Run", "Conveyor", "Smelter Bend", "Steam Break", "Sensor Sweep", "Iron Gate", "Slag Hill",
                    "Molten Mile", "Cooling Rest", "Forge Turn", "Bridge Works", "Crucible", "Furnace Rush", "Foundry Crown"]
        case .skyport:
            return ["Lift Off", "Tailwind", "Cloud Nine", "Gust Gate", "Hangar Rest", "Crosswind", "Jet Stream", "Updraft",
                    "Windsock", "Lounge Break", "High Pass", "Sky Bridge", "Turbulence", "Storm Front", "Sky Crown"]
        case .orbit:
            return ["Low Orbit", "Moon Hop", "Star Lane", "Zero G", "Dock Rest", "Comet Tail", "Asteroid Run", "Gravity Well",
                    "Solar Wind", "Station Break", "Nebula", "Eclipse", "Event Horizon", "Echo Storm", "Last Echo"]
        }
    }
}

/// The optional challenge on each track. Earning it once gives Sparks and counts towards achievements.
public enum Medal: String, Codable, CaseIterable, Sendable {
    case draftTrain, clean, gatekeeper, iceDancer, relay, bridgeTimer, shelter, echoMaster

    public var title: String {
        switch self {
        case .draftTrain: return "Draft train"
        case .clean: return "Clean run"
        case .gatekeeper: return "Gatekeeper"
        case .iceDancer: return "Ice dancer"
        case .relay: return "Relay"
        case .bridgeTimer: return "Bridge timer"
        case .shelter: return "Shelter"
        case .echoMaster: return "Echo master"
        }
    }

    public var goal: String {
        switch self {
        case .draftTrain: return "Slipstream behind your echoes."
        case .clean: return "Finish without bumping a solid echo."
        case .gatekeeper: return "Drive through the gate while an echo holds it open."
        case .iceDancer: return "Finish without falling through the ice."
        case .relay: return "Swap places with your echoes."
        case .bridgeTimer: return "Cross the bridge after an echo lowered it."
        case .shelter: return "Spend time in your echoes' slipstream."
        case .echoMaster: return "No bumps, plenty of slipstream."
        }
    }

    /// The number the goal asks for on a track with this many laps (only laps 2+ have echoes to use).
    public func target(laps: Int) -> Int {
        let echoLaps = max(1, laps - 1)
        switch self {
        case .draftTrain: return 1 + 2 * echoLaps
        case .clean, .iceDancer: return 0
        case .gatekeeper, .bridgeTimer, .relay: return 2
        case .shelter: return 3 + 2 * echoLaps
        case .echoMaster: return 1 + echoLaps
        }
    }

    public func goal(laps: Int) -> String {
        let n = target(laps: laps)
        switch self {
        case .draftTrain: return "Slipstream behind echoes \(n) times."
        case .clean: return "Finish without bumping a solid echo."
        case .gatekeeper: return "Drive through the gate twice while an echo holds it open."
        case .iceDancer: return "Finish without falling through the ice."
        case .relay: return "Swap places with an echo twice."
        case .bridgeTimer: return "Cross the bridge twice after an echo lowered it."
        case .shelter: return "Slipstream for \(n) seconds in total."
        case .echoMaster: return "Finish with no bumps and \(n) slipstreams."
        }
    }

    /// Whether a finished race earned this medal.
    public func isEarned(by stats: RaceStats, laps: Int) -> Bool {
        let n = target(laps: laps)
        switch self {
        case .draftTrain: return stats.drafts >= n
        case .clean: return stats.bumps == 0
        case .gatekeeper, .bridgeTimer: return stats.echoGatePasses >= n
        case .iceDancer: return stats.splashes == 0
        case .relay: return stats.swaps >= n
        case .shelter: return stats.draftSeconds >= Double(n)
        case .echoMaster: return stats.bumps == 0 && stats.drafts >= n
        }
    }
}

/// What kind of event a track is.
public enum RaceMode: String, Codable, Sendable {
    case career, daily, weekly, survival
}

/// Every track is fully described by this: the generator turns it into the same circuit on every device.
public struct TrackDef: Hashable, Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case normal, breather, boss }

    public let id: String
    public let world: World
    /// 1...15 within the world (0 for daily, weekly and survival tracks).
    public let slot: Int
    /// Difficulty index 1...120 (career order).
    public let index: Int
    public let kind: Kind
    public let laps: Int
    public let seed: UInt64
    public let name: String
    public let features: Set<Feature>
    public let mode: RaceMode

    public init(id: String, world: World, slot: Int, index: Int, kind: Kind, laps: Int, seed: UInt64,
                name: String, features: Set<Feature>, mode: RaceMode) {
        self.id = id
        self.world = world
        self.slot = slot
        self.index = index
        self.kind = kind
        self.laps = laps
        self.seed = seed
        self.name = name
        self.features = features
        self.mode = mode
    }

    /// "3-7" style label shown on the map.
    public var label: String { slot > 0 ? "\(world.rawValue)-\(slot)" : name }

    /// Echoes are solid everywhere except World 1 career tracks.
    public var softEchoes: Bool { features.contains(.softEchoes) }

    /// The echo medal for this track: the world's medal, or an easier one on two-lap breathers.
    public var medal: Medal? {
        guard mode == .career else { return nil }
        if kind == .breather { return softEchoes ? .draftTrain : .clean }
        return world.medal
    }
}

/// The 120 career tracks, in order.
public enum Catalog {
    public static let tracksPerWorld = 15

    public static let career: [TrackDef] = World.allCases.flatMap { world in
        (1...tracksPerWorld).map { slot in careerTrack(world: world, slot: slot) }
    }

    private static let byID: [String: TrackDef] = Dictionary(uniqueKeysWithValues: career.map { ($0.id, $0) })

    public static func track(id: String) -> TrackDef? { byID[id] }

    public static func tracks(in world: World) -> [TrackDef] {
        Array(career[(world.rawValue - 1) * tracksPerWorld ..< world.rawValue * tracksPerWorld])
    }

    /// The track that comes after this one in the career, if any.
    public static func next(after def: TrackDef) -> TrackDef? {
        guard let i = career.firstIndex(of: def), i + 1 < career.count else { return nil }
        return career[i + 1]
    }

    public static func previous(of def: TrackDef) -> TrackDef? {
        guard let i = career.firstIndex(of: def), i > 0 else { return nil }
        return career[i - 1]
    }

    static func kind(slot: Int) -> TrackDef.Kind {
        if slot == 15 { return .boss }
        if slot == 5 || slot == 10 { return .breather }
        return .normal
    }

    /// Laps per the difficulty curve: 2–3 in World 1 up to 6–7 in World 8; breathers 2; bosses one more than usual.
    static func laps(world: World, slot: Int) -> Int {
        let low = [2, 3, 4, 4, 4, 5, 5, 6][world.rawValue - 1]
        switch kind(slot: slot) {
        case .breather: return 2
        case .boss: return low + 2
        case .normal: return slot >= 8 ? low + 1 : low
        }
    }

    static func careerTrack(world: World, slot: Int) -> TrackDef {
        let id = "\(world.rawValue)-\(slot)"
        var features = world.primaryFeatures
        if slot >= 6 { features.formUnion(world.secondaryFeatures) }
        return TrackDef(id: id, world: world, slot: slot, index: (world.rawValue - 1) * tracksPerWorld + slot,
                        kind: kind(slot: slot), laps: laps(world: world, slot: slot),
                        seed: stableHash("echolap.career." + id), name: world.trackNames[slot - 1],
                        features: features, mode: .career)
    }

    // MARK: - Daily, weekly and survival tracks

    /// Today's track: the same for every player on the same calendar day. Uses only the first three worlds' rules,
    /// so every player can play it, and cycles through their looks.
    public static func daily(_ day: DayKey) -> TrackDef {
        var rng = SeededRandom(seed: stableHash("echolap.daily." + day.string))
        let world: World = [.harbour, .canyon, .neon][rng.int(3)]
        let features: Set<Feature> = world == .harbour ? [] : world.primaryFeatures
        return TrackDef(id: "daily-" + day.string, world: world, slot: 0, index: 18 + rng.int(28), kind: .normal, laps: 3,
                        seed: rng.next(), name: "Daily track", features: features, mode: .daily)
    }

    /// This week's gauntlet: three tracks raced back to back, total time counts.
    public static func weekly(_ week: WeekKey) -> [TrackDef] {
        var rng = SeededRandom(seed: stableHash("echolap.weekly." + week.string))
        return (1...3).map { n in
            let world = World(rawValue: 1 + rng.int(4))!
            let features: Set<Feature> = world == .harbour ? [] : world.primaryFeatures
            return TrackDef(id: "weekly-\(week.string)-\(n)", world: world, slot: 0, index: 25 + rng.int(36), kind: .normal,
                            laps: 3, seed: rng.next(), name: "Gauntlet \(n) of 3", features: features, mode: .weekly)
        }
    }

    /// Echo Survival: laps never end and every lap adds an echo. Three bumps and the run is over.
    public static func survival(_ day: DayKey) -> TrackDef {
        var rng = SeededRandom(seed: stableHash("echolap.survival." + day.string))
        return TrackDef(id: "survival-" + day.string, world: [.canyon, .neon, .orbit][rng.int(3)], slot: 0, index: 12, kind: .breather,
                        laps: Int.max, seed: rng.next(), name: "Echo Survival", features: [], mode: .survival)
    }

    /// The career track that unlocks Echo Survival once finished.
    public static let survivalUnlockTrack = "1-5"
    /// Total stars that unlock the weekly gauntlet.
    public static let weeklyUnlockStars = 20
}
