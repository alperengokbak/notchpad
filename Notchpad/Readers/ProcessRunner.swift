import Foundation
import NotchpadCore

/// Runs a command-line tool and collects its output. Gives up after 10 seconds.
/// Call it off the main thread.
struct ProcessRunner: CommandRunning {
    func run(_ executable: String, _ arguments: [String]) -> (exitCode: Int32, output: Data)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if finished.wait(timeout: .now() + 10) == .timedOut {
            process.terminate()
            return nil
        }
        return (process.terminationStatus, data)
    }
}
