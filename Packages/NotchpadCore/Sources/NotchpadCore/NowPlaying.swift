import Foundation

/// The song Apple Music or Spotify has loaded.
public struct NowPlaying: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var duration: TimeInterval?
    /// Position at `positionDate`.
    public var position: TimeInterval
    public var isPlaying: Bool
    public var positionDate: Date

    public init(title: String, artist: String, duration: TimeInterval?, position: TimeInterval,
                isPlaying: Bool, positionDate: Date) {
        self.title = title; self.artist = artist; self.duration = duration
        self.position = position; self.isPlaying = isPlaying; self.positionDate = positionDate
    }

    /// Parses the `com.apple.Music.playerInfo` notification. Nil when stopped or empty.
    /// The notification has no position, so it starts at 0 until fetched.
    public static func from(playerInfo: [AnyHashable: Any], now: Date) -> NowPlaying? {
        from(playerInfo: playerInfo, source: .appleMusic, now: now)
    }

    /// Parses Apple Music's or Spotify's notification. Both send milliseconds for the length
    /// (Music as "Total Time", Spotify as "Duration"); only Spotify sends the position.
    public static func from(playerInfo: [AnyHashable: Any], source: MusicSource, now: Date) -> NowPlaying? {
        let state = playerInfo["Player State"] as? String
        guard state != "Stopped", let title = playerInfo["Name"] as? String else { return nil }
        let lengthKey = source == .spotify ? "Duration" : "Total Time"
        let ms = (playerInfo[lengthKey] as? NSNumber)?.doubleValue
        let position = (playerInfo["Playback Position"] as? NSNumber)?.doubleValue ?? 0
        return NowPlaying(title: title, artist: playerInfo["Artist"] as? String ?? "",
                          duration: ms.map { $0 / 1000 }, position: position,
                          isPlaying: state == "Playing", positionDate: now)
    }

    /// Where the song is at `date`: moves on while playing, never past the end.
    public func position(at date: Date) -> TimeInterval {
        let p = isPlaying ? position + date.timeIntervalSince(positionDate) : position
        return duration.map { min(p, $0) } ?? p
    }
}

public enum MusicState: Equatable, Sendable {
    case notRunning
    case idle
    case playing(NowPlaying)
}

extension MusicState {
    /// True only while a song is actually playing (not paused, idle or closed).
    public var isPlaying: Bool {
        if case .playing(let song) = self { return song.isPlaying }
        return false
    }
}

/// Which song the cover on screen belongs to. Dropping the cover also forgets its song,
/// so going back to that song later fetches the cover again.
public struct CoverCache: Equatable, Sendable {
    public private(set) var title: String?

    public init() {}

    /// A player notification named this song. True when the cover on screen is for another
    /// song (or there is none), meaning it should be cleared.
    public mutating func songChanged(to title: String) -> Bool {
        guard title != self.title else { return false }
        self.title = nil
        return true
    }

    /// True when a cover for this song isn't on screen yet.
    public func needsFetch(for title: String?) -> Bool {
        title != nil && title != self.title
    }

    public mutating func stored(for title: String?) {
        self.title = title
    }
}
