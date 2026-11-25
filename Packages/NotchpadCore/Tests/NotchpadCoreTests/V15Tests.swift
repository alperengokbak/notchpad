import Foundation
import Testing
@testable import NotchpadCore

private let london = TimeZone(identifier: "Europe/London")!

private func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

// MARK: World clock

@Test func cityNamesFromZoneIDs() {
    #expect(WorldClock.cityName("Europe/Istanbul") == "Istanbul")
    #expect(WorldClock.cityName("America/New_York") == "New York")
    #expect(WorldClock.cityName("America/Argentina/Buenos_Aires") == "Buenos Aires")
    #expect(WorldClock.cityName("UTC") == "UTC")
}

@Test func clockRowTimeOffsetAndDay() {
    // 25 Nov 2026, 22:30 UTC = 22:30 in London (winter), 01:30 next day in Istanbul (+3).
    let now = utc(2026, 11, 25, 22, 30)
    let ist = WorldClock.row(zoneID: "Europe/Istanbul", now: now, local: london)
    #expect(ist?.time == "01:30")
    #expect(ist?.offset == "+3 h")
    #expect(ist?.day == "Tomorrow")
    let ny = WorldClock.row(zoneID: "America/New_York", now: now, local: london)
    #expect(ny?.time == "17:30" && ny?.offset == "−5 h" && ny?.day == nil)
    let delhi = WorldClock.row(zoneID: "Asia/Kolkata", now: now, local: london)
    #expect(delhi?.offset == "+5 h 30 min")
    let home = WorldClock.row(zoneID: "Europe/London", now: now, local: london)
    #expect(home?.offset == "Same time")
    #expect(WorldClock.row(zoneID: "Not/AZone", now: now, local: london) == nil)
}

@Test func clockZonesByRegion() {
    let groups = WorldClock.zonesByRegion()
    #expect(groups.map(\.region).contains("Europe"))
    #expect(groups.first { $0.region == "Europe" }?.zones.contains("Europe/Istanbul") == true)
    #expect(!groups.map(\.region).contains("Etc"))
}

@Test func clockZonesPreference() {
    let suite = "notchpad-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    #expect(prefs.worldClockZones == [TimeZone.current.identifier])
    prefs.worldClockZones = ["Europe/London", "Europe/Istanbul"]
    #expect(Preferences(defaults: defaults).worldClockZones == ["Europe/London", "Europe/Istanbul"])
    #expect(!prefs.screenshotsToShelf) // off unless turned on
}

// MARK: Focus history

@Test func focusHistoryTodayAndWeek() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = london
    cal.firstWeekday = 2 // Monday
    var log = FocusLog()
    // Monday 23 Nov, Tuesday 24 Nov, Wednesday 25 Nov 2026; Sunday 22 Nov is last week.
    log.record(minutes: 50, at: utc(2026, 11, 22, 10), calendar: cal)
    log.record(minutes: 25, at: utc(2026, 11, 23, 10), calendar: cal)
    log.record(minutes: 45, at: utc(2026, 11, 24, 10), calendar: cal)
    log.record(minutes: 30, at: utc(2026, 11, 25, 9), calendar: cal)
    log.record(minutes: 20, at: utc(2026, 11, 25, 15), calendar: cal)
    let now = utc(2026, 11, 25, 18)
    #expect(log.minutesToday(now: now, calendar: cal) == 50)
    #expect(log.minutesThisWeek(now: now, calendar: cal) == 120)
    #expect(FocusLog.text(50) == "50 min")
    #expect(FocusLog.text(200) == "3 h 20 min")
    #expect(FocusLog.text(120) == "2 h")
}

@Test func focusHistoryForgetsOldDaysAndIgnoresTinyStops() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = london
    var log = FocusLog()
    log.record(minutes: 30, at: utc(2026, 8, 1, 10), calendar: cal)
    log.record(minutes: 0, at: utc(2026, 11, 25, 10), calendar: cal)   // under a minute: not counted
    log.record(minutes: 25, at: utc(2026, 11, 25, 11), calendar: cal)
    #expect(log.days.count == 1)                                          // August entry dropped (over 60 days)
    #expect(FocusTimer.focusedMinutes(planned: 25 * 60, remaining: 10 * 60 + 20) == 14)
}
