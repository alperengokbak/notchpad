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
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }

        // Read on another thread, so a hung tool can't block us past the timeout.
        let box = OutputBox()
        let readDone = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            box.data = pipe.fileHandleForReading.readDataToEndOfFile()
            readDone.signal()
        }
        if finished.wait(timeout: .now() + 10) == .timedOut {
            process.terminate()
            return nil
        }
        _ = readDone.wait(timeout: .now() + 2)
        return (process.terminationStatus, box.data)
    }
}

private final class OutputBox: @unchecked Sendable {
    var data = Data()
}
