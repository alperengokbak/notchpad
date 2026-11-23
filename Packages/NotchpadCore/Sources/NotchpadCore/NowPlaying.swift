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
