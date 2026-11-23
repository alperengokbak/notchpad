import Foundation
import NotchpadCore

/// Made-up data for `--demo` screenshots and gallery previews. Never his real reminders, events or files.
@MainActor
enum DemoData {
    static func reminders(now: Date) -> [ReminderSummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: today)! }
        func item(_ title: String, _ due: Date?, list: String = "Personal", order: Int = 0) -> ReminderSummary {
            ReminderSummary(id: title, title: title, listID: list, listTitle: list, listOrder: order, due: due, dueHasTime: false)
        }
        return [
            item("Renew library books", day(-1)),
            item("Submit lab report", day(0)),
            item("Call the dentist", day(1)),
            item("Pay phone bill", day(3)),
            item("Plan weekend trip", nil),
            item("Milk", nil, list: "Shopping", order: 1),
        ]
    }

    static func events(now: Date) -> [EventSummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func at(_ hour: Int) -> Date { cal.date(bySettingHour: hour, minute: 0, second: 0, of: today)! }
        return [
            EventSummary(id: "demo-1", title: "Networking lecture", start: at(15), end: at(17),
                         isAllDay: false, red: 0.04, green: 0.52, blue: 1),
            EventSummary(id: "demo-2", title: "Gym", start: at(18), end: at(19),
                         isAllDay: false, red: 0.2, green: 0.78, blue: 0.35),
            EventSummary(id: "demo-3", title: "Call home", start: at(21), end: at(22),
                         isAllDay: false, red: 1, green: 0.58, blue: 0),
        ]
    }

    static func focus(now: Date) -> FocusTimer {
        var timer = FocusTimer()
        timer.start(.focus, seconds: 18 * 60 + 42, now: now)
        return timer
    }

    static let tailscale = TailscaleStatus(state: .connected, devices: [
        TailscaleDevice(id: "d1", name: "macbook", ipv4: "100.64.0.1", isOnline: true, isSelf: true),
        TailscaleDevice(id: "d2", name: "iphone", ipv4: "100.64.0.2", isOnline: true, isSelf: false),
        TailscaleDevice(id: "d3", name: "lab-server", ipv4: "100.64.0.3", isOnline: false, isSelf: false),
    ])

    /// Two small placeholder files in a temp folder.
    static func files() -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("notchpad-demo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let files = ["Lecture notes.pdf", "Lab screenshot.png"].map { dir.appendingPathComponent($0) }
        for f in files where !FileManager.default.fileExists(atPath: f.path) {
            FileManager.default.createFile(atPath: f.path, contents: Data("demo".utf8))
        }
        return files
    }

    /// A shelf of its own for previews, so the real shelf is never touched.
    static let previewShelf: ShelfStore = {
        let store = ShelfStore(storageURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("notchpad-preview/shelf.json"))
        store.clear()
        store.add(files())
        return store
    }()

    static func inputs(now: Date) -> WidgetInputs {
        WidgetInputs(music: .notRunning, artwork: nil, now: now,
                     reminders: reminders(now: now), remindersAccess: .granted, pendingReminderIDs: [],
                     events: events(now: now), calendarAccess: .granted,
                     focus: focus(now: now), lastFocusMinutes: 25,
                     tailscale: tailscale, tailscaleBusy: false, tailscaleMessage: nil, copiedDeviceID: nil,
                     shelf: previewShelf, shelfDropTargeted: false, actions: .none)
    }
}
