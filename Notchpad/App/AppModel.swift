import AppKit
import Combine
import EventKit
import NotchpadCore

/// Everything the panel shows. Readers write into it, views read from it.
@MainActor
final class AppModel: ObservableObject {
    @Published var isOpen = false
    /// Size of the real notch, so the closed shape matches it.
    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var events: [EventSummary] = []
    @Published var calendarAccess: CalendarAccess = .unknown
    @Published var music: MusicState = .notRunning {
        didSet { if case .playing(let n) = music, n.title != oldValue.title { DebugTools.log("music: \(n.title)") } }
    }
    @Published var artwork: NSImage?
    /// Ticks every second while open, so the progress bar moves.
    @Published var clock = Date()

    @Published var selectedTab: PanelTab = .home {
        didSet {
            DebugTools.log("tab: \(selectedTab.rawValue)")
            if selectedTab != oldValue { updateTailscaleRefresh() }
        }
    }
    @Published var focus = FocusTimer()
    @Published var mic = MicActivity()
    private let micMonitor = MicMonitor()
    /// Width of the closed-notch strip (0 when nothing to show).
    var stripWidth: CGFloat { NotchGeometry.wingWidth(focus: focus.isActive, mic: mic.isActive) }
    private(set) var lastFocusMinutes = 25
    private var focusTicker: Timer?
    private var askedNotificationPermission = false
    @Published var reminders: [ReminderSummary] = []
    @Published var remindersAccess: CalendarAccess = .unknown
    /// Ticked in the last ~1 s: shown checked, saved unless clicked again.
    @Published var pendingReminderIDs: Set<String> = []
    private var pendingTicks = PendingTicks()
    @Published var tailscale: TailscaleStatus?
    @Published var tailscaleBusy = false
    @Published var tailscaleMessage: String?
    @Published var copiedDeviceID: String?

    /// `--demo`: made-up data for README screenshots, so no real reminders or files show.
    static let isDemo = CommandLine.arguments.contains("--demo")

