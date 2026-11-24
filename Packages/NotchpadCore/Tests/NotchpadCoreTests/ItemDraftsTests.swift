import Foundation
import Testing
@testable import NotchpadCore

private let london: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/London")!
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    london.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

// MARK: Reminders

@Test func reminderDraftNeedsTitle() {
    var d = ReminderDraft.new(listID: "L", now: date(2026, 11, 24, 14, 20), calendar: london)
    #expect(!d.canSave)
    d.title = "   "
    #expect(!d.canSave)
    d.title = " Buy milk "
    #expect(d.canSave)
    #expect(d.trimmedTitle == "Buy milk")
}

@Test func reminderDueComponentsNone() {
    var d = ReminderDraft.new(listID: "L", now: date(2026, 11, 24, 14, 20), calendar: london)
    d.hasDue = false
    #expect(d.dueComponents(calendar: london) == nil)
}

@Test func reminderDueComponentsDateOnly() {
    var d = ReminderDraft.new(listID: "L", now: date(2026, 11, 24, 14, 20), calendar: london)
    d.hasDue = true
    d.hasTime = false
    d.due = date(2026, 11, 25, 9, 30)
    let c = d.dueComponents(calendar: london)
    #expect(c?.year == 2026)
    #expect(c?.month == 11)
    #expect(c?.day == 25)
    #expect(c?.hour == nil)
    #expect(c?.minute == nil)
}

@Test func reminderDueComponentsWithTime() {
    var d = ReminderDraft.new(listID: "L", now: date(2026, 11, 24, 14, 20), calendar: london)
    d.hasDue = true
    d.hasTime = true
    d.due = date(2026, 11, 25, 9, 30)
    let c = d.dueComponents(calendar: london)
    #expect(c?.day == 25)
    #expect(c?.hour == 9)
    #expect(c?.minute == 30)
}

@Test func reminderDraftFromSummaryKeepsFields() {
    let r = ReminderSummary(id: "r1", title: "Pay bill", listID: "L2", listTitle: "Bills", listOrder: 1,
                            due: date(2026, 11, 26, 18, 0), dueHasTime: true)
    let d = ReminderDraft(editing: r, now: date(2026, 11, 24), calendar: london)
    #expect(d.id == "r1" && d.title == "Pay bill" && d.listID == "L2")
    #expect(d.hasDue && d.hasTime && d.due == date(2026, 11, 26, 18, 0))
    let undated = ReminderSummary(id: "r2", title: "Idea", listID: "L", listTitle: "L", listOrder: 0, due: nil, dueHasTime: false)
    #expect(!ReminderDraft(editing: undated, now: date(2026, 11, 24), calendar: london).hasDue)
}

// MARK: Events

@Test func eventDraftDefaultsToNextHour() {
    let d = EventDraft.new(calendarID: "C", now: date(2026, 11, 24, 14, 20), calendar: london)
    #expect(d.start == date(2026, 11, 24, 15, 0))
    #expect(d.end == date(2026, 11, 24, 16, 0))
    #expect(!d.isAllDay && d.id == nil)
}

@Test func eventDraftMovingStartKeepsLength() {
    var d = EventDraft.new(calendarID: "C", now: date(2026, 11, 24, 14, 20), calendar: london)
    d.end = date(2026, 11, 24, 17, 30) // 2.5 h
    d.moveStart(to: date(2026, 11, 25, 10, 0))
    #expect(d.start == date(2026, 11, 25, 10, 0))
    #expect(d.end == date(2026, 11, 25, 12, 30))
}

@Test func eventDraftEndBeforeStartCannotSave() {
    var d = EventDraft.new(calendarID: "C", now: date(2026, 11, 24, 14, 20), calendar: london)
    d.title = "Lecture"
    #expect(d.canSave)
    d.end = d.start
    #expect(!d.canSave)
    d.end = d.start.addingTimeInterval(-60)
    #expect(!d.canSave)
}

@Test func eventDraftAllDayUsesWholeDays() {
    var d = EventDraft.new(calendarID: "C", now: date(2026, 11, 24, 14, 20), calendar: london)
    d.title = "Holiday"
    d.isAllDay = true
    d.end = d.start // same day is fine for all-day
    #expect(d.canSave)
    let days = d.allDayRange(calendar: london)
    #expect(days.start == date(2026, 11, 24))
    #expect(days.end == date(2026, 11, 25))
}

@Test func eventDraftFromSummaryKeepsOccurrence() {
    let e = EventSummary(id: "e1", title: "Gym", start: date(2026, 11, 24, 18), end: date(2026, 11, 24, 19),
                         isAllDay: false, red: 0, green: 0, blue: 0, calendarID: "C2", isEditable: true)
    let d = EventDraft(editing: e)
    #expect(d.id == "e1" && d.occurrenceStart == date(2026, 11, 24, 18) && d.calendarID == "C2")
    #expect(d.title == "Gym" && d.start == e.start && d.end == e.end)
}

