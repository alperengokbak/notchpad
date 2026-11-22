import Foundation

/// A reminder, reduced to what the panel shows.
public struct ReminderSummary: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var listID: String
    public var listTitle: String
    /// Position of its list in the Reminders app.
    public var listOrder: Int
    public var due: Date?
    /// False for date-only reminders.
    public var dueHasTime: Bool

    public init(id: String, title: String, listID: String, listTitle: String, listOrder: Int, due: Date?, dueHasTime: Bool) {
        self.id = id; self.title = title; self.listID = listID; self.listTitle = listTitle
        self.listOrder = listOrder; self.due = due; self.dueHasTime = dueHasTime
    }
}

public enum ReminderLogic {
    /// Same rule as the Reminders app: a timed reminder is overdue once its time has passed,
    /// a date-only one from the next day.
    public static func isOverdue(_ r: ReminderSummary, now: Date, calendar: Calendar) -> Bool {
        guard let due = r.due else { return false }
        return r.dueHasTime ? due < now : calendar.startOfDay(for: due) < calendar.startOfDay(for: now)
    }

    /// "Overdue", "Today", "Tomorrow", a weekday within the week ("Tue"), else "3 Dec". Nil when undated.
    public static func dueLabel(_ r: ReminderSummary, now: Date, calendar: Calendar) -> String? {
        guard let due = r.due else { return nil }
        if isOverdue(r, now: now, calendar: calendar) { return "Overdue" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: due)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = days < 7 ? "EEE" : "d MMM"
        return f.string(from: due)
    }

    /// Home column: dated reminders only, overdue first, then by due date.
    public static func homeList(_ items: [ReminderSummary], now: Date, calendar: Calendar, limit: Int = 4) -> [ReminderSummary] {
        items.filter { $0.due != nil }
            .sorted { a, b in
                let ao = isOverdue(a, now: now, calendar: calendar), bo = isOverdue(b, now: now, calendar: calendar)
                if ao != bo { return ao }
                return a.due! < b.due!
            }
            .prefix(limit).map { $0 }
    }

    /// Reminders tab: grouped by list in the app's order; dated by due date, then undated in input order.
    public static func grouped(_ items: [ReminderSummary]) -> [(listTitle: String, items: [ReminderSummary])] {
        let byList = Dictionary(grouping: items.enumerated(), by: { $0.element.listID })
        return byList.values
            .sorted { $0[0].element.listOrder < $1[0].element.listOrder }
            .map { entries in
                let sorted = entries.sorted { a, b in
                    switch (a.element.due, b.element.due) {
                    case let (x?, y?): return x < y
                    case (.some, nil): return true
                    case (nil, .some): return false
                    case (nil, nil): return a.offset < b.offset
                    }
                }
                return (entries[0].element.listTitle, sorted.map(\.element))
            }
    }
}
