//
//  rezilTests.swift
//  rezilTests
//
//  Created by Erman Manyasli on 4.09.2026.
//

import Foundation
import CoreLocation
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
