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
                                red: Double(rgb[0]), green: Double(rgb[safe: 1] ?? rgb[0]), blue: Double(rgb[safe: 2] ?? rgb[0]))
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