    let shelf = ShelfStore(storageURL: AppModel.isDemo
        ? FileManager.default.temporaryDirectory.appendingPathComponent("notchpad-demo/shelf.json")
        : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notchpad/shelf.json"))
    /// Set by the window controller: keeps the panel open while a file is dragged out.
    var onShelfDragActive: ((Bool) -> Void)?

    private let calendarReader = CalendarReader()
    private lazy var remindersReader = RemindersReader(store: calendarReader.store)
    private let musicQueue = DispatchQueue(label: "notchpad.music")
    private let musicController = MusicController(
        isMusicRunning: { AppModel.musicIsRunning() },
        runner: AppleScriptRunner())
    nonisolated static let musicBundleID = "com.apple.Music"
    private var artworkTitle: String?
    private let tailscaleQueue = DispatchQueue(label: "notchpad.tailscale")
    private let tailscaleController: TailscaleController = {
        if let path = DebugTools.argument(after: "--tailscale-fixture") {
            return TailscaleController(runner: FixtureRunner(path: path), cliExists: { true })
        }
        return TailscaleController(runner: ProcessRunner())
    }()
    private var tailscaleTimer: Timer?
    /// One status read at a time, so a hung Tailscale can't queue up calls (they'd run after close).
    private var tailscaleRefresh = SingleFlight()
    private var openTimers: [Timer] = []

    init() {
        calendarAccess = calendarReader.access
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: calendarReader.store,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshEvents()
                self?.refreshReminders()
            }
        }
        observeMusic()
        music = isMusicRunning ? .idle : .notRunning
        if let tab = DebugTools.argument(after: "--tab").flatMap(PanelTab.init(rawValue:)) { selectedTab = tab }
        if CommandLine.arguments.contains("--focus-demo") { startFocus(.focus, minutes: 25) }
        if Self.isDemo { loadDemo() }
        micMonitor.onChange = { [weak self] running in
            guard let self, !CommandLine.arguments.contains("--mic-demo"), running != self.mic.isActive else { return }
            self.mic.update(isRunning: running, now: Date())
            DebugTools.log("mic: \(running)")
            self.updateFocusTicker()
        }
        micMonitor.start()
        if CommandLine.arguments.contains("--mic-demo") { mic.update(isRunning: true, now: Date().addingTimeInterval(-252)) }
        if let s = DebugTools.argument(after: "--focus-seconds").flatMap(Double.init) {
            focus.start(.focus, seconds: s, now: Date())
            askForNotificationsOnce()
            updateFocusTicker()
        }
    }

    /// Called by the window controller right after the panel opens.
    func panelDidOpen() {
        shelf.refresh()
        updateTailscaleRefresh()
        refreshEvents()
        every(60) { $0.refreshEvents() }
        refreshReminders()
        if remindersAccess == .unknown {
            Task {
                remindersAccess = await remindersReader.requestAccess()
                DebugTools.log("reminders: \(remindersAccess)")
                refreshReminders()
            }
        }
        refreshMusic()
        clock = Date()
        every(1) { $0.clock = Date() }
        if calendarAccess == .unknown {
            Task {
                calendarAccess = await calendarReader.requestAccess()
                DebugTools.log("calendar: \(calendarAccess)")
                refreshEvents()
            }
        }
    }

    /// Called by the window controller right after the panel closes. Nothing polls while closed.
    func panelDidClose() {
        openTimers.forEach { $0.invalidate() }
        openTimers.removeAll()
        updateTailscaleRefresh()
    }

    /// Runs `action` every `seconds` until the panel closes.
    private func every(_ seconds: TimeInterval, _ action: @escaping @MainActor (AppModel) -> Void) {
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        openTimers.append(timer)
    }

    // MARK: Tailscale

    private var tailscaleShowing: Bool { isOpen && selectedTab == .tailscale }

    /// Refreshes now and every 5 s while the Tailscale tab is showing; stops otherwise.
    private func updateTailscaleRefresh() {
        tailscaleTimer?.invalidate()
        tailscaleTimer = nil
        guard tailscaleShowing else { return }
        refreshTailscale()
        tailscaleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTailscale() }
        }
    }

    private func refreshTailscale() {
        guard tailscaleRefresh.tryStart() else { return }
        DebugTools.log("tailscale refresh")
        let controller = tailscaleController
        tailscaleQueue.async { [weak self] in
            let status = controller.status()
            DispatchQueue.main.async {
                guard let self else { return }
                self.tailscaleRefresh.finish()
                guard self.tailscaleShowing else { return }
                self.tailscale = status
                DebugTools.log("tailscale state: \(status.state)")
            }
        }
    }

    func connectTailscale(_ on: Bool) {
        guard !tailscaleBusy else { return }
        tailscaleBusy = true
        tailscaleMessage = nil
        let controller = tailscaleController
        // Tailscale brings itself to the front when it starts; remember who had focus.
        let previousFront = NSWorkspace.shared.frontmostApplication
        DispatchQueue.global().async { [weak self] in
            var launchedTailscale = false
            let ok = on
                ? controller.connect(
                    isAppRunning: {
                        TailscaleController.appBundleIDs.contains { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
                    },
                    launchApp: {
                        DebugTools.log("tailscale: starting the app")
                        launchedTailscale = true
                        // Start it in the background: never take focus from the app he's using.
                        let config = NSWorkspace.OpenConfiguration()
                        config.activates = false
                        let url = TailscaleController.appBundleIDs.lazy
                            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
                            ?? URL(fileURLWithPath: "/Applications/Tailscale.app")
                        NSWorkspace.shared.openApplication(at: url, configuration: config)
                    },
                    sleep: { Thread.sleep(forTimeInterval: $0) })
                : controller.setConnected(false)
            DebugTools.log("tailscale \(on ? "up" : "down") ok=\(ok)")
            if launchedTailscale, let previousFront, !TailscaleController.isTailscaleApp(previousFront.bundleIdentifier) {
                // Give focus back to the app he was using.
                Thread.sleep(forTimeInterval: 0.5)
                previousFront.activate()
                DebugTools.log("focus returned")
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.tailscaleBusy = false
                if !ok {
                    let text = on ? "Couldn't connect" : "Couldn't disconnect"
                    self.tailscaleMessage = text
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if self.tailscaleMessage == text { self.tailscaleMessage = nil }
                    }
                }
                if self.tailscaleShowing { self.refreshTailscale() }
            }
        }
    }

    func copyIP(_ device: TailscaleDevice) {
        guard let ip = device.ipv4 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        copiedDeviceID = device.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.copiedDeviceID == device.id { self?.copiedDeviceID = nil }
        }
    }

    // MARK: Music

    func sendMusic(_ command: MusicCommand) {
        let controller = musicController
        musicQueue.async { controller.send(command) }
    }

    func openMusic() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.musicBundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    private var isMusicRunning: Bool { Self.musicIsRunning() }

    nonisolated static func musicIsRunning() -> Bool {
        MusicController.isRunning(among: NSRunningApplication.runningApplications(withBundleIdentifier: musicBundleID)
            .map { ($0.bundleIdentifier, $0.isTerminated) })
    }

    private func observeMusic() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main
        ) { [weak self] note in
            let info = note.userInfo ?? [:]
            let track = NowPlaying.from(playerInfo: info, now: Date())
            let shouldQuery = MusicController.shouldQuery(afterPlayerInfo: info)
            MainActor.assumeIsolated {
                guard let self else { return }
                if let track { self.music = .playing(track) } else { self.music = self.isMusicRunning ? .idle : .notRunning }
                if self.isOpen && shouldQuery { self.refreshMusic() }
            }
        }
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == AppModel.musicBundleID else { return }
                let launched = name == NSWorkspace.didLaunchApplicationNotification
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.music = launched ? .idle : .notRunning
                    if !launched { self.artwork = nil; self.artworkTitle = nil }
                }
            }
        }
    }

    /// Asks Music for the current track, position and artwork. Never launches Music.
    private func refreshMusic() {
        guard !Self.isDemo else { return }
        guard isMusicRunning else {
            music = .notRunning
            artwork = nil
            artworkTitle = nil
            return
        }
        if music == .notRunning { music = .idle }
        let controller = musicController
        let knownArtworkTitle = artworkTitle
        musicQueue.async { [weak self] in
            let track = controller.fetchNowPlaying(now: Date())
            let needsArtwork = track != nil && track?.title != knownArtworkTitle
            let data = needsArtwork ? controller.fetchArtwork() : nil
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isMusicRunning else {
                    // Music quit while we were asking: don't show stale "running" state.
                    self.music = .notRunning
                    self.artwork = nil
                    self.artworkTitle = nil
                    return
                }
                self.music = track.map { .playing($0) } ?? .idle
                if needsArtwork {
                    self.artwork = data.flatMap(NSImage.init(data:))
                    self.artworkTitle = track?.title
                } else if track == nil {
                    self.artwork = nil
                    self.artworkTitle = nil
                }
            }
        }
    }

    // MARK: Focus timer

    func startFocus(_ kind: FocusKind, minutes: Int) {
        if kind == .focus { lastFocusMinutes = minutes }
        focus.start(kind, minutes: minutes, now: Date())
        clock = Date()
        askForNotificationsOnce()
        updateFocusTicker()
    }

    func togglePauseFocus() {
        if focus.isPaused { focus.resume(now: Date()) } else { focus.pause(now: Date()) }
        updateFocusTicker()
    }

    func stopFocus() {
        focus.stop()
        updateFocusTicker()
    }

    /// The only timer that runs while the panel is closed: only while a countdown runs or the mic is in use.
    /// Added in .common mode so it keeps ticking while a menu is open or a drag is running.
    private func updateFocusTicker() {
        let running: Bool = { if case .running = focus.phase { return true }; return mic.isActive }()
        if running, focusTicker == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.focusTick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            focusTicker = timer
        } else if !running {
            focusTicker?.invalidate()
            focusTicker = nil
        }
    }

    private func focusTick() {
        clock = Date()
        DebugTools.log("focus tick")
        if focus.tick(now: Date()), let kind = focus.kind {
            updateFocusTicker()
            FocusAlert.fire(kind)
        }
    }

    private func askForNotificationsOnce() {
        guard !askedNotificationPermission else { return }
        askedNotificationPermission = true
        FocusAlert.requestPermission()
    }

    // MARK: Reminders

    private func refreshReminders() {
        guard !Self.isDemo else { return }
        remindersAccess = remindersReader.access
        guard remindersAccess == .granted else { reminders = []; return }
        Task {
            let items = await remindersReader.fetchIncomplete()
            reminders = items
            DebugTools.log("reminders loaded: \(items.count)")
        }
    }

    /// First click ticks (saved after ~1.2 s); a second click within that time undoes it.
    func toggleReminder(_ id: String) {
        if pendingTicks.contains(id) {
            pendingTicks.untick(id)
            pendingReminderIDs.remove(id)
            return
        }
        let token = pendingTicks.tick(id)
        pendingReminderIDs.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.pendingTicks.commit(id, token: token) else { return }
            self.remindersReader.complete(id)
            // Drop the row now, so it doesn't flash back unticked while the refresh runs.
            self.reminders.removeAll { $0.id == id }
            self.pendingReminderIDs.remove(id)
            DebugTools.log("reminder completed")
            self.refreshReminders()
        }
    }

    private func refreshEvents() {
        guard !Self.isDemo else { return }
        calendarAccess = calendarReader.access
        events = DayEvents.upcoming(calendarReader.todaysEvents(now: Date()), now: Date(), calendar: .current)
    }

}

