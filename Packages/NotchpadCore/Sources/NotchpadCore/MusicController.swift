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

/// Talks to Apple Music. Every call checks first that Music is already running,
/// because `tell application "Music"` would launch it.
public final class MusicController: @unchecked Sendable {
    private let isMusicRunning: () -> Bool
    private let runner: ScriptRunning

    public init(isMusicRunning: @escaping () -> Bool, runner: ScriptRunning) {
        self.isMusicRunning = isMusicRunning
        self.runner = runner
    }

    /// Music counts as running only if a not-yet-terminated process has its bundle id.
    /// (A quitting Music is still listed for a moment; talking to it then relaunches it.)
    public static func isRunning(among apps: [(bundleID: String?, isTerminated: Bool)]) -> Bool {
        apps.contains { $0.bundleID == "com.apple.Music" && !$0.isTerminated }
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

    public func fetchArtwork() -> Data? {
        tell("get raw data of artwork 1 of current track")?.data
    }

    /// The current track straight from Music, for when no notification has arrived yet.
    public func fetchNowPlaying(now: Date) -> NowPlaying? {
        let script = "if player state is not stopped then get {name of current track, artist of current track, "
            + "duration of current track, player state as string, player position}"
        guard let list = tell(script), list.numberOfItems >= 5,
              let title = list.atIndex(1)?.stringValue else { return nil }
        return NowPlaying(title: title, artist: list.atIndex(2)?.stringValue ?? "",
                          duration: list.atIndex(3)?.doubleValue, position: list.atIndex(5)?.doubleValue ?? 0,
                          isPlaying: list.atIndex(4)?.stringValue == "playing", positionDate: now)
    }

    private func tell(_ body: String) -> NSAppleEventDescriptor? {
        guard isMusicRunning() else { return nil }
        return runner.run("tell application \"Music\" to \(body)")
    }
}
