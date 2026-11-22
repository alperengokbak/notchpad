import Combine
import Foundation

/// A file waiting on the shelf: a bookmark to the original, not a copy.
public struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bookmark: Data
    public var name: String
}

/// The shelf's files, saved as JSON so they survive a restart.
/// Bookmarks are resolved once (on load, add and `refresh()`), never while drawing,
/// and never mount a volume or show UI.
@MainActor
public final class ShelfStore: ObservableObject {
    @Published public private(set) var items: [ShelfItem] = []
    private var resolved: [UUID: URL] = [:]
    private let storageURL: URL

    public init(storageURL: URL) {
        self.storageURL = storageURL
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            items = saved
            refresh()
        }
    }

    /// Adds file URLs, skipping non-files and files already on the shelf.
    public func add(_ urls: [URL]) {
        var known = Set(resolved.values.map { $0.standardizedFileURL.path })
        for url in urls where url.isFileURL {
            let path = url.standardizedFileURL.path
            guard !known.contains(path), let data = try? url.bookmarkData() else { continue }
            let item = ShelfItem(id: UUID(), bookmark: data, name: url.lastPathComponent)
            items.append(item)
            resolved[item.id] = url
            known.insert(path)
        }
        save()
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        resolved[id] = nil
        save()
    }

    public func clear() {
        items.removeAll()
        resolved.removeAll()
        save()
    }

    /// Called when a drag out of the shelf ends. Removes the item only if some app took it.
    public func dragEnded(_ id: UUID, accepted: Bool) {
        if accepted { remove(id) }
    }

    /// The file's current location, or nil while its disk is disconnected.
    public func url(for id: UUID) -> URL? { resolved[id] }

    /// Every file that can be used right now, in shelf order (skips files on a disconnected disk).
    public func availableURLs() -> [URL] { items.compactMap { resolved[$0.id] } }

    /// Re-checks every file: drops deleted or trashed ones, follows moves and renames,
    /// keeps files on a disconnected disk (they come back when it's plugged in).
    public func refresh() {
        let before = items
        var kept: [ShelfItem] = []
        resolved.removeAll()
        for item in items {
            switch Self.resolve(item.bookmark) {
            case .gone:
                continue
            case .offline:
                kept.append(item)
            case .available(let url, let stale):
                var updated = item
                updated.name = url.lastPathComponent
                if stale, let fresh = try? url.bookmarkData() { updated.bookmark = fresh }
                resolved[item.id] = url
                kept.append(updated)
            }
        }
        items = kept
        if items != before { save() }
    }

    private enum Resolution { case available(URL, stale: Bool), offline, gone }

    private static func resolve(_ bookmark: Data) -> Resolution {
        var stale = false
        if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &stale) {
            let exists = FileManager.default.fileExists(atPath: url.path)
            return exists && !isInTrash(url) ? .available(url, stale: stale) : .gone
        }
        // Couldn't resolve: if the file's disk isn't mounted, it's only offline.
        let values = URL.resourceValues(forKeys: [.volumeURLKey], fromBookmarkData: bookmark)
        if let volume = values?.volume, !FileManager.default.fileExists(atPath: volume.path) { return .offline }
        return .gone
    }

    /// Finder's Trash is "~/.Trash", or ".Trashes/<uid>" on other disks.
    static func isInTrash(_ url: URL) -> Bool {
        url.standardizedFileURL.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? JSONEncoder().encode(items).write(to: storageURL, options: .atomic)
    }
}
