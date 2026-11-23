import Foundation

/// Reads and writes the panel layout. A missing or broken file gives the default layout;
/// a broken file is first moved aside as `layout-broken-<date>.json` so a later save can't destroy it.
public final class LayoutStore {
    private let fileURL: URL
    private let makeDefault: () -> PanelLayout
    /// True when the last `load()` found a file it couldn't read.
    public private(set) var lastLoadFailed = false
    /// Where the last broken file was moved to, if it was.
    public private(set) var lastBackupURL: URL?

    public init(fileURL: URL, makeDefault: @escaping () -> PanelLayout = { .makeDefault() }) {
        self.fileURL = fileURL
        self.makeDefault = makeDefault
    }

    public func load() -> PanelLayout {
        lastLoadFailed = false
        lastBackupURL = nil
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return makeDefault() }
        guard let data = try? Data(contentsOf: fileURL),
              let layout = try? JSONDecoder().decode(PanelLayout.self, from: data) else {
            lastLoadFailed = true
            moveAside()
            return makeDefault()
        }
        return layout.validated()
    }

    private func moveAside() {
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        let backup = fileURL.deletingLastPathComponent()
            .appendingPathComponent("layout-broken-\(stamp.string(from: Date())).json")
        if (try? FileManager.default.moveItem(at: fileURL, to: backup)) != nil { lastBackupURL = backup }
    }

    public func save(_ layout: PanelLayout) {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layout) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
