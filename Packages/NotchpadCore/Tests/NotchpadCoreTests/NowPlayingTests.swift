import Foundation
import Testing
@testable import NotchpadCore

private let t0 = Date(timeIntervalSinceReferenceDate: 0)

@Test func parsesPlayerInfo() {
    let n = NowPlaying.from(playerInfo: ["Name": "Song", "Artist": "Band", "Player State": "Playing",
                                         "Total Time": 215000], now: t0)!
    #expect(n.title == "Song")
    #expect(n.artist == "Band")
    #expect(n.duration == 215)
    #expect(n.isPlaying)
}

@Test func pausedIsNotPlaying() {
    #expect(NowPlaying.from(playerInfo: ["Name": "Song", "Player State": "Paused"], now: t0)?.isPlaying == false)
}

@Test func stoppedIsNil() {
    #expect(NowPlaying.from(playerInfo: ["Name": "Song", "Player State": "Stopped"], now: t0) == nil)
    #expect(NowPlaying.from(playerInfo: ["Player State": "Playing"], now: t0) == nil)
}

@Test func positionAdvancesOnlyWhilePlaying() {
    var n = NowPlaying(title: "S", artist: "A", duration: 12, position: 10, isPlaying: true, positionDate: t0)
    #expect(n.position(at: t0.addingTimeInterval(1)) == 11)
    #expect(n.position(at: t0.addingTimeInterval(5)) == 12)
    n.isPlaying = false
    #expect(n.position(at: t0.addingTimeInterval(5)) == 10)
}

@Test func coverComesBackAfterSkippingAwayAndBack() {
    var cache = CoverCache()
    cache.stored(for: "A")
    #expect(!cache.needsFetch(for: "A"))
    do { let r = cache.songChanged(to: "B"); #expect(r) }   // paused skip to B: the A cover is dropped
    do { let r = cache.songChanged(to: "A"); #expect(r) }   // back to A: still no cover on screen
    #expect(cache.needsFetch(for: "A"))      // so playing A again must fetch it
}

@Test func coverKeptWhileSameSongPlays() {
    var cache = CoverCache()
    cache.stored(for: "A")
    do { let r = cache.songChanged(to: "A"); #expect(!r) }  // play/pause of the same song keeps the cover
    #expect(!cache.needsFetch(for: "A"))
    #expect(!cache.needsFetch(for: nil))
}
