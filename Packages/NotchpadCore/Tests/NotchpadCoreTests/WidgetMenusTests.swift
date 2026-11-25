import Foundation
import Testing
@testable import NotchpadCore

// MARK: AppleScript text

@Test func appleScriptQuotingEscapesQuotesAndBackslashes() {
    #expect(AppleScriptText.quote("Road trip") == "\"Road trip\"")
    #expect(AppleScriptText.quote("80's \"best\"") == "\"80's \\\"best\\\"\"")
    #expect(AppleScriptText.quote("a\\b") == "\"a\\\\b\"")
}

// MARK: Meeting links

@Test func findsMeetingLinksInLocationOrNotes() {
    let zoom = MeetingLink.find(in: [nil, "Room 2.14", "Join: https://uni.zoom.us/j/123456789?pwd=abc thanks"])
    #expect(zoom?.absoluteString == "https://uni.zoom.us/j/123456789?pwd=abc")
    let teams = MeetingLink.find(in: ["https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0"])
    #expect(teams?.host == "teams.microsoft.com")
    #expect(MeetingLink.find(in: ["meet.google.com/abc-defg-hij"])?.host == "meet.google.com")
}

@Test func ignoresOtherLinksAndLookalikes() {
    #expect(MeetingLink.find(in: ["https://example.com/zoom.us", "https://notzoom.us/j/1", "Lecture room"]) == nil)
    #expect(MeetingLink.find(in: [nil, ""]) == nil)
    // The first meeting link wins, in the order given (URL, location, notes).
    let first = MeetingLink.find(in: ["https://meet.google.com/aaa-bbbb-ccc", "https://zoom.us/j/1"])
    #expect(first?.host == "meet.google.com")
}

// MARK: Song links

@Test func spotifyURIBecomesWebLink() {
    #expect(SongLink.spotifyWebURL(fromURI: "spotify:track:4uLU6hMCjMI75M1A2tKUQC")?.absoluteString
            == "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")
    #expect(SongLink.spotifyWebURL(fromURI: "spotify:local:Artist:Album:Song:215") == nil)
    #expect(SongLink.spotifyWebURL(fromURI: "nonsense") == nil)
}

@Test func appleLookupPicksMatchingSong() throws {
    let json = """
    {"resultCount":2,"results":[
     {"trackName":"Paper Lanterns (Live)","artistName":"Demo Artist","trackViewUrl":"https://music.apple.com/gb/album/x/1?i=1"},
     {"trackName":"Paper Lanterns","artistName":"Demo Artist","trackViewUrl":"https://music.apple.com/gb/album/y/2?i=2&uo=4"}]}
    """
    let url = SongLink.parseAppleLookup(Data(json.utf8), title: "paper lanterns", artist: "demo artist")
    #expect(url?.absoluteString == "https://music.apple.com/gb/album/y/2?i=2")
    #expect(SongLink.parseAppleLookup(Data(json.utf8), title: "Other", artist: "Demo Artist") == nil)
    #expect(SongLink.parseAppleLookup(Data("oops".utf8), title: "a", artist: "b") == nil)
    let lookup = try #require(SongLink.appleLookupURL(title: "Paper Lanterns", artist: "Demo Artist", country: "GB"))
    #expect(lookup.absoluteString.hasPrefix("https://itunes.apple.com/search?term=Paper%20Lanterns%20Demo%20Artist&entity=song"))
    #expect(lookup.absoluteString.hasSuffix("&country=GB"))
    #expect(SongLink.appleSearchPage(title: "A&B", artist: "C")?.absoluteString == "https://music.apple.com/search?term=A%26B%20C")
}

// MARK: Quick note to Apple Notes

@Test func noteExportMakesTitleAndParagraphs() {
    #expect(NoteExport.html("Shopping\nmilk & eggs\n\n<b>") ==
            "<div><h1>Shopping</h1></div><div>milk &amp; eggs</div><div><br></div><div>&lt;b&gt;</div>")
}

