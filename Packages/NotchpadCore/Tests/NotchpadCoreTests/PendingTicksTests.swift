import Testing
@testable import NotchpadCore

@Test func reTickGetsAFullUndoWindow() {
    var ticks = PendingTicks()
    let first = ticks.tick("r1")
    ticks.untick("r1")
    let second = ticks.tick("r1")
    // The first tick's timer fires: it must not complete the reminder (that was undone).
    #expect(!ticks.shouldCommit("r1", token: first))
    #expect(ticks.shouldCommit("r1", token: second))
}

@Test func untickedNeverCommits() {
    var ticks = PendingTicks()
    let t = ticks.tick("r1")
    ticks.untick("r1")
    #expect(!ticks.shouldCommit("r1", token: t))
    #expect(!ticks.contains("r1"))
}

@Test func commitRemovesThePendingTick() {
    var ticks = PendingTicks()
    let t = ticks.tick("r1")
    #expect(ticks.contains("r1"))
    let committed = ticks.commit("r1", token: t)
    #expect(committed)
    #expect(!ticks.contains("r1"))
}
