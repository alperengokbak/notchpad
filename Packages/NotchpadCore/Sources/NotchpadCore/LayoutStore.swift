import Foundation

/// Reads and writes the panel layout. A missing or broken file gives the default layout.
public final class LayoutStore {
    private let fileURL: URL
    /// True when the last `load()` found a file it couldn't read.
    public private(set) var lastLoadFailed = false

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> PanelLayout {
        lastLoadFailed = false
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .makeDefault() }
        guard let data = try? Data(contentsOf: fileURL),
              let layout = try? JSONDecoder().decode(PanelLayout.self, from: data) else {
            lastLoadFailed = true
            return .makeDefault()
        }
        return layout.validated()
    }

    public func save(_ layout: PanelLayout) {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layout) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
