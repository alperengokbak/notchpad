import Foundation

/// The music apps Notchpad can show and control.
public enum MusicSource: String, CaseIterable, Codable, Sendable {
    case appleMusic, spotify

    public var bundleID: String {
        switch self {
        case .appleMusic: "com.apple.Music"
        case .spotify: "com.spotify.client"
        }
    }

    /// Name used in `tell application "…"`.
    public var appName: String {
        switch self {
        case .appleMusic: "Music"
        case .spotify: "Spotify"
        }
    }

    /// Name shown to people.
    public var title: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        }
    }

    /// Distributed notification the app posts when the song or play state changes.
    public var notificationName: String {
        switch self {
        case .appleMusic: "com.apple.Music.playerInfo"
        case .spotify: "com.spotify.client.PlaybackStateChanged"
        }
    }
}

/// Which player the Music widget follows: whichever is playing; otherwise the last one.
public enum PlayerFollower {
    public static func choose(current: MusicSource, playing: Set<MusicSource>, running: Set<MusicSource>) -> MusicSource {
        if playing.contains(current) { return current }
        if let other = MusicSource.allCases.first(where: playing.contains) { return other }
        if running.contains(current) || running.isEmpty { return current }
        return MusicSource.allCases.first(where: running.contains) ?? current
    }
}

/// Small settings that survive restarts.
public struct Preferences {
    private let defaults: UserDefaults
    private static let micKey = "showMicIndicator"
    private static let sourceKey = "lastMusicSource"
    private static let closedMusicKey = "showClosedMusic"
    private static let focusMinutesKey = "focusMinutes"
    private static let swipeKey = "swipeToChangeSongs"
    private static let shelfNewestKey = "shelfNewestFirst"
    private static let fileDragKey = "openOnFileDrag"
    private static let chargingKey = "showChargingAnimation"
    private static let updatesKey = "checkForUpdates"
    private static let lastCheckKey = "lastUpdateCheck"
    private static let clockZonesKey = "worldClockZones"
    private static let screenshotsKey = "screenshotsToShelf"
    private static let focusLogKey = "focusLog"
    private static let quickNoteKey = "quickNote"
    private static let mainDisplayKey = "preferMainDisplay"
    private static let mirrorFlippedKey = "mirrorFlipped"
    private static let displayChoiceKey = "displayChoice"
    private static let clipboardPausedKey = "clipboardPaused"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The red mic beside the notch. On unless he turned it off.
    public var showMicIndicator: Bool {
        get { defaults.object(forKey: Self.micKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.micKey) }
    }

    /// Cover and bars beside the closed notch while a song plays. On unless turned off.
    public var showClosedMusic: Bool {
        get { defaults.object(forKey: Self.closedMusicKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.closedMusicKey) }
    }

    /// Focus length picked with − / +. 25 until changed; always within 5…180.
    public var focusMinutes: Int {
        get { FocusLength.clamp(defaults.object(forKey: Self.focusMinutesKey) as? Int ?? 25) }
        nonmutating set { defaults.set(FocusLength.clamp(newValue), forKey: Self.focusMinutesKey) }
    }

    /// Two-finger swipe over the notch changes the song. On unless turned off.
    public var swipeToChangeSongs: Bool {
        get { defaults.object(forKey: Self.swipeKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.swipeKey) }
    }

    /// Shelf shows the most recently added files first. Off unless turned on.
    public var shelfNewestFirst: Bool {
        get { defaults.object(forKey: Self.shelfNewestKey) as? Bool ?? false }
        nonmutating set { defaults.set(newValue, forKey: Self.shelfNewestKey) }
    }

    /// Dragging a file towards the notch opens the panel. On unless turned off.
    public var openOnFileDrag: Bool {
        get { defaults.object(forKey: Self.fileDragKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.fileDragKey) }
    }

    /// A short "plugged in" badge beside the closed notch. On unless turned off.
    public var showChargingAnimation: Bool {
        get { defaults.object(forKey: Self.chargingKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.chargingKey) }
    }

    /// Ask GitHub once a day whether a newer Notchpad exists. On unless turned off.
    public var checkForUpdates: Bool {
        get { defaults.object(forKey: Self.updatesKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.updatesKey) }
    }

    public var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Self.lastCheckKey) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Self.lastCheckKey) }
    }

    /// World clock cities (time zone IDs). Starts with this Mac's own time zone.
    public var worldClockZones: [String] {
        get { defaults.stringArray(forKey: Self.clockZonesKey) ?? [TimeZone.current.identifier] }
        nonmutating set { defaults.set(newValue, forKey: Self.clockZonesKey) }
    }

    /// New screenshots go to the shelf. Off unless turned on.
    public var screenshotsToShelf: Bool {
        get { defaults.object(forKey: Self.screenshotsKey) as? Bool ?? false }
        nonmutating set { defaults.set(newValue, forKey: Self.screenshotsKey) }
    }

    public var focusLog: FocusLog {
        get { defaults.dictionary(forKey: Self.focusLogKey).map { FocusLog(days: $0.compactMapValues { $0 as? Int }) } ?? FocusLog() }
        nonmutating set { defaults.set(newValue.days, forKey: Self.focusLogKey) }
    }

    /// The Quick note widget's text.
    public var quickNote: String {
        get { defaults.string(forKey: Self.quickNoteKey) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Self.quickNoteKey) }
    }

    /// Put Notchpad on the main display (an external monitor) instead of the MacBook's notch. Off unless turned on.
    /// "Show on": the key of the screen Notchpad should use; nil = the MacBook notch (or the main screen).
    public var displayChoice: String? {
        get { defaults.string(forKey: Self.displayChoiceKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.displayChoiceKey) }
    }

    /// Mirror widget shows the camera unmirrored (as others see you). Off unless turned on.
    public var mirrorFlipped: Bool {
        get { defaults.bool(forKey: Self.mirrorFlippedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.mirrorFlippedKey) }
    }

    /// Clipboard history stops saving new copies. Off unless turned on.
    public var clipboardPaused: Bool {
        get { defaults.bool(forKey: Self.clipboardPausedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.clipboardPausedKey) }
    }

    public var preferMainDisplay: Bool {
        get { defaults.object(forKey: Self.mainDisplayKey) as? Bool ?? false }
        nonmutating set { defaults.set(newValue, forKey: Self.mainDisplayKey) }
    }

    /// The player the Music widget showed last, so its "Open" button opens the right app.
    public var lastMusicSource: MusicSource? {
        get { defaults.string(forKey: Self.sourceKey).flatMap(MusicSource.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.sourceKey) }
    }
}
