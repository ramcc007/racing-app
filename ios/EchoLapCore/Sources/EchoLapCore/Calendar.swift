import Foundation

/// A calendar day in the player's own time zone, e.g. "2026-10-25". The daily track changes at local midnight.
public struct DayKey: Hashable, Codable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
    }

    public init?(_ string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var string: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// Days since 1 January 2000 (proleptic Gregorian, no time zones), so day arithmetic is exact.
    public var ordinal: Int {
        // Howard Hinnant's days_from_civil.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468 - 10_957
    }

    public init(ordinal: Int) {
        let z = ordinal + 10_957 + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    public func adding(days: Int) -> DayKey { DayKey(ordinal: ordinal + days) }

    public static func < (a: DayKey, b: DayKey) -> Bool { a.ordinal < b.ordinal }

    /// Monday-based week this day belongs to.
    public var week: WeekKey {
        // 2000-01-03 was a Monday (ordinal 2).
        let weekIndex = Int((Double(ordinal - 2) / 7).rounded(.down))
        return WeekKey(index: weekIndex)
    }

    /// Short label like "25 Oct".
    public var shortLabel: String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(day) \(names[month - 1])"
    }
}

/// A Monday-to-Sunday week, numbered from the week of 3 January 2000.
public struct WeekKey: Hashable, Codable, Comparable, Sendable {
    public let index: Int
    public init(index: Int) { self.index = index }
    public var string: String { "w\(index)" }
    public var monday: DayKey { DayKey(ordinal: index * 7 + 2) }
    public static func < (a: WeekKey, b: WeekKey) -> Bool { a.index < b.index }
}
