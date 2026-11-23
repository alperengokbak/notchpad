import Foundation
import Testing
@testable import NotchpadCore

@Test func musicSourceNames() {
    #expect(MusicSource.appleMusic.bundleID == "com.apple.Music")
    #expect(MusicSource.spotify.bundleID == "com.spotify.client")
    #expect(MusicSource.appleMusic.appName == "Music")
    #expect(MusicSource.spotify.appName == "Spotify")
    #expect(MusicSource.appleMusic.title == "Apple Music")
    #expect(MusicSource.spotify.notificationName == "com.spotify.client.PlaybackStateChanged")
    #expect(MusicSource.appleMusic.notificationName == "com.apple.Music.playerInfo")
}

@Test func parsesSpotifyNotification() {
    let now = Date()
    let info: [AnyHashable: Any] = ["Name": "Song", "Artist": "Band", "Duration": NSNumber(value: 215_500),
                                    "Playback Position": NSNumber(value: 12.5), "Player State": "Playing"]
    let n = NowPlaying.from(playerInfo: info, source: .spotify, now: now)
    #expect(n == NowPlaying(title: "Song", artist: "Band", duration: 215.5, position: 12.5, isPlaying: true, positionDate: now))
    #expect(NowPlaying.from(playerInfo: ["Name": "Song", "Player State": "Stopped"], source: .spotify, now: now) == nil)
}

@Test func appleMusicNotificationStillParses() {
    let now = Date()
    let info: [AnyHashable: Any] = ["Name": "Song", "Artist": "Band", "Total Time": NSNumber(value: 200_000), "Player State": "Paused"]
    #expect(NowPlaying.from(playerInfo: info, source: .appleMusic, now: now)
        == NowPlaying(title: "Song", artist: "Band", duration: 200, position: 0, isPlaying: false, positionDate: now))
}

@Test func spotifyControllerTalksToSpotify() {
    let spy = SpyRunner()
    MusicController(source: .spotify, isMusicRunning: { true }, runner: spy).send(.playPause)
    #expect(spy.calls == ["tell application \"Spotify\" to playpause"])
}

@Test func spotifyDurationIsMilliseconds() {
    let spy = SpyRunner()
    let list = NSAppleEventDescriptor.list()
    list.insert(NSAppleEventDescriptor(string: "Song"), at: 1)
    list.insert(NSAppleEventDescriptor(string: "Band"), at: 2)
    list.insert(NSAppleEventDescriptor(double: 215_500), at: 3)
    list.insert(NSAppleEventDescriptor(string: "playing"), at: 4)
    list.insert(NSAppleEventDescriptor(double: 30), at: 5)
    spy.reply = list
    let n = MusicController(source: .spotify, isMusicRunning: { true }, runner: spy).fetchNowPlaying(now: Date())
    #expect(n?.duration == 215.5)
    #expect(n?.position == 30)
    #expect(n?.isPlaying == true)
}

@Test func spotifyArtworkIsAURL() {
    let spy = SpyRunner()
    spy.reply = NSAppleEventDescriptor(string: "https://i.scdn.co/image/abc")
    let c = MusicController(source: .spotify, isMusicRunning: { true }, runner: spy)
    #expect(c.fetchArtworkURL() == URL(string: "https://i.scdn.co/image/abc"))
    #expect(spy.calls == ["tell application \"Spotify\" to get artwork url of current track"])
    #expect(c.fetchArtwork() == nil)  // Spotify has no raw artwork data
}

@Test func isRunningChecksTheRightBundle() {
    #expect(MusicController.isRunning(.spotify, among: [("com.spotify.client", false)]))
    #expect(!MusicController.isRunning(.spotify, among: [("com.apple.Music", false)]))
    #expect(!MusicController.isRunning(.spotify, among: [("com.spotify.client", true)]))
}

@Test func followsWhicheverIsPlaying() {
    // Playing wins.
    #expect(PlayerFollower.choose(current: .appleMusic, playing: [.spotify], running: [.appleMusic, .spotify]) == .spotify)
    // Both playing: keep the current one (no flapping).
    #expect(PlayerFollower.choose(current: .spotify, playing: [.appleMusic, .spotify], running: [.appleMusic, .spotify]) == .spotify)
    // Both paused: the last one stays.
    #expect(PlayerFollower.choose(current: .spotify, playing: [], running: [.appleMusic, .spotify]) == .spotify)
    // The current one quit, the other is open: switch to the open one.
    #expect(PlayerFollower.choose(current: .spotify, playing: [], running: [.appleMusic]) == .appleMusic)
    // Nothing open: keep the last one (so its "Open" button opens the right app).
    #expect(PlayerFollower.choose(current: .spotify, playing: [], running: []) == .spotify)
}

@Test func preferencesDefaultsAndPersistence() {
    let suite = "notchpad-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var prefs = Preferences(defaults: defaults)
    #expect(prefs.showMicIndicator)
    #expect(prefs.lastMusicSource == nil)
    prefs.showMicIndicator = false
    prefs.lastMusicSource = .spotify
    let again = Preferences(defaults: defaults)
    #expect(!again.showMicIndicator)
    #expect(again.lastMusicSource == .spotify)
}
