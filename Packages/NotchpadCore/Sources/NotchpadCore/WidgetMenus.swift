import Foundation

// Logic behind the right-click menus on widgets. The menus themselves are built in the app.

/// Text inside an AppleScript string literal.
public enum AppleScriptText {
    /// `He said "hi"` → `"He said \"hi\""`. Backslashes first, then quotes.
    public static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

/// Finds an online meeting link in an event (its URL, location or notes).
public enum MeetingLink {
    /// Hosts of the meeting services Notchpad recognises.
    static let hosts = ["zoom.us", "teams.microsoft.com", "teams.live.com", "meet.google.com", "webex.com", "facetime.apple.com",
                        "whereby.com", "gotomeeting.com", "chime.aws"]

    /// The first meeting link in the texts, in order. Nil when there is none.
    public static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, url.scheme == "https" || url.scheme == "http",
                      let host = url.host?.lowercased() else { continue }
                if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
            }
        }
        return nil
    }
}

/// Shareable links for the song playing.
public enum SongLink {
    /// `spotify:track:4uLU6hMCjMI75M1A2tKUQC` → `https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC`.
    public static func spotifyWebURL(fromURI uri: String) -> URL? {
        let parts = uri.split(separator: ":")
        guard parts.count == 3, parts[0] == "spotify", !parts[2].isEmpty,
              parts[2].allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return URL(string: "https://open.spotify.com/\(parts[1])/\(parts[2])")
    }

    /// Apple's public search service (no account): finds the song's Apple Music page.
    public static func appleLookupURL(title: String, artist: String, country: String) -> URL? {
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [URLQueryItem(name: "term", value: "\(title) \(artist)"), URLQueryItem(name: "entity", value: "song"),
                        URLQueryItem(name: "limit", value: "5"), URLQueryItem(name: "country", value: country)]
        return c.url
    }

    /// The best result's page: same title and artist (ignoring case) first, otherwise nothing.
    public static func parseAppleLookup(_ data: Data, title: String, artist: String) -> URL? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else { return nil }
        func same(_ a: Any?, _ b: String) -> Bool {
            (a as? String)?.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let match = results.first { same($0["trackName"], title) && same($0["artistName"], artist) }
            ?? results.first { same($0["trackName"], title) }
        // Drop Apple's tracking tag ("uo=4") so the shared link is clean.
        guard let page = match?["trackViewUrl"] as? String, var c = URLComponents(string: page) else { return nil }
        c.queryItems = c.queryItems?.filter { $0.name != "uo" }
        return c.url
    }

    /// When the lookup finds nothing: an Apple Music search page for the song.
    public static func appleSearchPage(title: String, artist: String) -> URL? {
        var c = URLComponents(string: "https://music.apple.com/search")!
        c.queryItems = [URLQueryItem(name: "term", value: "\(title) \(artist)")]
        return c.url
    }
}

/// The Quick note as an Apple Notes body: the first line becomes the title, every line its own paragraph.
public enum NoteExport {
    public static func html(_ text: String) -> String {
        text.components(separatedBy: "\n").enumerated().map { i, line in
            let escaped = escape(line)
            if i == 0 && !line.isEmpty { return "<div><h1>\(escaped)</h1></div>" }
            return "<div>\(escaped.isEmpty ? "<br>" : escaped)</div>"
        }.joined()
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Repeat in the music app. Spotify only has on and off (`.all` / `.off`).
public enum RepeatMode: String, CaseIterable, Sendable {
    case off, all, one

    public var title: String {
        switch self {
        case .off: "Off"
        case .all: "All"
        case .one: "One"
        }
    }
}

/// What the Music menu shows ticks for, read when the panel opens.
public struct MusicMenuState: Equatable, Sendable {
    public var playlists: [String] = []
    public var favorited: Bool?
    public var shuffle: Bool?
    public var repeatMode: RepeatMode?

    public init(playlists: [String] = [], favorited: Bool? = nil, shuffle: Bool? = nil, repeatMode: RepeatMode? = nil) {
        self.playlists = playlists; self.favorited = favorited; self.shuffle = shuffle; self.repeatMode = repeatMode
    }
}

/// How adding the song to the library or a playlist went.
public enum MusicAddResult: String, Sendable {
    case added, alreadyThere, failed

    public static func parse(_ reply: String?) -> MusicAddResult {
        switch reply {
        case "added": .added
        case "already": .alreadyThere
        default: .failed
        }
    }
}
