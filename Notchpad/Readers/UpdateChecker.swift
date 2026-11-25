import AppKit
import NotchpadCore

/// Asks GitHub for the latest Notchpad release. The only time Notchpad goes online.
enum UpdateChecker {
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Calls back on the main queue with the newer release, or nil (up to date, offline, or GitHub said no).
    static func check(completion: @escaping @MainActor ((version: String, url: URL)?, Bool) -> Void) {
        var request = URLRequest(url: UpdateCheck.latestReleaseAPI, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Notchpad", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            let latest = data.flatMap(UpdateCheck.parseLatest)
            // Only a newer version whose page is Notchpad's own release page on github.com counts.
            let newer = latest.flatMap {
                UpdateCheck.isNewer($0.version, than: currentVersion) && UpdateCheck.isTrustedReleasePage($0.url) ? $0 : nil
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(newer, ok && latest != nil) } }
        }.resume()
    }
}
