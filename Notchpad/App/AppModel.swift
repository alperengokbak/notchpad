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
    @Published var battery: BatteryStatus?
    @Published var temperature: Int?
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
    @Published var tailscale: TailscaleStatus?
    @Published var tailscaleBusy = false
    @Published var tailscaleMessage: String?
    @Published var copiedDeviceID: String?

    let shelf = ShelfStore(storageURL: FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Notchpad/shelf.json"))
    /// Set by the window controller: keeps the panel open while a file is dragged out.
    var onShelfDragActive: ((Bool) -> Void)?

    private let batteryReader = BatteryReader()
    private let temperatureReader = TemperatureReader()
    private let calendarReader = CalendarReader()
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
        battery = batteryReader.current()
        batteryReader.observe { [weak self] in
            guard let self else { return }
            self.battery = self.batteryReader.current()
        }
        calendarAccess = calendarReader.access
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: calendarReader.store,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshEvents() }
        }
        observeMusic()
        music = isMusicRunning ? .idle : .notRunning
        if DebugTools.argument(after: "--tab") == "tailscale" { selectedTab = .tailscale }
    }

    /// Called by the window controller right after the panel opens.
    func panelDidOpen() {
        shelf.refresh()
        updateTailscaleRefresh()
        refreshTemperature()
        every(2) { $0.refreshTemperature() }
        refreshEvents()
        every(60) { $0.refreshEvents() }
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
        DispatchQueue.global().async { [weak self] in
            let ok = controller.setConnected(on)
            DebugTools.log("tailscale \(on ? "up" : "down") ok=\(ok)")
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

    private func refreshEvents() {
        calendarAccess = calendarReader.access
        events = DayEvents.upcoming(calendarReader.todaysEvents(now: Date()), now: Date(), calendar: .current)
    }

    private func refreshTemperature() {
        temperature = ChipTemperature.average(temperatureReader.readAll())
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
