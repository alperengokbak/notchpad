import Foundation

/// A reminder being added or edited in the panel's editor.
public struct ReminderDraft: Equatable, Sendable {
    /// Nil for a new reminder.
    public var id: String?
    public var title: String
    public var listID: String
    public var hasDue: Bool
    public var due: Date
    /// False = date only.
    public var hasTime: Bool

    public init(id: String?, title: String, listID: String, hasDue: Bool, due: Date, hasTime: Bool) {
        self.id = id; self.title = title; self.listID = listID
        self.hasDue = hasDue; self.due = due; self.hasTime = hasTime
    }

    /// Empty title, due today (date only) in the given list. The time part is the next full hour,
    /// ready if he ticks Time, except after 23:00, where that hour would already be tomorrow.
    public static func new(listID: String, now: Date, calendar: Calendar) -> ReminderDraft {
        let next = EventDraft.nextHour(after: now, calendar: calendar)
        let due = calendar.isDate(next, inSameDayAs: now) ? next : now
        return ReminderDraft(id: nil, title: "", listID: listID, hasDue: true, due: due, hasTime: false)
    }

    public init(editing r: ReminderSummary, now: Date, calendar: Calendar) {
        self.init(id: r.id, title: r.title, listID: r.listID, hasDue: r.due != nil,
                  due: r.due ?? EventDraft.nextHour(after: now, calendar: calendar), hasTime: r.dueHasTime)
    }

    public var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var canSave: Bool { !trimmedTitle.isEmpty }

    /// What EventKit stores as the due date: no hour/minute for a date-only reminder.
    public func dueComponents(calendar: Calendar) -> DateComponents? {
        guard hasDue else { return nil }
        var parts: Set<Calendar.Component> = [.year, .month, .day]
        if hasTime { parts.formUnion([.hour, .minute]) }
        var c = calendar.dateComponents(parts, from: due)
        c.calendar = calendar
        c.timeZone = calendar.timeZone
        return c
    }
}

/// A calendar event being added or edited in the panel's editor.
public struct EventDraft: Equatable, Sendable {
    /// Nil for a new event.
    public var id: String?
    /// Start of the occurrence being edited, so a repeating event changes only that one.
    public var occurrenceStart: Date?
    public var title: String
    public var calendarID: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool

    public init(id: String?, occurrenceStart: Date?, title: String, calendarID: String,
                start: Date, end: Date, isAllDay: Bool) {
        self.id = id; self.occurrenceStart = occurrenceStart; self.title = title; self.calendarID = calendarID
        self.start = start; self.end = end; self.isAllDay = isAllDay
    }

    /// Next full hour, one hour long.
    public static func new(calendarID: String, now: Date, calendar: Calendar) -> EventDraft {
        let start = nextHour(after: now, calendar: calendar)
        return EventDraft(id: nil, occurrenceStart: nil, title: "", calendarID: calendarID,
                          start: start, end: start.addingTimeInterval(3600), isAllDay: false)
    }

    public init(editing e: EventSummary) {
        self.init(id: e.id, occurrenceStart: e.start, title: e.title, calendarID: e.calendarID,
                  start: e.start, end: e.end, isAllDay: e.isAllDay)
    }

    /// The first full hour after `now` (15:00 at 14:20; 15:00 at 14:00 too, never "now").
    public static func nextHour(after now: Date, calendar: Calendar) -> Date {
        let hour = calendar.dateInterval(of: .hour, for: now)!.start
        return calendar.date(byAdding: .hour, value: 1, to: hour)!
    }

    public var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// A title, and for timed events an end after the start. All-day events may end on the start day.
    public var canSave: Bool {
        !trimmedTitle.isEmpty && (isAllDay || end > start)
    }

    /// Moves the start and keeps the length.
    public mutating func moveStart(to newStart: Date) {
        let length = end.timeIntervalSince(start)
        start = newStart
        end = newStart.addingTimeInterval(max(length, 0))
    }

    /// Whole days for an all-day event: start of the first day to the start of the day after the last.
    public func allDayRange(calendar: Calendar) -> (start: Date, end: Date) {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: max(end, start))
        return (first, calendar.date(byAdding: .day, value: 1, to: last)!)
    }
}

/// Focus lengths the − / + buttons step through.
public enum FocusLength {
    public static let range = 5...180
    public static let stepMinutes = 5

    /// One step up (+1) or down (−1), on the 5-minute grid, kept within 5…180.
    public static func step(_ minutes: Int, by direction: Int) -> Int {
        let snapped: Int
        if minutes % stepMinutes == 0 {
            snapped = minutes + direction * stepMinutes
        } else {
            // Off the grid: go to the nearest grid value in the chosen direction.
            snapped = direction > 0 ? (minutes / stepMinutes + 1) * stepMinutes : (minutes / stepMinutes) * stepMinutes
        }
        return clamp(snapped)
    }

    /// A typed length: "45", "45 min", "45m", "1:30", "1h", "1h30", "2h 30m". Kept within 5…180.
    /// Nil when it can't be read or is zero.
    public static func parse(_ text: String) -> Int? {
        let t = text.lowercased().filter { !$0.isWhitespace }
        guard !t.isEmpty else { return nil }
        var minutes: Int?
        if let m = t.wholeMatch(of: /(\d{1,2}):(\d{2})/) {
            let h = Int(m.1)!, mm = Int(m.2)!
            minutes = mm < 60 ? h * 60 + mm : nil
        } else if let m = t.wholeMatch(of: /(\d{1,2})h(?:(\d{1,2})(?:m|min|mins)?)?/) {
            let mm = m.2.map { Int($0)! } ?? 0
            minutes = mm < 60 ? Int(m.1)! * 60 + mm : nil
        } else if let m = t.wholeMatch(of: /(\d{1,4})(?:m|min|mins|minutes)?/) {
            minutes = Int(m.1)!
        }
        guard let minutes, minutes > 0 else { return nil }
        return clamp(minutes)
    }

    public static func clamp(_ minutes: Int) -> Int {
        min(max(minutes, range.lowerBound), range.upperBound)
    }
}
