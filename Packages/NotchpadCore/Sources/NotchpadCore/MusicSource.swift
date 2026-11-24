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

    /// The player the Music widget showed last, so its "Open" button opens the right app.
    public var lastMusicSource: MusicSource? {
        get { defaults.string(forKey: Self.sourceKey).flatMap(MusicSource.init(rawValue:)) }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Self.sourceKey) }
    }
}
