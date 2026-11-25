import AppKit

/// Launch flags used for automated checks:
/// `--force-open` keeps the panel open, `--snapshot <path>` saves the panel as a PNG and quits,
/// `--log-state` prints "open"/"closed" to stdout on every change.
/// Layout checks: `--layout-file <path>` (never touches the real layout), `--tab <name or number>`,
/// `--drop-file <path>`, `--widget-sheet <png>`, `--edit`, `--gallery`, `--snapshot-gallery <png>`.
///
/// SECURITY: these flags exist only in Debug builds (tests, screenshots, launch videos). In the app people
/// download (Release) every flag is ignored. Otherwise any program could start Notchpad with, say,
/// `--force-open --snapshot <file>` and read the user's reminders and events through Notchpad's permissions.
enum DebugTools {
    #if DEBUG
    static let enabled = true
    #else
    static let enabled = false
    #endif

    static func argument(after flag: String) -> String? {
        guard enabled else { return nil }
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// True when the flag was passed, and only in Debug builds.
    static func flag(_ name: String) -> Bool {
        enabled && CommandLine.arguments.contains(name)
    }

    static let logState = flag("--log-state")

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
