import Foundation
import Testing
@testable import NotchpadCore

/// A fresh temp folder with a.txt and b.txt, plus where the shelf JSON goes.
private struct Sandbox {
    let dir: URL
    let a: URL
    let b: URL
    var storage: URL { dir.appendingPathComponent("shelf.json") }

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("shelf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        a = dir.appendingPathComponent("a.txt")
        b = dir.appendingPathComponent("b.txt")
        try "a".write(to: a, atomically: true, encoding: .utf8)
        try "b".write(to: b, atomically: true, encoding: .utf8)
    }
}

@MainActor @Test func addsFilesOnceInOrder() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([s.a, s.b, s.a])
    #expect(store.items.map(\.name) == ["a.txt", "b.txt"])
}

@MainActor @Test func ignoresNonFileURLs() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([URL(string: "https://example.com")!])
    #expect(store.items.isEmpty)
}

@MainActor @Test func persistsAcrossInstances() throws {
    let s = try Sandbox()
    ShelfStore(storageURL: s.storage).add([s.a])
    #expect(ShelfStore(storageURL: s.storage).items.map(\.name) == ["a.txt"])
}

@MainActor @Test func loadDropsDeletedFilesAndFollowsMovedFiles() throws {
    let s = try Sandbox()
    ShelfStore(storageURL: s.storage).add([s.a, s.b])
    try FileManager.default.removeItem(at: s.a)
    let sub = s.dir.appendingPathComponent("sub")
    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
    try FileManager.default.moveItem(at: s.b, to: sub.appendingPathComponent("b2.txt"))
    let reloaded = ShelfStore(storageURL: s.storage)
    #expect(reloaded.items.map(\.name) == ["b2.txt"])
    #expect(reloaded.url(for: reloaded.items[0].id)?.path.hasSuffix("sub/b2.txt") == true)
}

@MainActor @Test func dragEndedRemovesOnlyWhenAccepted() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([s.a])
    let id = store.items[0].id
    store.dragEnded(id, accepted: false)
    #expect(store.items.count == 1)
    store.dragEnded(id, accepted: true)
    #expect(store.items.isEmpty)
}

@MainActor @Test func removeDropsOneItem() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([s.a, s.b])
    store.remove(store.items[0].id)
    #expect(store.items.map(\.name) == ["b.txt"])
}

@MainActor @Test func brokenJSONStartsEmpty() throws {
    let s = try Sandbox()
    try "nope".write(to: s.storage, atomically: true, encoding: .utf8)
    #expect(ShelfStore(storageURL: s.storage).items.isEmpty)
}

@MainActor @Test func clearEmptiesAndSaves() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([s.a, s.b])
    store.clear()
    #expect(store.items.isEmpty)
    #expect(ShelfStore(storageURL: s.storage).items.isEmpty)
}

@MainActor @Test func createsMissingStorageFolder() throws {
    let s = try Sandbox()
    let nested = s.dir.appendingPathComponent("Notchpad/shelf.json")
    ShelfStore(storageURL: nested).add([s.a])
    #expect(FileManager.default.fileExists(atPath: nested.path))
}

@MainActor @Test func trashedFileIsDroppedOnLoad() throws {
    let s = try Sandbox()
    ShelfStore(storageURL: s.storage).add([s.a, s.b])
    let trash = s.dir.appendingPathComponent(".Trash")
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    try FileManager.default.moveItem(at: s.a, to: trash.appendingPathComponent("a.txt"))
    #expect(ShelfStore(storageURL: s.storage).items.map(\.name) == ["b.txt"])
}

@MainActor @Test func refreshDropsFilesTrashedOrDeletedWhileRunning() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([s.a, s.b])
    let trash = s.dir.appendingPathComponent(".Trashes/501")
    try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
    try FileManager.default.moveItem(at: s.a, to: trash.appendingPathComponent("a.txt"))
    try FileManager.default.removeItem(at: s.b)
    store.refresh()
    #expect(store.items.isEmpty)
    #expect(ShelfStore(storageURL: s.storage).items.isEmpty)
}

@MainActor @Test func refreshFollowsRenameWhileRunning() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([s.a])
    try FileManager.default.moveItem(at: s.a, to: s.dir.appendingPathComponent("renamed.txt"))
    store.refresh()
    #expect(store.items.map(\.name) == ["renamed.txt"])
    #expect(store.url(for: store.items[0].id)?.lastPathComponent == "renamed.txt")
}

@MainActor @Test func availableURLsInShelfOrder() throws {
    let s = try Sandbox()
    let store = ShelfStore(storageURL: s.storage)
    store.add([s.b, s.a])
    #expect(store.availableURLs().map(\.lastPathComponent) == ["b.txt", "a.txt"])
}
