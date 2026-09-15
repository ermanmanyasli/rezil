//
//  rezilTests.swift
//  rezilTests
//
//  Created by Erman Manyasli on 4.09.2026.
//

import Foundation
import CoreLocation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import rezil

struct rezilTests {

    @Test func coordinateValidationRejectsNaN() {
        #expect(!CoordinateValidation.isValid(.init(latitude: .nan, longitude: .nan)))
        #expect(!CoordinateValidation.isValid(.init(latitude: 0, longitude: 0)))
        #expect(CoordinateValidation.isValid(.init(latitude: 41.01, longitude: 28.97)))
    }

    @Test func complaintAPIPayloadRoundTrips() throws {
        let complaint = Complaint(
            id: UUID(uuidString: "E5C55E1D-9F1E-4CF1-AB45-9D11A3AA6A5D")!,
            authorID: UUID(uuidString: "DB2D23B2-F9E8-4E9F-AF5D-7E705E9F99D8")!,
            title: "Kaldırım kapalı",
            category: .sidewalk,
            coordinate: .init(latitude: 39.91, longitude: 32.86),
            locationName: "Çankaya",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            supportCount: 3,
            commentCount: 1,
            isSupported: true
        )

        let encoded = try JSONEncoder.rezil.encode(complaint)
        let decoded = try JSONDecoder.rezil.decode(Complaint.self, from: encoded)

        #expect(decoded.id == complaint.id)
        #expect(decoded.coordinate.latitude == complaint.coordinate.latitude)
        #expect(decoded.coordinate.longitude == complaint.coordinate.longitude)
        #expect(decoded.title == complaint.title)
    }

