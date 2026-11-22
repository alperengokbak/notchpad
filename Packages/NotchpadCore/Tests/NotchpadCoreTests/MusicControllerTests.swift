import Foundation
import Testing
@testable import NotchpadCore

final class SpyRunner: ScriptRunning, @unchecked Sendable {
    var calls: [String] = []
    var reply: NSAppleEventDescriptor?
    func run(_ source: String) -> NSAppleEventDescriptor? { calls.append(source); return reply }
}

@Test func musicCommandsAreDroppedWhenMusicIsNotRunning() {
    let spy = SpyRunner()
    let c = MusicController(isMusicRunning: { false }, runner: spy)
    c.send(.playPause)
    c.send(.next)
    c.send(.previous)
    #expect(c.fetchPosition() == nil)
    #expect(c.fetchArtwork() == nil)
    #expect(spy.calls.isEmpty)
}

@Test func sendsCommandWhenRunning() {
    let spy = SpyRunner()
    MusicController(isMusicRunning: { true }, runner: spy).send(.next)
    #expect(spy.calls == ["tell application \"Music\" to next track"])
}

@Test func fetchPositionReadsDouble() {
    let spy = SpyRunner()
    spy.reply = NSAppleEventDescriptor(double: 42.5)
    #expect(MusicController(isMusicRunning: { true }, runner: spy).fetchPosition() == 42.5)
    #expect(spy.calls == ["tell application \"Music\" to get player position"])
}

@Test func fetchNowPlayingParsesList() {
    let spy = SpyRunner()
    let list = NSAppleEventDescriptor.list()
    list.insert(NSAppleEventDescriptor(string: "Song"), at: 1)
    list.insert(NSAppleEventDescriptor(string: "Band"), at: 2)
    list.insert(NSAppleEventDescriptor(double: 215.5), at: 3)
    list.insert(NSAppleEventDescriptor(string: "playing"), at: 4)
    list.insert(NSAppleEventDescriptor(double: 30), at: 5)
    spy.reply = list
    let t = Date(timeIntervalSinceReferenceDate: 0)
    let n = MusicController(isMusicRunning: { true }, runner: spy).fetchNowPlaying(now: t)
    #expect(n == NowPlaying(title: "Song", artist: "Band", duration: 215.5, position: 30, isPlaying: true, positionDate: t))
}

@Test func fetchNowPlayingNilWhenStoppedOrNotRunning() {
    let spy = SpyRunner()
    #expect(MusicController(isMusicRunning: { false }, runner: spy).fetchNowPlaying(now: Date()) == nil)
    #expect(spy.calls.isEmpty)
    spy.reply = nil // Music answers nothing when stopped
    #expect(MusicController(isMusicRunning: { true }, runner: spy).fetchNowPlaying(now: Date()) == nil)
}

@Test func terminatedMusicDoesNotCountAsRunning() {
    #expect(MusicController.isRunning(among: [("com.apple.Music", false)]))
    #expect(!MusicController.isRunning(among: [("com.apple.Music", true)]))
    #expect(!MusicController.isRunning(among: [("com.apple.Safari", false), (nil, false)]))
}

@Test func stoppedNotificationNeverTriggersAQuery() {
    #expect(!MusicController.shouldQuery(afterPlayerInfo: ["Name": "Song", "Player State": "Stopped"]))
    #expect(!MusicController.shouldQuery(afterPlayerInfo: ["Player State": "Playing"]))
    #expect(MusicController.shouldQuery(afterPlayerInfo: ["Name": "Song", "Player State": "Paused"]))
}
