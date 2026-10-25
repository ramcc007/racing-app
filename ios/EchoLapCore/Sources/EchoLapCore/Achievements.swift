import Foundation

/// Achievements, unlocked from saved progress. The Game Center IDs are "echolap.ach." + id
/// and must match App Store Connect exactly (docs/GAME_CENTER_SETUP.md).
public struct Achievement: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    let check: @Sendable (PlayerProgress) -> Bool

    public var gameCenterID: String { "echolap.ach." + id }

    public static func == (a: Achievement, b: Achievement) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }

    public func isUnlocked(in progress: PlayerProgress) -> Bool { check(progress) }

    public static let all: [Achievement] = {
        var list: [Achievement] = [
            Achievement(id: "firstFinish", title: "Lights out", detail: "Finish your first race.") { $0.stats.finishes >= 1 },
            Achievement(id: "firstGold", title: "Gold standard", detail: "Earn three stars on a track.") { p in p.tracks.values.contains { $0.stars >= 3 } },
        ]
        for world in World.allCases {
            let boss = "\(world.rawValue)-15"
            list.append(Achievement(id: "world\(world.rawValue)", title: "\(world.name) cleared",
                                    detail: "Finish the boss track of \(world.name).") { $0.tracks[boss] != nil })
        }
        list += [
            Achievement(id: "stars50", title: "Star collector", detail: "Earn 50 stars.") { $0.totalStars >= 50 },
            Achievement(id: "stars150", title: "Constellation", detail: "Earn 150 stars.") { $0.totalStars >= 150 },
            Achievement(id: "stars300", title: "Galaxy", detail: "Earn 300 stars.") { $0.totalStars >= 300 },
            Achievement(id: "stars360", title: "Every star", detail: "Earn all 360 stars.") { $0.totalStars >= 360 },
            Achievement(id: "medals10", title: "Decorated", detail: "Earn 10 echo medals.") { $0.medalCount >= 10 },
            Achievement(id: "medals60", title: "Medal case", detail: "Earn 60 echo medals.") { $0.medalCount >= 60 },
            Achievement(id: "medals120", title: "Full honours", detail: "Earn every echo medal.") { $0.medalCount >= 120 },
            Achievement(id: "mastered1", title: "Top of the ladder", detail: "Master a track: five echoes beaten with gold.") { $0.masteredCount >= 1 },
            Achievement(id: "mastered15", title: "Ladder climber", detail: "Master 15 tracks.") { $0.masteredCount >= 15 },
            Achievement(id: "mastered60", title: "Echo legend", detail: "Master 60 tracks.") { $0.masteredCount >= 60 },
            Achievement(id: "drifts100", title: "Sideways", detail: "Earn 100 drift boosts.") { $0.stats.driftBoosts >= 100 },
            Achievement(id: "drifts1000", title: "Drift king", detail: "Earn 1,000 drift boosts.") { $0.stats.driftBoosts >= 1000 },
            Achievement(id: "nearMiss50", title: "By a whisker", detail: "Pass your echoes within a whisker 50 times.") { $0.stats.nearMisses >= 50 },
            Achievement(id: "nearMiss500", title: "Paint trader", detail: "500 near misses.") { $0.stats.nearMisses >= 500 },
            Achievement(id: "drafts100", title: "Slipstreamer", detail: "Slipstream behind echoes 100 times.") { $0.stats.drafts >= 100 },
            Achievement(id: "boosts250", title: "Afterburner", detail: "Fire the nitro 250 times.") { $0.stats.boosts >= 250 },
            Achievement(id: "swaps50", title: "Relay runner", detail: "Relay-swap 50 times.") { $0.stats.swaps >= 50 },
            Achievement(id: "gate25", title: "Gatekeeper", detail: "Pass 25 gates or bridges your echoes opened.") { $0.stats.echoGatePasses >= 25 },
            Achievement(id: "ice30", title: "Icebreaker", detail: "Break 30 sheets of thin ice.") { $0.stats.iceBreaks >= 30 },
            Achievement(id: "jumps100", title: "Moonwalker", detail: "Take 100 jumps.") { $0.stats.jumps >= 100 },
            Achievement(id: "sprints1000", title: "Marathon", detail: "Finish 1,000 sprints.") { $0.stats.finishes >= 1000 },
            Achievement(id: "daily1", title: "Daily driver", detail: "Finish a daily track.") { !$0.daily.isEmpty },
            Achievement(id: "streak3", title: "Three in a row", detail: "Finish the daily track 3 days in a row.") { $0.bestDailyStreak >= 3 },
            Achievement(id: "streak7", title: "Week streak", detail: "Finish the daily track 7 days in a row.") { $0.bestDailyStreak >= 7 },
            Achievement(id: "streak30", title: "Month streak", detail: "Finish the daily track 30 days in a row.") { $0.bestDailyStreak >= 30 },
            Achievement(id: "weekly1", title: "Gauntlet runner", detail: "Finish a weekly gauntlet.") { p in p.weekly.values.contains { $0.bestTotal != nil } },
            Achievement(id: "survival10", title: "Crowd control", detail: "Survive 10 laps in Echo Survival.") { $0.survivalBest >= 10 },
            Achievement(id: "survival25", title: "Echo chamber", detail: "Survive 25 laps in Echo Survival.") { $0.survivalBest >= 25 },
            Achievement(id: "level10", title: "Pro driver", detail: "Reach driver level 10.") { $0.level >= 10 },
            Achievement(id: "level25", title: "Champion", detail: "Reach driver level 25.") { $0.level >= 25 },
            Achievement(id: "garage", title: "Full garage", detail: "Unlock all six racers.") { $0.totalStars >= Cars.all.map(\.starsToUnlock).max()! },
            Achievement(id: "stylist", title: "Stylist", detail: "Own 10 paints, trails or celebrations you bought.") { $0.owned.subtracting(Cosmetics.freeIDs).count >= 10 },
        ]
        return list
    }()

    public static func unlocked(in progress: PlayerProgress) -> [Achievement] { all.filter { $0.check(progress) } }
}
