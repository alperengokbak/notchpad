import Foundation
import Testing
@testable import NotchpadCore

private let t0 = Date(timeIntervalSinceReferenceDate: 5_000)

@Test func elapsedCountsFromWhenTheMicTurnedOn() {
    var m = MicActivity()
    #expect(!m.isActive)
    #expect(m.elapsed(now: t0) == nil)
    m.update(isRunning: true, now: t0)
    #expect(m.isActive)
    #expect(m.elapsed(now: t0.addingTimeInterval(252)) == 252)
}

@Test func repeatedOnKeepsTheOriginalStart() {
    var m = MicActivity()
    m.update(isRunning: true, now: t0)
    m.update(isRunning: true, now: t0.addingTimeInterval(60))
    #expect(m.elapsed(now: t0.addingTimeInterval(100)) == 100)
}

@Test func offClearsAndNextOnStartsFresh() {
    var m = MicActivity()
    m.update(isRunning: true, now: t0)
    m.update(isRunning: false, now: t0.addingTimeInterval(30))
    #expect(!m.isActive)
    m.update(isRunning: true, now: t0.addingTimeInterval(90))
    #expect(m.elapsed(now: t0.addingTimeInterval(100)) == 10)
}