// MARK: Focus history

@Test func clearDayForgetsOnlyThatDay() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/London")!
    let today = cal.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12))!
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    var log = FocusLog()
    log.record(minutes: 25, at: today, calendar: cal)
    log.record(minutes: 50, at: yesterday, calendar: cal)
    log.clearDay(today, calendar: cal)
    #expect(log.minutesToday(now: today, calendar: cal) == 0)
    #expect(log.minutesToday(now: yesterday, calendar: cal) == 50)
}

// MARK: Music commands

private func list(_ items: [String]) -> NSAppleEventDescriptor {
    let l = NSAppleEventDescriptor.list()
    for (i, s) in items.enumerated() { l.insert(NSAppleEventDescriptor(string: s), at: i + 1) }
    return l
}

@Test func playlistsAndStateComeFromOneTellBlock() {
    let spy = SpyRunner()
    spy.reply = list(["Road trip", "Study"])
    let music = MusicController(isMusicRunning: { true }, runner: spy)
    #expect(music.fetchPlaylists() == ["Road trip", "Study"])
    #expect(spy.calls.last?.hasPrefix("tell application \"Music\"\n") == true)
    #expect(spy.calls.last?.contains("whose smart is false and special kind is none") == true)

    spy.reply = list(["true", "false", "all"])
    #expect(music.fetchMenuState() == MusicMenuState(favorited: true, shuffle: false, repeatMode: .all))
    spy.reply = list(["none", "true", "off"])
    #expect(music.fetchMenuState() == MusicMenuState(favorited: nil, shuffle: true, repeatMode: .off))
}

@Test func spotifyMenuStateAndCommands() {
    let spy = SpyRunner()
    let spotify = MusicController(source: .spotify, isMusicRunning: { true }, runner: spy)
    spy.reply = list(["true", "true"])
    #expect(spotify.fetchMenuState() == MusicMenuState(favorited: nil, shuffle: true, repeatMode: .all))
    #expect(spotify.fetchPlaylists().isEmpty)
    spotify.setShuffle(false)
    spotify.setRepeat(.one)
    #expect(spy.calls.suffix(2) == ["tell application \"Spotify\" to set shuffling to false",
                                    "tell application \"Spotify\" to set repeating to true"])
    // Apple Music-only commands send nothing to Spotify.
    let before = spy.calls.count
    spotify.setFavorited(true)
    #expect(spotify.addToLibrary() == .failed)
    #expect(spotify.addToPlaylist("x") == .failed)
    #expect(spy.calls.count == before)
}

@Test func appleMusicCommands() {
    let spy = SpyRunner()
    let music = MusicController(isMusicRunning: { true }, runner: spy)
    music.setShuffle(true)
    music.setRepeat(.one)
    #expect(spy.calls == ["tell application \"Music\" to set shuffle enabled to true",
                          "tell application \"Music\" to set song repeat to one"])
    spy.reply = NSAppleEventDescriptor(string: "already")
    #expect(music.addToPlaylist("80's \"best\"") == .alreadyThere)
    #expect(spy.calls.last?.contains("first user playlist whose name is \"80's \\\"best\\\"\"") == true)
    spy.reply = NSAppleEventDescriptor(string: "added")
    #expect(music.addToLibrary() == .added)
    spy.reply = nil
    #expect(music.addToLibrary() == .failed)
}

@Test func menuCommandsAreDroppedWhenAppIsNotRunning() {
    let spy = SpyRunner()
    let music = MusicController(isMusicRunning: { false }, runner: spy)
    #expect(music.fetchPlaylists().isEmpty)
    #expect(music.fetchMenuState() == MusicMenuState())
    music.setShuffle(true)
    music.reveal()
    #expect(music.addToPlaylist("x") == .failed)
    #expect(spy.calls.isEmpty)
}
