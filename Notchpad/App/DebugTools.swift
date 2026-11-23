import AppKit

/// Launch flags used for automated checks:
/// `--force-open` keeps the panel open, `--snapshot <path>` saves the panel as a PNG and quits,
/// `--log-state` prints "open"/"closed" to stdout on every change.
/// Layout checks: `--layout-file <path>` (never touches the real layout), `--tab <name or number>`,
/// `--drop-file <path>`, `--widget-sheet <png>`.
enum DebugTools {
    static func argument(after flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static let logState = CommandLine.arguments.contains("--log-state")

    static func log(_ line: String) {
        guard logState else { return }
        print(line)
        fflush(stdout)
    }

    @MainActor
    static func snapshot(_ view: NSView, to path: String) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
