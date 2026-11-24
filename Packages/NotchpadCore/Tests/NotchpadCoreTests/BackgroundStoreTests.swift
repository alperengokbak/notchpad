import AppKit
import Foundation
import Testing
@testable import NotchpadCore

private func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("np-bg-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

/// A plain PNG of the given pixel size.
private func png(_ w: Int, _ h: Int, in dir: URL) -> URL {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let url = dir.appendingPathComponent("source-\(w)x\(h).png")
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    return url
}

private func pixelSize(_ url: URL) -> (Int, Int)? {
    guard let rep = NSImageRep(contentsOf: url) else { return nil }
    return (rep.pixelsWide, rep.pixelsHigh)
}

@Test func importDownscalesAndKeepsAspect() throws {
    let dir = tempDir()
    let store = BackgroundStore(directory: dir)
    #expect(store.currentURL == nil)
    let saved = try store.importImage(from: png(4000, 1000, in: dir))
    #expect(store.currentURL == saved)
    let size = try #require(pixelSize(saved))
    #expect(size.0 == BackgroundStore.maxPixels)
    #expect(size.1 == BackgroundStore.maxPixels / 4)
}

@Test func smallImagesAreNotEnlarged() throws {
    let dir = tempDir()
    let saved = try BackgroundStore(directory: dir).importImage(from: png(800, 300, in: dir))
    let size = try #require(pixelSize(saved))
    #expect(size.0 == 800 && size.1 == 300)
}

@Test func importReplacesAndRemoveDeletes() throws {
    let dir = tempDir()
    let store = BackgroundStore(directory: dir)
    _ = try store.importImage(from: png(500, 500, in: dir))
    let second = try store.importImage(from: png(600, 200, in: dir))
    #expect(pixelSize(second)?.0 == 600)
    store.remove()
    #expect(store.currentURL == nil)
    #expect(!FileManager.default.fileExists(atPath: second.path))
}

@Test func notAnImageIsRefused() {
    let dir = tempDir()
    let text = dir.appendingPathComponent("notes.txt")
    try! Data("hello".utf8).write(to: text)
    let store = BackgroundStore(directory: dir)
    #expect(throws: BackgroundStore.ImportError.notAnImage) { try store.importImage(from: text) }
    #expect(store.currentURL == nil)
}
