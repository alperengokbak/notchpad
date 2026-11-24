import AppKit
import NotchpadCore

/// Made-up data for `--demo` screenshots and gallery previews. Never real reminders, events or files.
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
            item("Bread", nil, list: "Shopping", order: 1),
            item("Coffee beans", nil, list: "Shopping", order: 1),
        ]
    }

    static func events(now: Date) -> [EventSummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func at(_ hour: Int) -> Date { cal.date(bySettingHour: hour, minute: 0, second: 0, of: today)! }
        return [
            EventSummary(id: "demo-1", title: "Networking lecture", start: at(15), end: at(17),
                         isAllDay: false, red: 0.04, green: 0.52, blue: 1, calendarID: "University"),
            EventSummary(id: "demo-2", title: "Gym", start: at(18), end: at(19),
                         isAllDay: false, red: 0.2, green: 0.78, blue: 0.35, calendarID: "Home"),
            EventSummary(id: "demo-3", title: "Call home", start: at(21), end: at(22),
                         isAllDay: false, red: 1, green: 0.58, blue: 0, calendarID: "Home"),
        ]
    }

    static func focus(now: Date) -> FocusTimer {
        var timer = FocusTimer()
        timer.start(.focus, seconds: 18 * 60 + 42, now: now)
        return timer
    }

    /// A made-up song for `--demo-spotify`.
    static func song(now: Date) -> NowPlaying {
        NowPlaying(title: "Late Night Drive", artist: "Demo Artist", duration: 214, position: 83,
                   isPlaying: true, positionDate: now)
    }

    /// Plain gradient cover art, drawn here so no real album art is used.
    static func cover() -> NSImage {
        NSImage(size: NSSize(width: 300, height: 300), flipped: false) { rect in
            NSGradient(colors: [NSColor(red: 0.98, green: 0.45, blue: 0.35, alpha: 1),
                                NSColor(red: 0.55, green: 0.25, blue: 0.75, alpha: 1)])?.draw(in: rect, angle: -45)
            NSColor(white: 1, alpha: 0.18).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 70, dy: 70)).fill()
            return true
        }
    }

    /// A made-up landscape for `--demo-background` screenshots (no real photo).
    static func background() -> NSImage {
        NSImage(size: NSSize(width: 1360, height: 400), flipped: false) { rect in
            NSGradient(colors: [NSColor(red: 0.13, green: 0.36, blue: 0.62, alpha: 1),
                                NSColor(red: 0.95, green: 0.55, blue: 0.35, alpha: 1)])?.draw(in: rect, angle: 90)
            NSColor(red: 0.1, green: 0.25, blue: 0.2, alpha: 1).setFill()
            let hills = NSBezierPath()
            hills.move(to: .zero)
            hills.curve(to: NSPoint(x: rect.width, y: 90), controlPoint1: NSPoint(x: 400, y: 260),
                        controlPoint2: NSPoint(x: 900, y: -40))
            hills.line(to: NSPoint(x: rect.width, y: 0))
            hills.close()
            hills.fill()
            return true
        }
    }

    /// Shortcuts widget: built-in Mac apps, a made-up shortcut and two empty demo folders.
    static func launcherItems() -> [LauncherItem] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("notchpad-demo")
        let drive = dir.appendingPathComponent("My Drive"), work = dir.appendingPathComponent("Coursework")
        for d in [drive, work] { try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
        return [
            LauncherItem(kind: .app, target: "/Applications/Safari.app", title: "Safari"),
            LauncherItem(kind: .app, target: "/System/Applications/Notes.app", title: "Notes"),
            LauncherItem(kind: .app, target: "/System/Applications/Calendar.app", title: "Calendar"),
            LauncherItem(kind: .shortcut, target: "Morning routine", title: "Morning routine"),
            LauncherItem(kind: .folder, target: drive.path, title: "My Drive"),
            LauncherItem(kind: .folder, target: work.path, title: "Coursework"),
        ]
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
        var inputs = WidgetInputs(music: .notRunning, musicAppName: "Music", artwork: nil, now: now,
                     reminders: reminders(now: now), remindersAccess: .granted, pendingReminderIDs: [],
                     events: events(now: now), calendarAccess: .granted,
                     focus: focus(now: now), lastFocusMinutes: 25,
                     tailscale: tailscale, tailscaleBusy: false, tailscaleMessage: nil, copiedDeviceID: nil,
                     shelf: previewShelf, shelfDropTargeted: false, actions: .none)
        inputs.launcherItems = launcherItems()
        return inputs
    }
}
