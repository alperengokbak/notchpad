import Foundation

/// Runs a command-line tool. Nil means it couldn't be started at all.
public protocol CommandRunning: Sendable {
    func run(_ executable: String, _ arguments: [String]) -> (exitCode: Int32, output: Data)?
}

/// Talks to the command-line tool inside Tailscale.app. Call it off the main thread.
public final class TailscaleController: @unchecked Sendable {
    public static let cliPath = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

    private let runner: CommandRunning
    private let cliExists: () -> Bool
    private let lock = NSLock()
    private var busy = false

    public init(runner: CommandRunning,
                cliExists: @escaping () -> Bool = { FileManager.default.isExecutableFile(atPath: TailscaleController.cliPath) }) {
        self.runner = runner
        self.cliExists = cliExists
    }

    public func status() -> TailscaleStatus {
        guard cliExists() else { return TailscaleStatus(state: .notInstalled, devices: []) }
        // Installed but it didn't start or didn't answer in time: treat as not connected.
        guard let result = runner.run(Self.cliPath, ["status", "--json"]) else {
            return TailscaleStatus(state: .notConnected, devices: [])
        }
        return TailscaleStatus.parse(result.output) ?? TailscaleStatus(state: .notConnected, devices: [])
    }

    /// Runs `up` or `down`. Returns false if it failed, or if another connect/disconnect is still running.
    public func setConnected(_ on: Bool) -> Bool {
        guard lock.withLock({ busy ? false : { busy = true; return true }() }) else { return false }
        defer { lock.withLock { busy = false } }
        guard cliExists(), let result = runner.run(Self.cliPath, [on ? "up" : "down"]) else { return false }
        return result.exitCode == 0
    }
}
