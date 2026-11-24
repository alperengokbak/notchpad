import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The panel's background picture: a downscaled copy in Notchpad's own folder, so moving or deleting
/// the original doesn't matter and a huge photo doesn't cost lots of memory.
public final class BackgroundStore: @unchecked Sendable {
    /// Longest side of the stored copy. The open panel is 680 × 200 pt (1360 × 400 px on Retina),
    /// so this leaves room for cropping a tall picture to the panel's wide shape.
    public static let maxPixels = 2000

    public enum ImportError: Error, Equatable {
        case notAnImage, couldNotSave
    }

    private let directory: URL
    private var fileURL: URL { directory.appendingPathComponent("background.png") }

    public init(directory: URL) {
        self.directory = directory
    }

    /// The stored picture, or nil when there is none.
    public var currentURL: URL? {
        FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    /// Reads any image macOS understands (JPEG, PNG, HEIC, …), shrinks it so its longest side is at
    /// most `maxPixels` (never enlarges), and saves it, replacing the previous one.
    @discardableResult
    public func importImage(from source: URL) throws -> URL {
        guard let src = CGImageSourceCreateWithURL(source as CFURL, nil), CGImageSourceGetCount(src) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int
        else { throw ImportError.notAnImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // phone photos: keep them the right way up
            kCGImageSourceThumbnailMaxPixelSize: min(max(w, h), Self.maxPixels),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
        else { throw ImportError.notAnImage }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tmp = directory.appendingPathComponent("background-new.png")
        guard let dest = CGImageDestinationCreateWithURL(tmp as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw ImportError.couldNotSave }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ImportError.couldNotSave }
        _ = try? FileManager.default.removeItem(at: fileURL)
        do {
            try FileManager.default.moveItem(at: tmp, to: fileURL)
        } catch {
            throw ImportError.couldNotSave
        }
        return fileURL
    }

    public func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
