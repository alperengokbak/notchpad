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

    /// Jumps to `seconds` into the current song. Both apps take seconds here.
    public func seek(to seconds: TimeInterval) {
        _ = tell("set player position to " + String(format: "%.1f", max(seconds, 0)))
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

    // MARK: Right-click menu

    /// Apple Music: his own playlists (not smart, not folders), in Music's order. Spotify: none (not scriptable).
    public func fetchPlaylists() -> [String] {
        guard source == .appleMusic else { return [] }
        let reply = tellBlock("""
            set out to {}
            repeat with p in (user playlists whose smart is false and special kind is none)
            if class of p is not folder playlist then set end of out to name of p
            end repeat
            return out
            """)
        guard let reply, reply.numberOfItems > 0 else { return [] }
        return (1...reply.numberOfItems).compactMap { reply.atIndex($0)?.stringValue }
    }

    /// Ticks for the menu: favourite (Apple Music), shuffle and repeat.
    public func fetchMenuState() -> MusicMenuState {
        var state = MusicMenuState()
        switch source {
        case .appleMusic:
            let reply = tellBlock("""
                set f to "none"
                if player state is not stopped then set f to (favorited of current track) as string
                return {f, shuffle enabled as string, song repeat as string}
                """)
            guard let reply, reply.numberOfItems == 3 else { return state }
            state.favorited = Self.bool(reply.atIndex(1)?.stringValue)
            state.shuffle = Self.bool(reply.atIndex(2)?.stringValue)
            state.repeatMode = reply.atIndex(3)?.stringValue.flatMap(RepeatMode.init(rawValue:))
        case .spotify:
            let reply = tellBlock("return {shuffling as string, repeating as string}")
            guard let reply, reply.numberOfItems == 2 else { return state }
            state.shuffle = Self.bool(reply.atIndex(1)?.stringValue)
            state.repeatMode = Self.bool(reply.atIndex(2)?.stringValue).map { $0 ? .all : .off }
        }
        return state
    }

    public func setShuffle(_ on: Bool) {
        _ = tell(source == .appleMusic ? "set shuffle enabled to \(on)" : "set shuffling to \(on)")
    }

    public func setRepeat(_ mode: RepeatMode) {
        _ = tell(source == .appleMusic ? "set song repeat to \(mode.rawValue)" : "set repeating to \(mode != .off)")
    }

    /// Apple Music only: the heart on the current song.
    public func setFavorited(_ on: Bool) {
        guard source == .appleMusic else { return }
        _ = tellBlock("if player state is not stopped then set favorited of current track to \(on)")
    }

    /// Apple Music only. A streamed song is added the way Music's own "Add to Library" does it;
    /// it takes a few seconds to show up, so this waits for it (up to 10 s).
    public func addToLibrary() -> MusicAddResult {
        guard source == .appleMusic else { return .failed }
        return MusicAddResult.parse(tellBlock("""
            try
            if player state is stopped then return "failed"
            \(Self.findInLibrary)
            if (count of found) > 0 then return "already"
            \(Self.addAndWait)
            if (count of found) > 0 then return "added"
            end try
            return "failed"
            """)?.stringValue)
    }

    /// Apple Music only. A song already in the library goes straight in; a streamed one is added to
    /// the library first (Music requires that), then to the playlist. A song already there isn't added twice.
    public func addToPlaylist(_ name: String) -> MusicAddResult {
        guard source == .appleMusic else { return .failed }
        return MusicAddResult.parse(tellBlock("""
            try
            if player state is stopped then return "failed"
            set p to first user playlist whose name is \(AppleScriptText.quote(name))
            \(Self.findInLibrary)
            if (count of (tracks of p whose name is nm and artist is ar)) > 0 then return "already"
            try
            duplicate t to p
            return "added"
            end try
            if (count of found) = 0 then
            \(Self.addAndWait)
            end if
            if (count of found) = 0 then return "failed"
            duplicate (item 1 of found) to p
            return "added"
            end try
            return "failed"
            """)?.stringValue)
    }

    /// Spotify only: `spotify:track:…` of the current song.
    public func fetchSpotifyURI() -> String? {
        guard source == .spotify else { return nil }
        return tell("get spotify url of current track")?.stringValue
    }

    /// Apple Music: select the song in Music's window (the app brings Music forward itself).
    /// Some streamed songs can't be selected; that's ignored.
    public func reveal() {
        guard source == .appleMusic else { return }
        _ = tellBlock("""
            try
            if player state is not stopped then reveal current track
            end try
            """)
    }

    /// Sets `t`, `nm`, `ar` and `found` (copies of the song in his library).
    private static let findInLibrary = """
        set t to current track
        set nm to name of t
        set ar to artist of t
        set found to (tracks of library playlist 1 whose name is nm and artist is ar)
        """

    private static let addAndWait = """
        duplicate t to source 1
        repeat 20 times
        delay 0.5
        set found to (tracks of library playlist 1 whose name is nm and artist is ar)
        if (count of found) > 0 then exit repeat
        end repeat
        """

    private static func bool(_ text: String?) -> Bool? {
        switch text {
        case "true": true
        case "false": false
        default: nil
        }
    }

    private func tellBlock(_ body: String) -> NSAppleEventDescriptor? {
        guard isMusicRunning() else { return nil }
        return runner.run("tell application \"\(source.appName)\"\n\(body)\nend tell")
    }

    private func tell(_ body: String) -> NSAppleEventDescriptor? {
        guard isMusicRunning() else { return nil }
        return runner.run("tell application \"\(source.appName)\" to \(body)")
    }
}
