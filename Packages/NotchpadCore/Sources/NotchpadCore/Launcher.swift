import Combine
import Foundation

/// One icon on the Shortcuts widget: an app, a shortcut from the Shortcuts app, or a folder.
public struct LauncherItem: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case app, shortcut, folder
    }

    public var id: UUID
    public var kind: Kind
    /// App or folder path, or the shortcut's name.
    public var target: String
    public var title: String

    public init(id: UUID = UUID(), kind: Kind, target: String, title: String) {
        self.id = id; self.kind = kind; self.target = target; self.title = title
    }
}

/// The Shortcuts widget's icons, saved as JSON. One list for every Shortcuts widget.
@MainActor
public final class LauncherStore: ObservableObject {
    @Published public private(set) var items: [LauncherItem] = []
    private let storageURL: URL

    public init(storageURL: URL) {
        self.storageURL = storageURL
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([LauncherItem].self, from: data) {
            items = saved
        }
    }

    /// Adds an icon at the end. False (nothing added) when the same app, shortcut or folder is already there.
    @discardableResult
    public func add(_ kind: LauncherItem.Kind, target: String, title: String) -> Bool {
        guard !items.contains(where: { $0.kind == kind && $0.target == target }) else { return false }
        items.append(LauncherItem(kind: kind, target: target, title: title))
        save()
        return true
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    /// For demo screenshots: replaces the list without saving.
    public func setForDemo(_ demo: [LauncherItem]) {
        items = demo
    }

    private func save() {
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(items).write(to: storageURL, options: .atomic)
    }
}

/// The `shortcuts` command-line tool that comes with macOS.
public enum ShortcutsCLI {
    public static let path = "/usr/bin/shortcuts"

    /// `shortcuts list` prints one name per line: trimmed, empty lines and repeats dropped, order kept.
    public static func parseList(_ output: Data) -> [String] {
        var seen = Set<String>()
        return String(decoding: output, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public static func runArguments(_ name: String) -> [String] { ["run", name] }
}

/// Files dropped on a folder icon are copied in; nothing is overwritten.
public enum FileDrop {
    /// "Report.pdf", or the first free "Report 2.pdf", "Report 3.pdf"… (Finder's numbering).
    public static func destination(for file: URL, in folder: URL, exists: (URL) -> Bool) -> URL {
        let name = file.lastPathComponent
        let first = folder.appendingPathComponent(name)
        guard exists(first) else { return first }
        let ext = file.pathExtension
        let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        var n = 2
        while true {
            let candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            if !exists(candidate) { return candidate }
            n += 1
        }
    }

    /// Copies each file (or folder) into `folder`. Returns where the copies went. Call it off the main thread.
    public static func copy(_ files: [URL], into folder: URL) -> [URL] {
        let fm = FileManager.default
        var done: [URL] = []
        for file in files where file.isFileURL {
            let target = destination(for: file, in: folder) { fm.fileExists(atPath: $0.path) }
            if (try? fm.copyItem(at: file, to: target)) != nil { done.append(target) }
        }
        return done
    }
}
