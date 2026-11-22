import Testing
@testable import NotchpadCore

@Test func onlyOneRefreshAtATime() {
    var gate = SingleFlight()
    let first = gate.tryStart()
    let whileRunning = gate.tryStart()
    gate.finish()
    let afterFinish = gate.tryStart()
    #expect(first)
    #expect(!whileRunning)
    #expect(afterFinish)
}
