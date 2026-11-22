import Foundation

/// A calendar event, reduced to what the panel shows.
public struct EventSummary: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    /// Calendar colour, sRGB 0…1.
    public var red: Double, green: Double, blue: Double

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool,
                red: Double, green: Double, blue: Double) {
        self.id = id; self.title = title; self.start = start; self.end = end; self.isAllDay = isAllDay
        self.red = red; self.green = green; self.blue = blue
    }
}

public enum CalendarAccess: Sendable { case unknown, granted, denied }

public enum DayEvents {
    /// Timed events from now until midnight, including ones happening now, earliest first.
    public static func upcoming(_ events: [EventSummary], now: Date, calendar: Calendar, limit: Int = 3) -> [EventSummary] {
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        return events
            .filter { !$0.isAllDay && $0.end > now && $0.start < midnight }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
            .prefix(limit)
            .map { $0 }
    }

    /// "15:00 – 17:00", or just "23:00" when the event ends on a later day.
    public static func timeText(_ e: EventSummary, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        if calendar.isDate(e.start, inSameDayAs: e.end) {
            return "\(f.string(from: e.start)) – \(f.string(from: e.end))"
        }
        return f.string(from: e.start)
    }
}