    @Test func rezilDecoderParsesSupabaseFractionalSecondTimestamps() throws {
        struct DateProbe: Decodable {
            let createdAt: Date
            enum CodingKeys: String, CodingKey { case createdAt = "created_at" }
        }
        // Supabase timestamptz format with microseconds (as returned by PostgREST).
        let fractional = try JSONDecoder.rezil.decode(
            DateProbe.self,
            from: Data(#"{"created_at":"2026-09-10T14:23:45.123456+00:00"}"#.utf8))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: fractional.createdAt)
        #expect(parts.year == 2026 && parts.month == 9 && parts.day == 10)
        #expect(parts.hour == 14 && parts.minute == 23 && parts.second == 45)
        // Date is Double-backed; allow sub-millisecond float error.
        #expect(abs((parts.nanosecond ?? 0) - 123_456_000) < 1_000_000)
        // Plain ISO8601 without fractions must keep working.
        let plain = try JSONDecoder.rezil.decode(
            DateProbe.self,
            from: Data(#"{"created_at":"2026-09-10T14:23:45Z"}"#.utf8))
        #expect(utc.dateComponents([.second], from: plain.createdAt).second == 45)
    }

    @Test func complaintPhotoPipelineCapsDimensionsAndBudget() throws {
        let big = TestPhotos.busyPhoto(width: 4032, height: 3024)
        let main = try ComplaintImageProcessor.process(big)
        #expect(max(main.pixelWidth, main.pixelHeight) <= 1280)
        #expect(main.byteCount <= 400 * 1024)
        #expect(Array(main.jpegData.prefix(3)) == [0xFF, 0xD8, 0xFF])
        #expect(main.byteCount == main.jpegData.count)

        let thumb = try ComplaintImageProcessor.thumbnail(fromJPEGData: main.jpegData)
        #expect(max(thumb.pixelWidth, thumb.pixelHeight) <= 320)
        #expect(Array(thumb.jpegData.prefix(3)) == [0xFF, 0xD8, 0xFF])
    }

    @Test func complaintPhotoPipelineNeverUpscales() throws {
        let small = TestPhotos.busyPhoto(width: 400, height: 300)
        let out = try ComplaintImageProcessor.process(small)
        #expect(out.pixelWidth == 400 && out.pixelHeight == 300)
    }

    @Test func complaintPhotoPipelineLadderEngagesOnNoise() throws {
        // Adversarial input: per-pixel white noise barely compresses.
        let noise = TestPhotos.noisePhoto(width: 2048, height: 1536)
        let main = try ComplaintImageProcessor.process(noise)
        #expect(max(main.pixelWidth, main.pixelHeight) <= 1280)
        #expect(Array(main.jpegData.prefix(3)) == [0xFF, 0xD8, 0xFF])
        // Ladder (quality steps + 1024px fallback) must pull even noise
        // close to budget; headroom covers cross-platform encoder variance.
        #expect(main.byteCount <= 450 * 1024)
    }

    @Test func complaintImageURLConventions() throws {
        let reportID = UUID(uuidString: "E5C55E1D-9F1E-4CF1-AB45-9D11A3AA6A5D")!
        let photoID = UUID(uuidString: "DB2D23B2-F9E8-4E9F-AF5D-7E705E9F99D8")!
        let main = ComplaintImageURLs.mainPath(reportID: reportID, photoID: photoID)
        #expect(main == "complaints/e5c55e1d-9f1e-4cf1-ab45-9d11a3aa6a5d/db2d23b2-f9e8-4e9f-af5d-7e705e9f99d8.jpg")
        #expect(ComplaintImageURLs.thumbnailPath(forMainPath: main)
            == "complaints/e5c55e1d-9f1e-4cf1-ab45-9d11a3aa6a5d/db2d23b2-f9e8-4e9f-af5d-7e705e9f99d8_thumb.jpg")
        #expect(ComplaintImageURLs.thumbnailPath(forMainPath: "https://cdn.example/x.jpg") == nil)
        #expect(ComplaintImageURLs.isLegacyURL("https://cdn.example/x.jpg"))
        #expect(!ComplaintImageURLs.isLegacyURL(main))

        let client = SupabaseClient(
            configuration: try AppConfiguration(url: "https://example.supabase.co", anonKey: "public-key", googleClientID: "x"),
            session: nil)
        #expect(client.resolveReportImageURL(main)?.absoluteString
            == "https://example.supabase.co/storage/v1/object/public/report-images/" + main)
        #expect(client.reportThumbnailURL(for: main)?.absoluteString.hasSuffix("_thumb.jpg") == true)
        #expect(client.resolveReportImageURL("https://cdn.example/x.jpg")?.absoluteString == "https://cdn.example/x.jpg")
        #expect(client.reportThumbnailURL(for: "https://cdn.example/x.jpg")?.absoluteString == "https://cdn.example/x.jpg")
    }

    @Test func missingSupabaseConfigurationIsNotValid() {
        #expect(throws: AppConfigurationError.self) {
            try AppConfiguration(url: "", anonKey: "", googleClientID: "")
        }
    }

    @Test func nativeGoogleConfigurationRequiresClientID() {
        #expect(throws: AppConfigurationError.self) {
            try AppConfiguration(url: "https://example.supabase.co", anonKey: "public-key", googleClientID: "")
        }
    }

    @Test func googleCallbackParsesSupabaseTokens() throws {
        let url = URL(string: "rezil://auth-callback#access_token=access123&refresh_token=refresh456")!

        let callback = try OAuthCallback(url: url)

        #expect(callback.accessToken == "access123")
        #expect(callback.refreshToken == "refresh456")
    }

    @Test func googleNonceIsHashedBeforeSendingToGoogle() {
        #expect(GoogleNonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func googleSessionDecodesMixedUserMetadata() throws {
        let json = #"{"access_token":"access","refresh_token":"refresh","user":{"id":"DB2D23B2-F9E8-4E9F-AF5D-7E705E9F99D8","user_metadata":{"full_name":"Test User","email_verified":true,"picture":"https://example.com/avatar.png"}}}"#

        let session = try JSONDecoder.rezil.decode(SupabaseSession.self, from: Data(json.utf8))

        #expect(session.user.userMetadata?.fullName == "Test User")
    }

