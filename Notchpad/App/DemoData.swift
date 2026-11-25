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

    /// Gallery previews never touch the camera.
    static let previewCamera = CameraMirror()

    /// A drawn stand-in for the camera picture (a soft room with a person shape), never a real photo.
    static func mirrorImage() -> NSImage {
        NSImage(size: NSSize(width: 480, height: 320), flipped: false) { rect in
            NSGradient(colors: [NSColor(red: 0.32, green: 0.36, blue: 0.45, alpha: 1),
                                NSColor(red: 0.62, green: 0.55, blue: 0.5, alpha: 1)])?.draw(in: rect, angle: 70)
            NSColor(red: 0.9, green: 0.78, blue: 0.68, alpha: 0.9).setFill()
            NSBezierPath(ovalIn: NSRect(x: 195, y: 150, width: 90, height: 110)).fill()
            NSColor(red: 0.2, green: 0.24, blue: 0.33, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 140, y: -40, width: 200, height: 190), xRadius: 90, yRadius: 90).fill()
            return true
        }
    }

    /// Clipboard previews: made-up copies.
    static let previewClipboard: ClipboardMonitor = {
        let m = ClipboardMonitor(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("notchpad-preview/clipboard.json"), saves: false)
        m.setForDemo(clips(now: Date()))
        return m
    }()

    static func clips(now: Date) -> [ClipEntry] {
        let picture = cover().tiffRepresentation.flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) }
        return [
            ClipEntry(text: "Meeting moved to room B12 at 3 pm", date: now.addingTimeInterval(-40)),
            ClipEntry(text: "https://github.com/alperengokbak/notchpad", date: now.addingTimeInterval(-8 * 60)),
            ClipEntry(imageData: picture, date: now.addingTimeInterval(-50 * 60)),
            ClipEntry(text: "Order number 48213", date: now.addingTimeInterval(-3 * 3600)),
            ClipEntry(text: "ssh lab-server.local", date: now.addingTimeInterval(-26 * 3600)),
        ]
    }

    /// Recent files previews: empty made-up files in the demo folder.
    static func recentFiles(now: Date) -> [RecentFile] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("notchpad-demo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let names: [(String, TimeInterval)] = [("Lab report.docx", 5 * 60), ("Network diagram.png", 2 * 3600),
                                               ("Budget.xlsx", 26 * 3600), ("Lecture notes.pdf", 3 * 86400)]
        return names.map { name, ago in
            let url = dir.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: Data("demo".utf8)) }
            return RecentFile(url: url, date: now.addingTimeInterval(-ago))
        }
    }

    /// Focus history previews: 50 min today, 3 h 20 min this week.
    static func focusLog(now: Date) -> FocusLog {
        var log = FocusLog()
        let cal = Calendar.current
        log.record(minutes: 50, at: now, calendar: cal)
        if let start = cal.dateInterval(of: .weekOfYear, for: now)?.start, !cal.isDate(start, inSameDayAs: now) {
            log.record(minutes: 150, at: start.addingTimeInterval(10 * 3600), calendar: cal)
        } else {
            log.record(minutes: 150, at: now, calendar: cal)
        }
        return log
    }

    static let note = "Pick up the parcel from the post office\nBring student ID\nRoom B12 at 3 pm"

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
        inputs.mirrorDemoImage = mirrorImage()
        inputs.recentFiles = recentFiles(now: now)
        inputs.clockRows = ["Europe/London", "Europe/Istanbul", "America/New_York", "Asia/Tokyo"]
            .compactMap { WorldClock.row(zoneID: $0, now: now, local: .current) }
        inputs.focusHistory = "Today 50 min · Week 3 h 20 min"
        inputs.quickNote = note
        return inputs
    }
}
