import Foundation
import Testing
@testable import NotchpadCore

// MARK: Update check

@Test func versionComparison() {
    #expect(UpdateCheck.isNewer("1.4.0", than: "1.3.0"))
    #expect(UpdateCheck.isNewer("v1.10.0", than: "1.9.2"))
    #expect(UpdateCheck.isNewer("2.0", than: "1.9.9"))
    #expect(!UpdateCheck.isNewer("1.3.0", than: "1.3.0"))
    #expect(!UpdateCheck.isNewer("1.2.9", than: "1.3.0"))
    #expect(!UpdateCheck.isNewer("nonsense", than: "1.3.0"))
}

@Test func parsesLatestRelease() {
    let json = Data(#"{"tag_name":"v1.4.0","html_url":"https://github.com/alperengokbak/notchpad/releases/tag/v1.4.0","draft":false}"#.utf8)
    let latest = UpdateCheck.parseLatest(json)
    #expect(latest?.version == "1.4.0")
    #expect(latest?.url.absoluteString == "https://github.com/alperengokbak/notchpad/releases/tag/v1.4.0")
    #expect(UpdateCheck.parseLatest(Data("{}".utf8)) == nil)
}

@Test func checksAtMostOnceADay() {
    let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
    #expect(UpdateCheck.isDue(lastCheck: nil, now: now))
    #expect(!UpdateCheck.isDue(lastCheck: now.addingTimeInterval(-3600), now: now))
    #expect(UpdateCheck.isDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now))
}

// MARK: Clipboard

@Test func clipboardMovesRepeatsToTopAndKeeps30() {
    var h = ClipboardHistory()
    for i in 1...35 { h.add(text: "item \(i)", now: Date()) }
    #expect(h.entries.count == ClipboardHistory.limit)
    #expect(h.entries.first?.text == "item 35")
    h.add(text: "item 20", now: Date())
    #expect(h.entries.first?.text == "item 20")
    #expect(h.entries.filter { $0.text == "item 20" }.count == 1)
    h.add(text: "   ", now: Date())          // blank copies are ignored
    #expect(h.entries.first?.text == "item 20")
}

@Test func clipboardSkipsSecretsAndAppGeneratedCopies() {
    #expect(ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
    #expect(ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text", "org.nspasteboard.TransientType"]))
    #expect(ClipboardHistory.shouldSkip(types: ["com.agilebits.onepassword"]))
    #expect(!ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"]))
}

@Test func clipboardSavesOnlyText() throws {
    var h = ClipboardHistory()
    h.add(text: "hello", now: Date())
    h.add(imageData: Data([1, 2, 3]), now: Date())
    let saved = try JSONEncoder().encode(h.forSaving)
    let back = try JSONDecoder().decode([ClipEntry].self, from: saved)
    #expect(back.map(\.text) == ["hello"])
    var h2 = ClipboardHistory()
    h2.add(text: "a", now: Date())
    h2.remove(h2.entries[0].id)
    #expect(h2.entries.isEmpty)
}

// MARK: Recent files

@Test func recentFilesKeepOnlyOrdinaryFiles() {
    let home = "/Users/someone"
    #expect(RecentFiles.keep(path: "\(home)/Documents/Report.docx", isFolder: false, isApp: false, home: home))
    #expect(!RecentFiles.keep(path: "\(home)/Library/Caches/x.db", isFolder: false, isApp: false, home: home))
    #expect(!RecentFiles.keep(path: "\(home)/.config/settings.json", isFolder: false, isApp: false, home: home))
    #expect(!RecentFiles.keep(path: "/Applications/Safari.app", isFolder: false, isApp: true, home: home))
    #expect(!RecentFiles.keep(path: "\(home)/Downloads", isFolder: true, isApp: false, home: home))
}

@Test func recentFilesRelativeTime() {
    let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
    #expect(RecentFiles.ago(now.addingTimeInterval(-20), now: now) == "Just now")
    #expect(RecentFiles.ago(now.addingTimeInterval(-5 * 60), now: now) == "5 min ago")
    #expect(RecentFiles.ago(now.addingTimeInterval(-2 * 3600), now: now) == "2 h ago")
    #expect(RecentFiles.ago(now.addingTimeInterval(-30 * 3600), now: now) == "Yesterday")
    #expect(RecentFiles.ago(now.addingTimeInterval(-3 * 86400), now: now) == "3 days ago")
}

// MARK: Reorder Shortcuts

@MainActor @Test func launcherMoveReordersAndPersists() {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("np-move-\(UUID().uuidString)/launcher.json")
    let store = LauncherStore(storageURL: file)
    for t in ["A", "B", "C", "D"] { store.add(.app, target: "/\(t).app", title: t) }
    let d = store.items[3].id
    store.move(d, to: 0)
    #expect(store.items.map(\.title) == ["D", "A", "B", "C"])
    let a = store.items[1].id
    store.move(a, to: 3)
    #expect(store.items.map(\.title) == ["D", "B", "C", "A"])
    #expect(LauncherStore(storageURL: file).items.map(\.title) == ["D", "B", "C", "A"])
}

// MARK: Progress bar on play/pause

@Test func pauseKeepsTheSongsPosition() {
    let t0 = Date(timeIntervalSinceReferenceDate: 5000)
    let playing = NowPlaying(title: "Song", artist: "Band", duration: 200, position: 30, isPlaying: true, positionDate: t0)
    // Apple Music's pause notification carries no position (0); the bar must not jump back.
    let paused = NowPlaying(title: "Song", artist: "Band", duration: 200, position: 0, isPlaying: false,
                            positionDate: t0.addingTimeInterval(10))
    let kept = paused.carryingPosition(from: playing, now: t0.addingTimeInterval(10))
    #expect(kept.position == 40)
    #expect(!kept.isPlaying)
    // A different song really starts at 0.
    let other = NowPlaying(title: "Other", artist: "Band", duration: 200, position: 0, isPlaying: true, positionDate: t0)
    #expect(other.carryingPosition(from: playing, now: t0.addingTimeInterval(10)).position == 0)
    // A notification that does carry a position (Spotify) wins.
    let spotify = NowPlaying(title: "Song", artist: "Band", duration: 200, position: 55, isPlaying: false, positionDate: t0)
    #expect(spotify.carryingPosition(from: playing, now: t0.addingTimeInterval(10)).position == 55)
}

@Test func newWidgetsInCatalog() {
    #expect(WidgetKind.clipboard.title == "Clipboard")
    #expect(WidgetKind.clipboard.sizes == [.medium, .wide, .full])
    #expect(WidgetKind.recentFiles.title == "Recent files")
    #expect(WidgetKind.recentFiles.dataSources == [.recentFiles])
    #expect(WidgetKind.clipboard.category == .productivity && WidgetKind.recentFiles.category == .productivity)
}

// MARK: Security hardening

@Test func onlyNotchpadReleasePagesAreOpened() {
    #expect(UpdateCheck.isTrustedReleasePage(URL(string: "https://github.com/alperengokbak/notchpad/releases/tag/v1.6.0")!))
    #expect(!UpdateCheck.isTrustedReleasePage(URL(string: "http://github.com/alperengokbak/notchpad/releases/tag/v1.6.0")!))
    #expect(!UpdateCheck.isTrustedReleasePage(URL(string: "https://evil.example/alperengokbak/notchpad/releases")!))
    #expect(!UpdateCheck.isTrustedReleasePage(URL(string: "https://github.com.evil.example/alperengokbak/notchpad/releases")!))
    #expect(!UpdateCheck.isTrustedReleasePage(URL(string: "https://github.com/someone/else/releases/tag/v9")!))
    #expect(!UpdateCheck.isTrustedReleasePage(URL(string: "file:///Applications/Calculator.app")!))
}

@Test func copiesInPasswordManagersAreSkipped() {
    #expect(ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"], frontApp: "com.1password.1password"))
    #expect(ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"], frontApp: "com.bitwarden.desktop"))
    #expect(ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"], frontApp: "com.apple.Passwords"))
    #expect(ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"], frontApp: "com.apple.keychainaccess"))
    #expect(!ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"], frontApp: "com.apple.Safari"))
    #expect(!ClipboardHistory.shouldSkip(types: ["public.utf8-plain-text"], frontApp: nil))
}
