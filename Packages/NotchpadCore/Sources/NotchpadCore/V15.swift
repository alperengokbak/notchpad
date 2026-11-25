import Foundation

// MARK: World clock

public struct ClockRow: Equatable, Sendable {
    public var zoneID: String
    public var city: String
    /// "01:30"
    public var time: String
    /// "+3 h", "−5 h", "+5 h 30 min", "Same time" (compared with this Mac's time zone).
    public var offset: String
    /// "Tomorrow" / "Yesterday" when the date there differs from here; nil on the same day.
    public var day: String?
}

public enum WorldClock {
    /// "America/Argentina/Buenos_Aires" → "Buenos Aires".
    public static func cityName(_ zoneID: String) -> String {
        (zoneID.split(separator: "/").last.map(String.init) ?? zoneID).replacingOccurrences(of: "_", with: " ")
    }

    public static func row(zoneID: String, now: Date, local: TimeZone) -> ClockRow? {
        guard let zone = TimeZone(identifier: zoneID) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = zone
        f.dateFormat = "HH:mm"
        let diff = zone.secondsFromGMT(for: now) - local.secondsFromGMT(for: now)
        var thereCal = Calendar(identifier: .gregorian)
        thereCal.timeZone = zone
        var hereCal = Calendar(identifier: .gregorian)
        hereCal.timeZone = local
        let there = thereCal.dateComponents([.year, .month, .day], from: now)
        let here = hereCal.dateComponents([.year, .month, .day], from: now)
        var day: String?
        if there != here, let a = thereCal.date(from: there), let b = thereCal.date(from: here) {
            day = a > b ? "Tomorrow" : "Yesterday"
        }
        return ClockRow(zoneID: zoneID, city: cityName(zoneID), time: f.string(from: now), offset: offsetText(diff), day: day)
    }

    static func offsetText(_ seconds: Int) -> String {
        guard seconds != 0 else { return "Same time" }
        let sign = seconds > 0 ? "+" : "−"
        let minutes = abs(seconds) / 60
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(sign)\(h) h" : (h == 0 ? "\(sign)\(m) min" : "\(sign)\(h) h \(m) min")
    }

    /// Every city macOS knows, grouped by region (Africa, America, Asia, Europe…), for the + menu.
    public static func zonesByRegion() -> [(region: String, zones: [String])] {
        let regions = ["Africa", "America", "Antarctica", "Asia", "Atlantic", "Australia", "Europe", "Indian", "Pacific"]
        let all = TimeZone.knownTimeZoneIdentifiers
        return regions.compactMap { region in
            let zones = all.filter { $0.hasPrefix(region + "/") }
                .sorted { cityName($0) < cityName($1) }
            return zones.isEmpty ? nil : (region, zones)
        }
    }
}

// MARK: Focus history

/// Focus minutes per day ("yyyy-MM-dd"), kept for 60 days.
public struct FocusLog: Codable, Equatable, Sendable {
    public private(set) var days: [String: Int] = [:]

    public init(days: [String: Int] = [:]) { self.days = days }

    public mutating func record(minutes: Int, at date: Date, calendar: Calendar) {
        guard minutes >= 1 else { return }
        days[Self.key(date, calendar), default: 0] += minutes
        // Forget days more than 60 days before this one.
        if let cutoff = calendar.date(byAdding: .day, value: -60, to: calendar.startOfDay(for: date)) {
            let cutoffKey = Self.key(cutoff, calendar)
            days = days.filter { $0.key >= cutoffKey }
        }
    }

    public func minutesToday(now: Date, calendar: Calendar) -> Int {
        days[Self.key(now, calendar)] ?? 0
    }

    /// From the start of this week (the calendar's first weekday) up to today.
    public func minutesThisWeek(now: Date, calendar: Calendar) -> Int {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        var total = 0
        var day = start
        while day <= now {
            total += days[Self.key(day, calendar)] ?? 0
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return total
    }

    /// "50 min", "2 h", "3 h 20 min".
    public static func text(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    static func key(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension FocusTimer {
    /// Minutes actually focused when a session of `planned` seconds stops with `remaining` left (rounded down).
    public static func focusedMinutes(planned: TimeInterval, remaining: TimeInterval) -> Int {
        Int(max(0, planned - remaining) / 60)
    }
}
