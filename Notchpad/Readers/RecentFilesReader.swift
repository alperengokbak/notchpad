import AppKit
import NotchpadCore

/// A file he opened recently, from Spotlight's "last used" date.
struct RecentFile: Identifiable, Equatable {
    let url: URL
    let date: Date
    var id: String { url.path }
}

/// Asks Spotlight for files used in the last 7 days. Runs only while a Recent files widget is on screen.
@MainActor
final class RecentFilesReader {
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?
    private var completion: (([RecentFile]) -> Void)?

    func fetch(completion: @escaping ([RecentFile]) -> Void) {
        guard query == nil else { return }
        self.completion = completion
        let q = NSMetadataQuery()
        q.predicate = NSPredicate(format: "kMDItemLastUsedDate >= %@", Date().addingTimeInterval(-7 * 86400) as NSDate)
        q.searchScopes = [NSMetadataQueryUserHomeScope]
        q.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: false)]
        query = q
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: q,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finished() }
        }
        q.start()
    }

    private func finished() {
        guard let q = query else { return }
        q.disableUpdates()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var files: [RecentFile] = []
        for i in 0..<min(q.resultCount, 300) {
            guard let item = q.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  let date = item.value(forAttribute: "kMDItemLastUsedDate") as? Date else { continue }
            let types = item.value(forAttribute: "kMDItemContentTypeTree") as? [String] ?? []
            guard RecentFiles.keep(path: path, isFolder: types.contains("public.folder"),
                                   isApp: types.contains("com.apple.application-bundle"), home: home) else { continue }
            files.append(RecentFile(url: URL(fileURLWithPath: path), date: date))
            if files.count == 30 { break }
        }
        q.stop()
        if let o = observer { NotificationCenter.default.removeObserver(o) }
        observer = nil
        query = nil
        DebugTools.log("recent files: \(files.count)")
        let done = completion
        completion = nil
        done?(files)
    }
}
