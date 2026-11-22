import EventKit
import NotchpadCore

/// Reads and ticks off reminders. The Reminders app doesn't need to be open.
@MainActor
final class RemindersReader {
    let store: EKEventStore

    init(store: EKEventStore) { self.store = store }

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: .granted
        case .notDetermined: .unknown
        default: .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        guard access == .unknown else { return access }
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        return granted ? .granted : .denied
    }

    /// All incomplete reminders, with their list's position in the Reminders app.
    func fetchIncomplete(calendar: Calendar = .current) async -> [ReminderSummary] {
        guard access == .granted else { return [] }
        let lists = store.calendars(for: .reminder)
        let order = Dictionary(uniqueKeysWithValues: lists.enumerated().map { ($1.calendarIdentifier, $0) })
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let store = self.store
        let raw = await withCheckedContinuation { (cont: CheckedContinuation<[Raw], Never>) in
            Self.fetch(store, predicate) { cont.resume(returning: $0) }
        }
        return raw.map { id, title, listID, listTitle, comps in
            ReminderSummary(id: id, title: title, listID: listID, listTitle: listTitle,
                            listOrder: order[listID] ?? Int.max,
                            due: comps.flatMap { calendar.date(from: $0) },
                            dueHasTime: comps?.hour != nil)
        }
    }

    private typealias Raw = (id: String, title: String, listID: String, listTitle: String, due: DateComponents?)

    /// EventKit calls back on its own queue, so this must not be tied to the main actor.
    private nonisolated static func fetch(_ store: EKEventStore, _ predicate: NSPredicate,
                                          completion: @escaping @Sendable ([Raw]) -> Void) {
        store.fetchReminders(matching: predicate) { reminders in
            completion((reminders ?? []).map {
                ($0.calendarItemIdentifier, $0.title ?? "", $0.calendar.calendarIdentifier, $0.calendar.title, $0.dueDateComponents)
            })
        }
    }

    /// Marks one reminder done, found by its identifier (never by row position).
    func complete(_ id: String) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
    }
}
