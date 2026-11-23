import Foundation
import Testing
@testable import NotchpadCore

final class SpyCommands: CommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [[String]] = []
    var calls: [[String]] { lock.withLock { _calls } }
    var exitCode: Int32 = 0
    var output = Data(#"{"BackendState":"Stopped"}"#.utf8)
    var launchFails = false
    /// When set, `run` waits on it, so a test can hold a command "in progress".
    var gate: DispatchSemaphore?
    let started = DispatchSemaphore(value: 0)

    func run(_ executable: String, _ arguments: [String]) -> (exitCode: Int32, output: Data)? {
        lock.withLock { _calls.append(arguments) }
        started.signal()
        _ = gate?.wait(timeout: .now() + 2)
        return launchFails ? nil : (exitCode, output)
    }
}

@Test func missingCLIIsNotInstalled() {
    let spy = SpyCommands()
    let status = TailscaleController(runner: spy, cliExists: { false }).status()
    #expect(status == TailscaleStatus(state: .notInstalled, devices: []))
    #expect(spy.calls.isEmpty)
}

@Test func launchFailureOrTimeoutWithCLIPresentIsNotConnected() {
    // A hung or slow Tailscale must not say "isn't installed"; only a missing CLI does.
    let spy = SpyCommands()
    spy.launchFails = true
    #expect(TailscaleController(runner: spy, cliExists: { true }).status() == TailscaleStatus(state: .notConnected, devices: []))
}

@Test func statusRunsStatusJSON() {
    let spy = SpyCommands()
    #expect(TailscaleController(runner: spy, cliExists: { true }).status().state == .notConnected)
    #expect(spy.calls == [["status", "--json"]])
}

@Test func unparsableOutputIsNotConnected() {
    let spy = SpyCommands()
    spy.output = Data("error: something".utf8)
    #expect(TailscaleController(runner: spy, cliExists: { true }).status() == TailscaleStatus(state: .notConnected, devices: []))
}

@Test func connectRunsUpDisconnectRunsDown() {
    let spy = SpyCommands()
    let c = TailscaleController(runner: spy, cliExists: { true })
    #expect(c.setConnected(true))
    #expect(c.setConnected(false))
    #expect(spy.calls == [["up"], ["down"]])
}

@Test func failedCommandReturnsFalse() {
    let spy = SpyCommands()
    spy.exitCode = 1
    #expect(!TailscaleController(runner: spy, cliExists: { true }).setConnected(true))
}

@Test func secondCommandIgnoredWhileBusy() {
    let spy = SpyCommands()
    spy.gate = DispatchSemaphore(value: 0)
    let c = TailscaleController(runner: spy, cliExists: { true })
    let done = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var firstResult = false
    Thread { firstResult = c.setConnected(true); done.signal() }.start()
    spy.started.wait()
    #expect(!c.setConnected(true))
    spy.gate?.signal()
    done.wait()
    #expect(firstResult)
    #expect(spy.calls == [["up"]])
}

/// Answers like Tailscale: status fails until `ready`, then works.
final class StartingTailscale: CommandRunning, @unchecked Sendable {
    var ready = false
    var calls: [[String]] = []
    func run(_ executable: String, _ arguments: [String]) -> (exitCode: Int32, output: Data)? {
        calls.append(arguments)
        if arguments == ["status", "--json"] { return ready ? (0, Data(#"{"BackendState":"Stopped"}"#.utf8)) : nil }
        return (0, Data())
    }
}

@Test func connectSkipsLaunchWhenRunning() {
    let runner = StartingTailscale()
    runner.ready = true
    var launched = false
    let ok = TailscaleController(runner: runner, cliExists: { true })
        .connect(isAppRunning: { true }, launchApp: { launched = true }, sleep: { _ in })
    #expect(ok)
    #expect(!launched)
    #expect(runner.calls == [["up"]])
}

@Test func connectStartsTailscaleWhenNotRunning() {
    let runner = StartingTailscale()
    var naps = 0
    let ok = TailscaleController(runner: runner, cliExists: { true })
        .connect(isAppRunning: { false }, launchApp: {}, sleep: { _ in
            naps += 1
            if naps == 3 { runner.ready = true } // Tailscale answers after ~1.5 s
        })
    #expect(ok)
    #expect(runner.calls.last == ["up"])
    #expect(runner.calls.filter { $0 == ["status", "--json"] }.count == 4)
}

@Test func connectGivesUpAfter10s() {
    let runner = StartingTailscale()
    var slept: TimeInterval = 0
    let ok = TailscaleController(runner: runner, cliExists: { true })
        .connect(isAppRunning: { false }, launchApp: {}, sleep: { slept += $0 })
    #expect(!ok)
    #expect(slept == 10)
    #expect(!runner.calls.contains(["up"]))
}

@Test func recognisesBothTailscaleVersions() {
    #expect(TailscaleController.isTailscaleApp("io.tailscale.ipn.macos"))   // App Store
    #expect(TailscaleController.isTailscaleApp("io.tailscale.ipn.macsys"))  // standalone download
    #expect(!TailscaleController.isTailscaleApp("dev.warp.Warp-Stable"))
    #expect(!TailscaleController.isTailscaleApp(nil))
}
