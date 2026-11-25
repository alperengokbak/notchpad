import EventKit
import Foundation
import NotchpadCore

/// Debug-only helpers: `--editor <kind>` opens the editor at launch (use with `--demo` for screenshots),
/// `--selftest-write` adds, changes and deletes one reminder and one event of its own, then quits.
extension AppModel {
    func openEditorForDebug(_ kind: String) {
        switch kind {
        case "new-reminder":
            newReminder()
            // `--editor-title <text>`: a title already typed in (launch video frames).
            if let title = DebugTools.argument(after: "--editor-title"), case .reminder(var d)? = editor {
                d.title = title
                editor = .reminder(d)
            }
        case "edit-reminder": if let r = reminders.first { editReminder(r.id) }
        case "new-event": newEvent()
        case "edit-event": if let e = events.first { editEvent(e) }
        case "readonly-event":
            if var e = events.first { e.isEditable = false; editEvent(e) }
        case "focus-length": beginFocusMinutesTyping()
        case "quick-note": beginNoteEditing()
        default: DebugTools.log("unknown editor kind: \(kind)")
        }
    }

    /// Round trip against the real stores, touching only items it created itself (unique title).
    /// Prints one line per step; "selftest: PASS" at the end when every step worked.
    func runWriteSelfTest() async {
        let tag = "Notchpad self-test \(UUID().uuidString.prefix(6))"
        var ok = true
        func step(_ name: String, _ passed: Bool) {
            print("selftest: \(name) \(passed ? "ok" : "FAILED")")
            fflush(stdout)
            ok = ok && passed
        }
        let cal = Calendar.current

        // Reminders
        _ = await remindersReader.requestAccess()
        step("reminders access", remindersReader.access == .granted)
        if remindersReader.access == .granted, let list = remindersReader.defaultListID {
            var draft = ReminderDraft.new(listID: list, now: Date(), calendar: cal)
            draft.title = tag
            draft.hasDue = false
            step("reminder add", remindersReader.save(draft))
            var found = await remindersReader.fetchIncomplete().first { $0.title == tag }
            step("reminder found", found != nil)
            if let r = found {
                var edit = ReminderDraft(editing: r, now: Date(), calendar: cal)
                edit.title = tag + " edited"
                step("reminder edit", remindersReader.save(edit))
                found = await remindersReader.fetchIncomplete().first { $0.id == r.id }
                step("reminder title changed", found?.title == tag + " edited")
                step("reminder delete", remindersReader.delete(r.id))
                let gone = await remindersReader.fetchIncomplete().contains { $0.id == r.id }
                step("reminder gone", !gone)
            }
        }

        // Calendar: 30 days ahead at 03:00, so no alert can fire before it's deleted.
        _ = await calendarReader.requestAccess()
        step("calendar access", calendarReader.access == .granted)
        if calendarReader.access == .granted, let calID = calendarReader.defaultCalendarID {
            let day = cal.date(byAdding: .day, value: 30, to: cal.startOfDay(for: Date()))!
            let start = cal.date(bySettingHour: 3, minute: 0, second: 0, of: day)!
            var draft = EventDraft.new(calendarID: calID, now: Date(), calendar: cal)
            draft.title = tag
            draft.moveStart(to: start)
            step("event add", calendarReader.save(draft))
            let store = calendarReader.store
            func find(_ title: String) -> EKEvent? {
                store.events(matching: store.predicateForEvents(withStart: start.addingTimeInterval(-60),
                                                                end: start.addingTimeInterval(7200), calendars: nil))
                    .first { $0.title == title }
            }
            if let e = find(tag), let id = e.eventIdentifier {
                step("event found", true)
                var edit = draft
                edit.id = id
                edit.occurrenceStart = e.startDate
                edit.title = tag + " edited"
                step("event edit", calendarReader.save(edit))
                step("event title changed", find(tag + " edited") != nil)
                step("event delete", calendarReader.delete(id, occurrence: e.startDate))
                step("event gone", find(tag + " edited") == nil)
            } else {
                step("event found", false)
            }
        }
        print("selftest: \(ok ? "PASS" : "FAIL")")
        fflush(stdout)
    }
}