@Test func eventSummaryDefaultsToEditable() {
    let e = EventSummary(id: "e", title: "t", start: Date(), end: Date(), isAllDay: false, red: 0, green: 0, blue: 0)
    #expect(e.isEditable && e.calendarID.isEmpty)
}

// MARK: Focus length

@Test func focusLengthStepsAndClamps() {
    #expect(FocusLength.step(25, by: 1) == 30)
    #expect(FocusLength.step(25, by: -1) == 20)
    #expect(FocusLength.step(5, by: -1) == 5)
    #expect(FocusLength.step(180, by: 1) == 180)
    #expect(FocusLength.step(23, by: 1) == 25) // odd values snap to the 5-minute grid
}

@Test func focusMinutesPreferenceDefault25() {
    let suite = "notchpad-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    #expect(prefs.focusMinutes == 25)
    prefs.focusMinutes = 40
    #expect(Preferences(defaults: defaults).focusMinutes == 40)
    prefs.focusMinutes = 999
    #expect(Preferences(defaults: defaults).focusMinutes == 180)
}

// MARK: Seeking

@Test func seekedClampsAndKeepsPlaying() {
    let t0 = Date(timeIntervalSinceReferenceDate: 500)
    let song = NowPlaying(title: "A", artist: "B", duration: 200, position: 10, isPlaying: true, positionDate: t0)
    let later = t0.addingTimeInterval(30)
    let moved = song.seeked(to: 120, now: later)
    #expect(moved.position(at: later) == 120)
    #expect(moved.isPlaying)
    #expect(song.seeked(to: 500, now: later).position(at: later) == 200)
    #expect(song.seeked(to: -5, now: later).position(at: later) == 0)
}

@Test func seekFractionClamps() {
    #expect(NowPlaying.seekFraction(x: 50, width: 200) == 0.25)
    #expect(NowPlaying.seekFraction(x: -10, width: 200) == 0)
    #expect(NowPlaying.seekFraction(x: 300, width: 200) == 1)
    #expect(NowPlaying.seekFraction(x: 10, width: 0) == 0)
}

@Test func seekSendsSetPlayerPosition() {
    let spy = SpyRunner()
    MusicController(isMusicRunning: { true }, runner: spy).seek(to: 83.46)
    MusicController(source: .spotify, isMusicRunning: { true }, runner: spy).seek(to: 12)
    #expect(spy.calls == ["tell application \"Music\" to set player position to 83.5",
                          "tell application \"Spotify\" to set player position to 12.0"])
}

@Test func seekDroppedWhenNotRunning() {
    let spy = SpyRunner()
    MusicController(isMusicRunning: { false }, runner: spy).seek(to: 10)
    #expect(spy.calls.isEmpty)
}

// MARK: Typing hold

@Test func typingHoldsPanelOpen() {
    var s = PanelStateMachine()
    s.pointer(inside: true, now: 0)
    s.tick(now: 1)
    #expect(s.isOpen)
    s.setTyping(true, now: 1)
    s.pointer(inside: false, now: 1)
    s.tick(now: 5)
    #expect(s.isOpen)
    s.setTyping(false, now: 5)
    s.tick(now: 5.31)
    #expect(!s.isOpen)
}

@Test func typingEndsWhileEditingStaysOpen() {
    var s = PanelStateMachine()
    s.setEditing(true, now: 0)
    s.setTyping(true, now: 0)
    s.pointer(inside: false, now: 0)
    s.setTyping(false, now: 1)
    s.tick(now: 5)
    #expect(s.isOpen)
}

@Test func reminderNewLateEveningStaysToday() {
    let d = ReminderDraft.new(listID: "L", now: date(2026, 11, 24, 23, 40), calendar: london)
    #expect(london.isDate(d.due, inSameDayAs: date(2026, 11, 24)))
    #expect(!d.hasTime)
}

@Test func focusLengthParsesTypedText() {
    #expect(FocusLength.parse("45") == 45)
    #expect(FocusLength.parse(" 45 min ") == 45)
    #expect(FocusLength.parse("45m") == 45)
    #expect(FocusLength.parse("1:30") == 90)
    #expect(FocusLength.parse("1h") == 60)
    #expect(FocusLength.parse("1h30") == 90)
    #expect(FocusLength.parse("2h 30m") == 150)
    #expect(FocusLength.parse("3") == 5)      // below the range: lowest length
    #expect(FocusLength.parse("500") == 180)  // above the range: longest length
}

@Test func focusLengthRejectsNonsense() {
    #expect(FocusLength.parse("") == nil)
    #expect(FocusLength.parse("abc") == nil)
    #expect(FocusLength.parse("0") == nil)
    #expect(FocusLength.parse("1:75") == nil)
    #expect(FocusLength.parse("-20") == nil)
}
