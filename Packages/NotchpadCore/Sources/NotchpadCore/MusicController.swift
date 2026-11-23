import Foundation

public enum MusicCommand: String, Sendable {
    case playPause = "playpause"
    case next = "next track"
    case previous = "previous track"
}

/// Runs AppleScript. The app's implementation uses NSAppleScript; tests use a spy.
public protocol ScriptRunning: Sendable {
    func run(_ source: String) -> NSAppleEventDescriptor?
}

/// Talks to Apple Music or Spotify. Every call checks first that the app is already running,
/// because `tell application "…"` would launch it.
public final class MusicController: @unchecked Sendable {
    public let source: MusicSource
    private let isMusicRunning: () -> Bool
    private let runner: ScriptRunning

    public init(source: MusicSource = .appleMusic, isMusicRunning: @escaping () -> Bool, runner: ScriptRunning) {
        self.source = source
        self.isMusicRunning = isMusicRunning
        self.runner = runner
    }

    /// The app counts as running only if a not-yet-terminated process has its bundle id.
    /// (A quitting app is still listed for a moment; talking to it then relaunches it.)
    public static func isRunning(_ source: MusicSource, among apps: [(bundleID: String?, isTerminated: Bool)]) -> Bool {
        apps.contains { $0.bundleID == source.bundleID && !$0.isTerminated }
    }

    public static func isRunning(among apps: [(bundleID: String?, isTerminated: Bool)]) -> Bool {
        isRunning(.appleMusic, among: apps)
    }

    /// After a playerInfo notification, only ask Music for more if it has a track and isn't stopped.
    /// Music posts "Stopped" as it quits; querying then could start it again.
    public static func shouldQuery(afterPlayerInfo info: [AnyHashable: Any]) -> Bool {
        info["Name"] is String && (info["Player State"] as? String) != "Stopped"
    }

    public func send(_ command: MusicCommand) {
        _ = tell(command.rawValue)
    }

    public func fetchPosition() -> TimeInterval? {
        tell("get player position")?.doubleValue
    }

    /// Apple Music only: the cover image itself.
    public func fetchArtwork() -> Data? {
        guard source == .appleMusic else { return nil }
        return tell("get raw data of artwork 1 of current track")?.data
    }

    /// Spotify only: a web address of the cover image.
    public func fetchArtworkURL() -> URL? {
        guard source == .spotify else { return nil }
        return tell("get artwork url of current track")?.stringValue.flatMap(URL.init(string:))
    }

    /// The current track straight from Music, for when no notification has arrived yet.
    public func fetchNowPlaying(now: Date) -> NowPlaying? {
        let script = "if player state is not stopped then get {name of current track, artist of current track, "
            + "duration of current track, player state as string, player position}"
        guard let list = tell(script), list.numberOfItems >= 5,
              let title = list.atIndex(1)?.stringValue else { return nil }
        // Music reports the length in seconds, Spotify in milliseconds.
        let length = list.atIndex(3).map { source == .spotify ? $0.doubleValue / 1000 : $0.doubleValue }
        return NowPlaying(title: title, artist: list.atIndex(2)?.stringValue ?? "",
                          duration: length, position: list.atIndex(5)?.doubleValue ?? 0,
                          isPlaying: list.atIndex(4)?.stringValue == "playing", positionDate: now)
    }

    private func tell(_ body: String) -> NSAppleEventDescriptor? {
        guard isMusicRunning() else { return nil }
        return runner.run("tell application \"\(source.appName)\" to \(body)")
    }
}
