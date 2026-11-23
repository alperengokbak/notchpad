import Foundation
import Testing
@testable import NotchpadCore

private func opened(at t: TimeInterval = 0) -> PanelStateMachine {
    var s = PanelStateMachine()
    s.pointer(inside: true, now: t)
    s.tick(now: t + 0.2)
    return s
}

@Test func opensAfterDelay() {
    var s = PanelStateMachine()
    s.pointer(inside: true, now: 0)
    s.tick(now: 0.1)
    #expect(!s.isOpen)
    s.tick(now: 0.16)
    #expect(s.isOpen)
}

@Test func briefPassDoesNotOpen() {
    var s = PanelStateMachine()
    s.pointer(inside: true, now: 0)
    s.pointer(inside: false, now: 0.1)
    s.tick(now: 0.5)
    #expect(!s.isOpen)
}

@Test func closesAfterDelayOutside() {
    var s = opened()
    #expect(s.isOpen)
    s.pointer(inside: false, now: 1)
    s.tick(now: 1.2)
    #expect(s.isOpen)
    s.tick(now: 1.31)
    #expect(!s.isOpen)
}

@Test func reEnteringCancelsClose() {
    var s = opened()
    s.pointer(inside: false, now: 1)
    s.pointer(inside: true, now: 1.2)
    s.tick(now: 2)
    #expect(s.isOpen)
}

@Test func staysOpenDuringShelfDrag() {
    var s = opened()
    s.setShelfDragActive(true, now: 0.5)
    s.pointer(inside: false, now: 1)
    s.tick(now: 5)
    #expect(s.isOpen)
    s.setShelfDragActive(false, now: 5)
    s.tick(now: 5.31)
    #expect(!s.isOpen)
}

@Test func endingShelfDragInsideKeepsItOpen() {
    var s = opened()
    s.setShelfDragActive(true, now: 0.5)
    s.setShelfDragActive(false, now: 1)
    s.tick(now: 5)
    #expect(s.isOpen)
}

@Test func fileDragOpensImmediately() {
    var s = PanelStateMachine()
    s.fileDragNearNotch(now: 0)
    #expect(s.isOpen)
}

@Test func forceOpenNeverCloses() {
    var s = PanelStateMachine()
    s.forceOpen = true
    s.tick(now: 0)
    #expect(s.isOpen)
    s.pointer(inside: false, now: 1)
    s.tick(now: 9)
    #expect(s.isOpen)
}

@Test func hasPendingDeadlineOnlyWhileWaiting() {
    var s = PanelStateMachine()
    #expect(!s.hasPendingDeadline)
    s.pointer(inside: true, now: 0)
    #expect(s.hasPendingDeadline)
    s.tick(now: 0.2)
    #expect(!s.hasPendingDeadline)
}

@Test func editingHoldsPanelOpen() {
    var s = opened()
    s.setEditing(true, now: 1)
    s.pointer(inside: false, now: 1)
    s.tick(now: 5)
    #expect(s.isOpen)
}

@Test func editingOpensClosedPanel() {
    var s = PanelStateMachine()
    s.setEditing(true, now: 0)
    #expect(s.isOpen)
}

@Test func endingEditOutsideSchedulesClose() {
    var s = opened()
    s.setEditing(true, now: 1)
    s.pointer(inside: false, now: 1)
    s.tick(now: 5)
    s.setEditing(false, now: 5)
    s.tick(now: 5.2)
    #expect(s.isOpen)
    s.tick(now: 5.31)
    #expect(!s.isOpen)
}
