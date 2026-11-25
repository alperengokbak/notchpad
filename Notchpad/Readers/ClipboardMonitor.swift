import AppKit
import Combine
import NotchpadCore

/// Keeps the last 30 copies. macOS has no "clipboard changed" notification, so it looks at the
/// clipboard's change counter a little more than once a second, and only while a Clipboard widget
/// is on one of his tabs. Text is saved to disk (Application Support/Notchpad/clipboard.json);
/// pictures stay in memory until Notchpad quits.
@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var history = ClipboardHistory()
    @Published private(set) var copiedID: UUID?
    private let storageURL: URL
    private let saves: Bool
    private var timer: Timer?
    private var lastChange = NSPasteboard.general.changeCount
    private var ownChange: Int?

    init(storageURL: URL, saves: Bool) {
        self.storageURL = storageURL
        self.saves = saves
        if saves, let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode([ClipEntry].self, from: data) {
            history = ClipboardHistory(entries: saved)
        }
    }

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        lastChange = NSPasteboard.general.changeCount
        let t = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        t.tolerance = 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t
        DebugTools.log("clipboard: watching")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        DebugTools.log("clipboard: stopped")
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        if ownChange == pb.changeCount { return } // our own "copy again"
        let types = (pb.types ?? []).map(\.rawValue)
        guard !ClipboardHistory.shouldSkip(types: types) else { DebugTools.log("clipboard: skipped a secret"); return }
        if let text = pb.string(forType: .string) {
            history.add(text: text, now: Date())
        } else if let image = NSImage(pasteboard: pb), let data = Self.smallPNG(image) {
            history.add(imageData: data, now: Date())
        } else {
            return
        }
        DebugTools.log("clipboard: \(history.entries.count) items")
        save()
    }

    /// Click on an entry: put it back on the clipboard.
    func copyAgain(_ entry: ClipEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = entry.text {
            pb.setString(text, forType: .string)
        } else if let data = entry.imageData, let image = NSImage(data: data) {
            pb.writeObjects([image])
        }
        ownChange = pb.changeCount
        copiedID = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.copiedID == entry.id { self?.copiedID = nil }
        }
    }

    func remove(_ id: UUID) { history.remove(id); save() }
    func clear() { history.clear(); save() }

    /// For demo screenshots: made-up entries, never saved.
    func setForDemo(_ entries: [ClipEntry]) { history = ClipboardHistory(entries: entries) }

    private func save() {
        guard saves else { return }
        try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(history.forSaving).write(to: storageURL, options: .atomic)
    }

    /// A copied picture, shrunk to at most 600 px so 30 of them stay small.
    private static func smallPNG(_ image: NSImage) -> Data? {
        let maxSide: CGFloat = 600
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let small = NSImage(size: target, flipped: false) { rect in image.draw(in: rect); return true }
        guard let tiff = small.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
