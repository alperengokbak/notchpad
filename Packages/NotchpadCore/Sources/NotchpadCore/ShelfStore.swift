import Combine
import Foundation

/// A file waiting on the shelf: a bookmark to the original, not a copy.
public struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bookmark: Data
    public var name: String
}

/// The shelf's files, saved as JSON so they survive a restart.
@MainActor
public final class ShelfStore: ObservableObject {
    @Published public private(set) var items: [ShelfItem] = []
    private let storageURL: URL

    public init(storageURL: URL) {
        self.storageURL = storageURL
        load()
    }

    /// Adds file URLs, skipping non-files and files already on the shelf.
    public func add(_ urls: [URL]) {
        var known = Set(items.compactMap { url(for: $0.id)?.standardizedFileURL.path })
        for url in urls where url.isFileURL {
            let path = url.standardizedFileURL.path
            guard !known.contains(path), let data = try? url.bookmarkData() else { continue }
            items.append(ShelfItem(id: UUID(), bookmark: data, name: url.lastPathComponent))
            known.insert(path)
        }
        save()
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func clear() {
        items.removeAll()
        save()
    }

    /// Called when a drag out of the shelf ends. Removes the item only if some app took it.
    public func dragEnded(_ id: UUID, accepted: Bool) {
        if accepted { remove(id) }
    }

    public func url(for id: UUID) -> URL? {
        guard let item = items.first(where: { $0.id == id }) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: item.bookmark, bookmarkDataIsStale: &stale)
    }

    /// Loads saved items, drops deleted files, follows moved ones.
    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return }
        items = saved.compactMap { item in
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: item.bookmark, bookmarkDataIsStale: &stale),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            var updated = item
            updated.name = url.lastPathComponent
            if stale, let fresh = try? url.bookmarkData() { updated.bookmark = fresh }
            return updated
        }
        if items != saved { save() }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? JSONEncoder().encode(items).write(to: storageURL, options: .atomic)
    }
}
