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

// MARK: Screens without a notch

private let mbp = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), isBuiltIn: true, isMain: true,
                             metrics: ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
                                                    leftAuxWidth: 771.5, rightAuxWidth: 771.5, safeTop: 32),
                             menuBarHeight: 32)
private let external = ScreenInfo(frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440), isBuiltIn: false, isMain: false,
                                  metrics: ScreenMetrics(frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440),
                                                         leftAuxWidth: nil, rightAuxWidth: nil, safeTop: 0),
                                  menuBarHeight: 25)

@Test func notchedMacBookKeepsTheRealNotch() {
    let pick = NotchGeometry.pickScreen([mbp, external], preferMain: false)
    #expect(pick?.index == 0)
    #expect(pick?.notch == CGRect(x: 771.5, y: 1085, width: 185, height: 32))
    #expect(pick?.isVirtual == false)
}

@Test func externalMainDisplayGetsAVirtualNotchWhenAsked() {
    var main = external; main.isMain = true
    var laptop = mbp; laptop.isMain = false
    let pick = NotchGeometry.pickScreen([laptop, main], preferMain: true)
    #expect(pick?.index == 1)
    #expect(pick?.isVirtual == true)
    #expect(pick?.notch == CGRect(x: 1728 + 2560 / 2 - 92.5, y: 1440 - 25, width: 185, height: 25))
    // Without the switch, the built-in notch still wins.
    #expect(NotchGeometry.pickScreen([laptop, main], preferMain: false)?.index == 0)
}

@Test func macWithoutNotchUsesTheMainScreen() {
    var imac = external; imac.isMain = true; imac.menuBarHeight = 20
    let pick = NotchGeometry.pickScreen([imac], preferMain: false)
    #expect(pick?.isVirtual == true)
    #expect(pick?.notch.height == 24) // never thinner than 24 pt, so it's easy to hit
    #expect(NotchGeometry.pickScreen([], preferMain: false) == nil)
}

@Test func chosenMonitorGetsTheNotchWhileConnected() {
    // His setup: MacBook is the main display, the monitor sits beside it without a menu bar.
    var monitor = external; monitor.key = "4c2d-7148-1"; monitor.name = "Studio Display 27"; monitor.menuBarHeight = 24
    var laptop = mbp; laptop.key = "610-a050-0"
    let pick = NotchGeometry.pickScreen([laptop, monitor], chosen: "4c2d-7148-1", preferMain: false)
    #expect(pick?.index == 1)
    #expect(pick?.isVirtual == true)
    #expect(pick?.notch == CGRect(x: 1728 + 2560 / 2 - 92.5, y: 1440 - 24, width: 185, height: 24))
    // Choosing the MacBook gives the real notch.
    #expect(NotchGeometry.pickScreen([laptop, monitor], chosen: "610-a050-0", preferMain: false)?.isVirtual == false)
    // Monitor unplugged: back to the notch.
    #expect(NotchGeometry.pickScreen([laptop], chosen: "4c2d-7148-1", preferMain: false)?.index == 0)
    #expect(NotchGeometry.pickScreen([laptop, monitor], chosen: nil, preferMain: false)?.index == 0)
}

@Test func followMouseUsesTheScreenUnderThePointer() {
    var monitor = external; monitor.key = "4c2d-7148-1"; monitor.menuBarHeight = 24
    let screens = [mbp, monitor]
    let onMonitor = NotchGeometry.pickScreen(screens, chosen: NotchGeometry.followMouse, preferMain: false,
                                             pointer: CGPoint(x: 2000, y: 700))
    #expect(onMonitor?.index == 1)
    #expect(onMonitor?.isVirtual == true)
    let onMacBook = NotchGeometry.pickScreen(screens, chosen: NotchGeometry.followMouse, preferMain: false,
                                             pointer: CGPoint(x: 500, y: 500))
    #expect(onMacBook?.index == 0)
    #expect(onMacBook?.isVirtual == false)
    // Pointer unknown or off every screen: the usual choice (the notch).
    #expect(NotchGeometry.pickScreen(screens, chosen: NotchGeometry.followMouse, preferMain: false)?.index == 0)
    #expect(NotchGeometry.pickScreen(screens, chosen: NotchGeometry.followMouse, preferMain: false,
                                     pointer: CGPoint(x: -5000, y: 0))?.index == 0)
}

@Test func screenMenuTitles() {
    var monitor = external; monitor.name = "Studio Display 27"
    #expect(mbp.menuTitle == "MacBook notch")
    #expect(monitor.menuTitle == "Studio Display 27")
    monitor.name = ""
    #expect(monitor.menuTitle == "Display")
}

// MARK: Quick note

@Test func quickNotePreferenceAndCatalog() {
    let suite = "notchpad-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    #expect(prefs.quickNote == "")
    #expect(!prefs.preferMainDisplay)
    prefs.quickNote = "Call the dentist 023 9200 0000"
    #expect(Preferences(defaults: defaults).quickNote == "Call the dentist 023 9200 0000")
    #expect(WidgetKind.quickNote.title == "Quick note")
    #expect(WidgetKind.quickNote.sizes == [.small, .medium, .wide])
}