private extension MusicState {
    var title: String? { if case .playing(let n) = self { n.title } else { nil } }
}

/// For `--tailscale-fixture <path>`: answers `status --json` with a saved file, `up`/`down` with success.
private struct FixtureRunner: CommandRunning {
    let path: String
    func run(_ executable: String, _ arguments: [String]) -> (exitCode: Int32, output: Data)? {
        (0, arguments.first == "status" ? ((try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()) : Data())
    }
}

// MARK: Demo data (README screenshots only)

extension AppModel {
    fileprivate func loadDemo() {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: today)! }
        func item(_ title: String, _ due: Date?, list: String = "Personal", order: Int = 0) -> ReminderSummary {
            ReminderSummary(id: title, title: title, listID: list, listTitle: list, listOrder: order, due: due, dueHasTime: false)
        }
        reminders = [
            item("Renew library books", day(-1)),
            item("Submit lab report", day(0)),
            item("Call the dentist", day(1)),
            item("Pay phone bill", day(3)),
            item("Plan weekend trip", nil),
            item("Milk", nil, list: "Shopping", order: 1),
        ]
        remindersAccess = .granted
        let start = cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!
        events = [EventSummary(id: "demo", title: "Networking lecture", start: start,
                               end: start.addingTimeInterval(7200), isAllDay: false,
                               red: 0.04, green: 0.52, blue: 1)]
        calendarAccess = .granted
        music = .notRunning
        focus.start(.focus, seconds: 18 * 60 + 42, now: now)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("notchpad-demo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let files = ["Lecture notes.pdf", "Lab screenshot.png"].map { dir.appendingPathComponent($0) }
        for f in files where !FileManager.default.fileExists(atPath: f.path) {
            FileManager.default.createFile(atPath: f.path, contents: Data("demo".utf8))
        }
        shelf.clear()
        shelf.add(files)
    }
}
