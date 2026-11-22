import Foundation
import Testing
@testable import NotchpadCore

private var london: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/London")!
    return c
}

/// 22 Nov 2026 at hh:mm London time (day offset for tomorrow).
private func at(_ h: Int, _ m: Int, day: Int = 22) -> Date {
    london.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))!
}

private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> EventSummary {
    EventSummary(id: title, title: title, start: start, end: end, isAllDay: allDay, red: 1, green: 0.6, blue: 0)
}

private let now = at(14, 5)

@Test func upcomingHandlesEndedOngoingAndPastMidnight() {
    let ended = event("Ended", at(13, 0), at(14, 4))
    let ongoing = event("Ongoing", at(13, 0), at(15, 0))
    let late = event("Late", at(23, 0), at(1, 0, day: 23))
    let result = DayEvents.upcoming([late, ended, ongoing], now: now, calendar: london)
    #expect(result.map(\.title) == ["Ongoing", "Late"])
}

@Test func allDayEventsAreHidden() {
    let allDay = event("Holiday", at(0, 0), at(0, 0, day: 23), allDay: true)
    #expect(DayEvents.upcoming([allDay], now: now, calendar: london).isEmpty)
}

@Test func tomorrowIsHidden() {
    let tomorrow = event("Tomorrow", at(9, 0, day: 23), at(10, 0, day: 23))
    #expect(DayEvents.upcoming([tomorrow], now: now, calendar: london).isEmpty)
}

@Test func limitsToThreeSortedByStart() {
    let events = [18, 15, 20, 16, 19].map { event("E\($0)", at($0, 0), at($0, 30)) }
    #expect(DayEvents.upcoming(events, now: now, calendar: london).map(\.title) == ["E15", "E16", "E18"])
}

@Test func sameStartSortsByTitle() {
    let b = event("B", at(15, 0), at(16, 0))
    let a = event("A", at(15, 0), at(16, 0))
    #expect(DayEvents.upcoming([b, a], now: now, calendar: london).map(\.title) == ["A", "B"])
}

@Test func timeTextRangeAndPastMidnight() {
    #expect(DayEvents.timeText(event("Lab", at(15, 0), at(17, 0)), calendar: london) == "15:00 – 17:00")
    #expect(DayEvents.timeText(event("Late", at(23, 0), at(1, 0, day: 23)), calendar: london) == "23:00")
}
