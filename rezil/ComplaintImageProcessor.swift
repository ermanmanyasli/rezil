import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Aggressive, low-bandwidth photo pipeline for street-problem reports.
/// Photo quality is not a priority: the output only needs to make the
/// reported issue recognizable.
///
/// Guarantees for `process(_:)` output:
/// - JPEG data (never HEIC/PNG/original), `image/jpeg` content type.
/// - Longest edge capped at 1280 px (1024 px fallback), never upscaled.
/// - All metadata stripped (EXIF, GPS, orientation normalized by drawing).
/// - Best effort ≤ 400 KB via the 0.60 → 0.52 → 0.45 quality ladder.
enum ComplaintImageProcessor {
    /// Policy constants (single source of truth, also used by tests).
    static let maxMainEdge: CGFloat = 1280
    static let fallbackMainEdge: CGFloat = 1024
    static let maxByteCount = 400 * 1024
    static let qualities: [CGFloat] = [0.60, 0.52, 0.45]
    static let thumbnailEdge: CGFloat = 320
    static let thumbnailQuality: CGFloat = 0.50

    /// Main upload asset + its list thumbnail, derived from one decode path.
    struct OptimizedPhoto {
        let image: ProcessedPhoto
        let thumbnail: ProcessedPhoto
    }

    /// One JPEG asset: bytes, final pixel dimensions and byte size.
    struct ProcessedPhoto {
        let jpegData: Data
        let pixelWidth: Int
        let pixelHeight: Int
        var byteCount: Int { jpegData.count }
    }

    enum ProcessingError: LocalizedError {
        case unreadableData

        var errorDescription: String? {
            "Fotoğraf işlenemedi. Başka bir fotoğraf dene."
        }
    }

    /// Full pipeline for one picked photo: main asset + 320px thumbnail.
    static func optimize(_ data: Data) throws -> OptimizedPhoto {
        let image = try process(data)
        let thumbnail = try thumbnail(fromJPEGData: image.jpegData)
        return OptimizedPhoto(image: image, thumbnail: thumbnail)
    }

    /// Main asset pipeline: 1280px cap, quality ladder, 1024px fallback.
    /// Returns the first encoding within budget; the cheapest fallback
    /// (1024px @ 0.45) is always returned so oversized inputs still upload.
    static func process(_ data: Data) throws -> ProcessedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ProcessingError.unreadableData
        }
        for maxEdge in [maxMainEdge, fallbackMainEdge] {
            for quality in qualities {
                guard let photo = encodedThumbnail(from: source, maxEdge: maxEdge, quality: quality) else { continue }
                let isCheapestFallback = (maxEdge == fallbackMainEdge && quality == qualities.last)
                if photo.byteCount <= maxByteCount || isCheapestFallback { return photo }
            }
        }
        throw ProcessingError.unreadableData
    }

    /// 320px list/map thumbnail from already-encoded JPEG bytes.
    /// Accepts any image data (works on originals too).
    static func thumbnail(fromJPEGData data: Data) throws -> ProcessedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let photo = encodedThumbnail(from: source, maxEdge: thumbnailEdge, quality: thumbnailQuality) else {
            throw ProcessingError.unreadableData
        }
        return photo
    }

    // MARK: - Private

    /// Downsampled, orientation-normalized, metadata-free JPEG encode.
    /// Returns nil when the source cannot be decoded or encoded.
    private static func encodedThumbnail(from source: CGImageSource, maxEdge: CGFloat, quality: CGFloat) -> ProcessedPhoto? {
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxEdge, 1),
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        // No properties dictionary: drops EXIF, GPS and all other metadata.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return ProcessedPhoto(jpegData: output as Data, pixelWidth: image.width, pixelHeight: image.height)
    }
}
