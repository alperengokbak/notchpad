import Foundation
import Testing
@testable import NotchpadCore

private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

@Test func startCountsDown() {
    var f = FocusTimer()
    #expect(!f.isActive)
    f.start(.focus, minutes: 25, now: t0)
    #expect(f.isActive)
    #expect(f.remaining(now: t0) == 1500)
    #expect(f.remaining(now: t0.addingTimeInterval(87)) == 1413)
    #expect(f.kind == .focus)
}

@Test func pauseFreezesResumeContinues() {
    var f = FocusTimer()
    f.start(.focus, minutes: 25, now: t0)
    f.pause(now: t0.addingTimeInterval(100))
    #expect(f.isPaused)
    #expect(f.remaining(now: t0.addingTimeInterval(900)) == 1400)
    f.resume(now: t0.addingTimeInterval(900))
    #expect(f.remaining(now: t0.addingTimeInterval(1000)) == 1300)
}

@Test func remainingUsesWallClock() {
    // The Mac sleeps 10 minutes; no ticks arrive, but the time still passes.
    var f = FocusTimer()
    f.start(.focus, minutes: 25, now: t0)
    #expect(f.remaining(now: t0.addingTimeInterval(600)) == 900)
}

@Test func tickFinishesOnceAtZero() {
    var f = FocusTimer()
    f.start(.rest, minutes: 5, now: t0)
    let early = f.tick(now: t0.addingTimeInterval(299))
    let atZero = f.tick(now: t0.addingTimeInterval(300))
    let again = f.tick(now: t0.addingTimeInterval(301))
    #expect(!early)
    #expect(atZero)
    #expect(!again)
    #expect(f.phase == .done(.rest))
    #expect(!f.isActive)
}

@Test func stopReturnsToIdle() {
    var f = FocusTimer()
    f.start(.focus, minutes: 50, now: t0)
    f.stop()
    #expect(f.phase == .idle)
    #expect(f.remaining(now: t0) == nil)
}

@Test func clockFormat() {
    #expect(FocusTimer.clock(0) == "0:00")
    #expect(FocusTimer.clock(59) == "0:59")
    #expect(FocusTimer.clock(1500) == "25:00")
    #expect(FocusTimer.clock(1452.4) == "24:13")
}
