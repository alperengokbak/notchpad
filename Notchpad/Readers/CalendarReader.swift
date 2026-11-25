import AppKit
import EventKit
import NotchpadCore

/// Reads today's events from every calendar the Calendar app shows.
@MainActor
final class CalendarReader {
    let store = EKEventStore()

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .unknown
        default: return .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        guard access == .unknown else { return access }
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        return granted ? .granted : .denied
    }

    func todaysEvents(now: Date, calendar: Calendar = .current) -> [EventSummary] {
        guard access == .granted else { return [] }
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { e in
            let c = e.calendar.cgColor.flatMap { $0.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) }
            let rgb = c?.components ?? [1, 0.62, 0.04]
            return EventSummary(id: e.eventIdentifier ?? UUID().uuidString, title: e.title ?? "",
                                start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
                                red: Double(rgb[0]), green: Double(rgb[safe: 1] ?? rgb[0]), blue: Double(rgb[safe: 2] ?? rgb[0]),
                                calendarID: e.calendar.calendarIdentifier,
                                isEditable: e.calendar.allowsContentModifications,
                                meetingURL: MeetingLink.find(in: [e.url?.absoluteString, e.location, e.notes]))
        }
    }

    /// Calendars that can take new or changed events.
    func writableCalendars() -> [NamedList] {
        store.calendars(for: .event).filter(\.allowsContentModifications)
            .map { NamedList(id: $0.calendarIdentifier, title: $0.title) }
    }

    var defaultCalendarID: String? { store.defaultCalendarForNewEvents?.calendarIdentifier }

    /// The event, or for a repeating event the one occurrence that starts at `occurrence`.
    private func event(_ id: String, occurrence: Date?) -> EKEvent? {
        if let occurrence {
            let predicate = store.predicateForEvents(withStart: occurrence.addingTimeInterval(-1),
                                                     end: occurrence.addingTimeInterval(86_400), calendars: nil)
            if let match = store.events(matching: predicate)
                .first(where: { $0.eventIdentifier == id && $0.startDate == occurrence }) {
                return match
            }
        }
        return store.event(withIdentifier: id)
    }

    /// Adds a new event or changes an existing one (only this occurrence of a repeating event).
    func save(_ draft: EventDraft, calendar: Calendar = .current) -> Bool {
        guard access == .granted, draft.canSave else { return false }
        let event = draft.id.flatMap { self.event($0, occurrence: draft.occurrenceStart) } ?? EKEvent(eventStore: store)
        if let existing = event.calendar, !existing.allowsContentModifications { return false }
        event.title = draft.trimmedTitle
        if let target = store.calendar(withIdentifier: draft.calendarID), target.allowsContentModifications {
            event.calendar = target
        } else if event.calendar == nil {
            event.calendar = store.defaultCalendarForNewEvents
        }
        event.isAllDay = draft.isAllDay
        if draft.isAllDay {
            let days = draft.allDayRange(calendar: calendar)
            event.startDate = days.start
            event.endDate = days.end.addingTimeInterval(-1)
        } else {
            event.startDate = draft.start
            event.endDate = draft.end
        }
        do {
            try store.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            DebugTools.log("event save failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Deletes an event (only this occurrence of a repeating event).
    func delete(_ id: String, occurrence: Date?) -> Bool {
        guard let event = event(id, occurrence: occurrence), event.calendar.allowsContentModifications else { return false }
        do {
            try store.remove(event, span: .thisEvent, commit: true)
            return true
        } catch {
            DebugTools.log("event delete failed: \(error.localizedDescription)")
            return false
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
