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
        isMusicRunning: { !NSRunningApplication.runningApplications(withBundleIdentifier: AppModel.musicBundleID).isEmpty },
        runner: AppleScriptRunner())
    nonisolated static let musicBundleID = "com.apple.Music"
    private var artworkTitle: String?
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
    }

    /// Called by the window controller right after the panel opens.
    func panelDidOpen() {
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
    }

    /// Runs `action` every `seconds` until the panel closes.
    private func every(_ seconds: TimeInterval, _ action: @escaping @MainActor (AppModel) -> Void) {
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        openTimers.append(timer)
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

    private var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.musicBundleID).isEmpty
    }

    private func observeMusic() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main
        ) { [weak self] note in
            let info = note.userInfo ?? [:]
            let track = NowPlaying.from(playerInfo: info, now: Date())
            MainActor.assumeIsolated {
                guard let self else { return }
                if let track { self.music = .playing(track) } else { self.music = self.isMusicRunning ? .idle : .notRunning }
                if self.isOpen { self.refreshMusic() }
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
