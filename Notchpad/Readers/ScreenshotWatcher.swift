import Foundation

/// Spots new screenshots (macOS marks them with kMDItemIsScreenCapture), wherever they're saved.
/// A live Spotlight query; runs only while "Add new screenshots to the shelf" is on.
@MainActor
final class ScreenshotWatcher {
    var onNew: (([URL]) -> Void)?
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?

    var isRunning: Bool { query != nil }

    func start() {
        guard query == nil else { return }
        let q = NSMetadataQuery()
        q.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1 AND kMDItemFSCreationDate >= %@", Date() as NSDate)
        q.searchScopes = [NSMetadataQueryUserHomeScope]
        query = q
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: q, queue: .main) { [weak self] note in
            let added = (note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]) ?? []
            let urls = added.compactMap { ($0.value(forAttribute: NSMetadataItemPathKey) as? String).map(URL.init(fileURLWithPath:)) }
            MainActor.assumeIsolated {
                guard !urls.isEmpty else { return }
                DebugTools.log("screenshots: \(urls.count) new")
                self?.onNew?(urls)
            }
        }
        q.start()
        DebugTools.log("screenshots: watching")
    }

    func stop() {
        query?.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        query = nil
    }
}
