import Foundation

/// Central image-path resolution and URL generation for complaint photos.
///
/// Storage layout (immutable, never overwritten):
///   complaints/{complaintUUID}/{photoUUID}.jpg          main asset (≤1280px)
///   complaints/{complaintUUID}/{photoUUID}_thumb.jpg    list/map thumbnail (320px)
///
/// The `report_media` row stores the MAIN path as the canonical value;
/// the thumbnail path is derived by convention. Legacy records that
/// contain a complete image URL pass through unchanged (no thumbnail
/// variant exists for them, so every size resolves to the same URL).
enum ComplaintImageURLs {
    static let rootPrefix = "complaints/"
    static let thumbnailSuffix = "_thumb.jpg"

    /// Canonical main-asset storage path for a new upload.
    static func mainPath(reportID: UUID, photoID: UUID = UUID()) -> String {
        "\(rootPrefix)\(reportID.uuidString.lowercased())/\(photoID.uuidString.lowercased()).jpg"
    }

    /// Thumbnail storage path derived from a main-asset path.
    /// Returns nil for values that are not main-asset paths.
    static func thumbnailPath(forMainPath path: String) -> String? {
        guard !isLegacyURL(path), path.hasSuffix(".jpg") else { return nil }
        return String(path.dropLast(".jpg".count)) + thumbnailSuffix
    }

    /// Legacy records store a complete URL instead of a storage path.
    static func isLegacyURL(_ stored: String) -> Bool {
        stored.lowercased().hasPrefix("http")
    }
}