    @Test func reportDraftRequiresMeaningfulTextAndPhoto() {
        #expect(!ReportDraftValidation.canPublish(text: "   ", hasPhoto: true))
        #expect(!ReportDraftValidation.canPublish(text: "Bozuk kaldırım", hasPhoto: false))
        #expect(ReportDraftValidation.canPublish(text: "Bozuk kaldırım", hasPhoto: true))
    }

    @Test func reportDraftRejectsTextOverLimit() {
        #expect(!ReportDraftValidation.canPublish(text: String(repeating: "a", count: 241), hasPhoto: true))
    }

    @Test func reportDraftRequiresResolvedLocation() {
        #expect(!ReportDraftValidation.canPublish(text: "Bozuk kaldırım", hasPhoto: true, hasLocation: false))
        #expect(ReportDraftValidation.canPublish(text: "Bozuk kaldırım", hasPhoto: true, hasLocation: true))
    }

    @Test func supabaseErrorsUseReadableDescription() {
        let data = Data(#"{"error":"invalid request","error_description":"Oturum doğrulanamadı."}"#.utf8)
        #expect(SupabaseError.readableMessage(from: data) == "Oturum doğrulanamadı.")
    }

    @Test func expiredAccessTokenNeedsRefresh() {
        let token = "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJleHAiOjEwMDB9.signature"
        #expect(JWTToken.expirationDate(from: token) == Date(timeIntervalSince1970: 1000))
        #expect(JWTToken.needsRefresh(token, now: Date(timeIntervalSince1970: 1001)))
        #expect(!JWTToken.needsRefresh(token, now: Date(timeIntervalSince1970: 900)))
    }

    @Test func relativeTimestampIsFixedAndLocalized() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(RelativeTimestamp.string(from: now.addingTimeInterval(-30), now: now) == "1 dakikadan az")
        #expect(RelativeTimestamp.string(from: now.addingTimeInterval(-3_600), now: now) == "1 saat önce")
        #expect(RelativeTimestamp.string(from: now.addingTimeInterval(-172_800), now: now) == "2 gün önce")
    }

}

/// Deterministic synthetic photos for pipeline tests (seeded RNG: no flakes).
private enum TestPhotos {
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64 = 0x12345678
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    /// Busy photographic-like image: gradient + shapes + speckle.
    static func busyPhoto(width: Int, height: Int) -> Data {
        var rng = SeededRNG()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        for y in stride(from: 0, to: height, by: 4) {
            let t = CGFloat(y) / CGFloat(height)
            ctx.setFillColor(red: t, green: 0.4 + 0.3 * t, blue: 0.9 - 0.5 * t, alpha: 1)
            ctx.fill(CGRect(x: 0, y: y, width: width, height: 4))
        }
        for _ in 0..<4000 {
            let x = Int.random(in: 0..<width, using: &rng)
            let y = Int.random(in: 0..<height, using: &rng)
            let s = Int.random(in: 2..<24, using: &rng)
            ctx.setFillColor(red: CGFloat.random(in: 0...1, using: &rng),
                             green: CGFloat.random(in: 0...1, using: &rng),
                             blue: CGFloat.random(in: 0...1, using: &rng), alpha: 1)
            ctx.fill(CGRect(x: x, y: y, width: s, height: s))
        }
        return pngData(ctx.makeImage()!)
    }

    /// Adversarial input: per-pixel white noise, barely compressible.
    static func noisePhoto(width: Int, height: Int) -> Data {
        var rng = SeededRNG()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = UInt8.random(in: 0...255, using: &rng)
            pixels[i + 1] = UInt8.random(in: 0...255, using: &rng)
            pixels[i + 2] = UInt8.random(in: 0...255, using: &rng)
            pixels[i + 3] = 255
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &pixels, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return pngData(ctx.makeImage()!)
    }

    private static func pngData(_ image: CGImage) -> Data {
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }
}
