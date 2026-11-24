import Foundation
import Testing
@testable import NotchpadCore

private func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("np-launch-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@MainActor @Test func launcherAddsSkipsDuplicatesAndPersists() {
    let file = tempDir().appendingPathComponent("launcher.json")
    let store = LauncherStore(storageURL: file)
    #expect(store.add(.app, target: "/System/Applications/Notes.app", title: "Notes"))
    #expect(store.add(.shortcut, target: "Morning routine", title: "Morning routine"))
    #expect(store.add(.folder, target: "/tmp/My Drive", title: "My Drive"))
    #expect(!store.add(.app, target: "/System/Applications/Notes.app", title: "Notes")) // already there
    #expect(store.items.map(\.title) == ["Notes", "Morning routine", "My Drive"])
    let again = LauncherStore(storageURL: file)
    #expect(again.items == store.items)
}

@MainActor @Test func launcherRemove() {
    let store = LauncherStore(storageURL: tempDir().appendingPathComponent("launcher.json"))
    store.add(.app, target: "/A.app", title: "A")
    store.add(.app, target: "/B.app", title: "B")
    store.remove(store.items[0].id)
    #expect(store.items.map(\.title) == ["B"])
}

@Test func shortcutsListParsing() {
    let out = Data("Morning routine\n\nSend ETA \nMorning routine\nResize image\n".utf8)
    #expect(ShortcutsCLI.parseList(out) == ["Morning routine", "Send ETA", "Resize image"])
    #expect(ShortcutsCLI.runArguments("Send ETA") == ["run", "Send ETA"])
}

@Test func dropDestinationNumbersLikeFinder() {
    let folder = URL(fileURLWithPath: "/tmp/Drive")
    let taken: Set<String> = ["/tmp/Drive/Report.pdf", "/tmp/Drive/Report 2.pdf", "/tmp/Drive/Notes"]
    let exists: (URL) -> Bool = { taken.contains($0.path) }
    #expect(FileDrop.destination(for: URL(fileURLWithPath: "/x/Photo.png"), in: folder, exists: exists).lastPathComponent == "Photo.png")
    #expect(FileDrop.destination(for: URL(fileURLWithPath: "/x/Report.pdf"), in: folder, exists: exists).lastPathComponent == "Report 3.pdf")
    #expect(FileDrop.destination(for: URL(fileURLWithPath: "/x/Notes"), in: folder, exists: exists).lastPathComponent == "Notes 2")
}

@Test func dropCopiesAndKeepsTheOriginal() throws {
    let src = tempDir(), dest = tempDir()
    let a = src.appendingPathComponent("a.txt")
    try Data("hello".utf8).write(to: a)
    try Data("old".utf8).write(to: dest.appendingPathComponent("a.txt"))
    let copied = FileDrop.copy([a], into: dest)
    #expect(copied.count == 1)
    #expect(FileManager.default.fileExists(atPath: a.path))                      // original kept
    #expect(try String(contentsOf: dest.appendingPathComponent("a.txt"), encoding: .utf8) == "old") // not overwritten
    #expect(try String(contentsOf: dest.appendingPathComponent("a 2.txt"), encoding: .utf8) == "hello")
}

@Test func launcherWidgetInCatalog() {
    #expect(WidgetKind.launcher.title == "Shortcuts")
    #expect(WidgetKind.launcher.sizes == [.small, .medium, .wide])
    #expect(WidgetKind.launcher.category == .productivity)
    #expect(WidgetKind.launcher.dataSources.isEmpty)
}
