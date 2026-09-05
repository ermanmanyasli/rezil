import Foundation
import CoreLocation

enum SupabaseError: LocalizedError {
    case invalidResponse
    case server(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Sunucudan geçersiz yanıt alındı."
        case .server(let message): message
        case .notAuthenticated: "Bu işlem için giriş yapmalısın."
        }
    }

    static func readableMessage(from data: Data) -> String {
        struct ErrorPayload: Decodable {
            let error: String?
            let errorDescription: String?
            let message: String?

            enum CodingKeys: String, CodingKey {
                case error, message
                case errorDescription = "error_description"
            }
        }

        if let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data) {
            return payload.errorDescription ?? payload.message ?? payload.error ?? "İşlem tamamlanamadı. Lütfen tekrar dene."
        }
        return "İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene."
    }
}

struct SupabaseSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", refreshToken = "refresh_token", user
    }
}

struct SupabaseUser: Codable, Sendable {
    let id: UUID
    let userMetadata: SupabaseUserMetadata?

    enum CodingKeys: String, CodingKey { case id, userMetadata = "user_metadata" }
}

struct SupabaseUserMetadata: Codable, Sendable {
    let fullName: String?

    enum CodingKeys: String, CodingKey { case fullName = "full_name" }
}

struct OAuthCallback: Sendable {
    let accessToken: String
    let refreshToken: String?

    init(url: URL) throws {
        guard let fragment = url.fragment else { throw SupabaseError.invalidResponse }
        let values = fragment.split(separator: "&").reduce(into: [String: String]()) { values, item in
            let parts = item.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return }
            values[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        guard let accessToken = values["access_token"], !accessToken.isEmpty else { throw SupabaseError.invalidResponse }
        self.accessToken = accessToken
        self.refreshToken = values["refresh_token"]
    }
}

struct SupabaseClient: Sendable {
    let configuration: AppConfiguration
    let session: SupabaseSession?

    func signInWithApple(idToken: String, nonce: String) async throws -> SupabaseSession {
        struct Body: Encodable { let provider = "apple"; let id_token: String; let nonce: String }
        return try await request("/auth/v1/token?grant_type=id_token", method: "POST", body: Body(id_token: idToken, nonce: nonce), authenticated: false)
    }

    func signInWithGoogle(idToken: String, accessToken: String, nonce: String?) async throws -> SupabaseSession {
        struct Body: Encodable {
            let provider = "google"
            let id_token: String
            let access_token: String
            let nonce: String?

            enum CodingKeys: String, CodingKey { case provider, id_token, access_token, nonce }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(provider, forKey: .provider)
                try container.encode(id_token, forKey: .id_token)
                try container.encode(access_token, forKey: .access_token)
                try container.encodeIfPresent(nonce, forKey: .nonce)
            }
        }
        return try await request("/auth/v1/token?grant_type=id_token", method: "POST", body: Body(id_token: idToken, access_token: accessToken, nonce: nonce), authenticated: false)
    }

    func signInWithPassword(email: String, password: String) async throws -> SupabaseSession {
        struct Body: Encodable { let email: String; let password: String }
        return try await request("/auth/v1/token?grant_type=password", method: "POST", body: Body(email: email, password: password), authenticated: false)
    }

    func signUp(email: String, password: String) async throws -> SupabaseAuthResponse {
        struct Body: Encodable { let email: String; let password: String }
        return try await request("/auth/v1/signup", method: "POST", body: Body(email: email, password: password), authenticated: false)
    }

    func refreshSession(refreshToken: String) async throws -> SupabaseSession {
        struct Body: Encodable { let refresh_token: String }
        return try await request("/auth/v1/token?grant_type=refresh_token", method: "POST", body: Body(refresh_token: refreshToken), authenticated: false)
    }

    func sendMagicLink(email: String, redirectTo: String) async throws {
        struct Body: Encodable { let email: String; let createUser = true; let redirectTo: String; enum CodingKeys: String, CodingKey { case email, createUser = "create_user", redirectTo = "redirect_to" } }
        let _: [String: String] = try await request("/auth/v1/otp", method: "POST", body: Body(email: email, redirectTo: redirectTo), authenticated: false)
    }

    func fetchUser(accessToken: String) async throws -> SupabaseUser {
        var request = URLRequest(url: endpointURL("/auth/v1/user"))
        request.httpMethod = "GET"
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder.rezil.decode(SupabaseUser.self, from: data)
    }

    func fetchProfile(userID: UUID) async throws -> Profile? {
        let profiles: [Profile] = try await request("/rest/v1/profiles?id=eq.\(userID.uuidString)&select=*", method: "GET")
        return profiles.first
    }

    func upsertProfile(_ profile: Profile) async throws -> Profile {
        let profiles: [Profile] = try await request("/rest/v1/profiles", method: "POST", body: profile, headers: ["Prefer": "resolution=merge-duplicates,return=representation"])
        guard let profile = profiles.first else { throw SupabaseError.invalidResponse }
        return profile
    }

    func updateProfile(displayName: String, homeCity: String?, homeCountry: String?, avatarPath: String?) async throws -> Profile {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        struct Body: Encodable { let display_name: String; let home_city: String?; let home_country: String?; let avatar_path: String? }
        let rows: [Profile] = try await request("/rest/v1/profiles?id=eq.\(userID.uuidString)", method: "PATCH", body: Body(display_name: displayName, home_city: homeCity, home_country: homeCountry, avatar_path: avatarPath), headers: ["Prefer": "return=representation"])
        guard let profile = rows.first else { throw SupabaseError.invalidResponse }; return profile
    }

    func fetchReports(includeOwnReports: Bool = false) async throws -> [Complaint] {
        let visibilityFilter = includeOwnReports ? "" : "&visibility=eq.public"
        let rows: [ReportRow] = try await request("/rest/v1/reports?select=*,author:profiles!reports_author_id_fkey(*),media:report_media(storage_path)\(visibilityFilter)&order=created_at.desc", method: "GET")
        var complaints = rows.map(Complaint.init)
        guard let userID = session?.user.id, !complaints.isEmpty else { return complaints }
        let ids = complaints.map { $0.id.uuidString }.joined(separator: ",")
        let supported: [SupportedReportRow] = try await request("/rest/v1/report_support?select=report_id&user_id=eq.\(userID.uuidString)&support_type=eq.seen&report_id=in.(\(ids))", method: "GET")
        let supportedIDs = Set(supported.map(\.reportID))
        for index in complaints.indices { complaints[index].isSupported = supportedIDs.contains(complaints[index].id) }
        return complaints
    }

    func fetchMyReports() async throws -> [Complaint] {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        let rows: [ReportRow] = try await request("/rest/v1/reports?select=*,author:profiles!reports_author_id_fkey(*),media:report_media(storage_path)&author_id=eq.\(userID.uuidString)&order=created_at.desc", method: "GET")
        return rows.map(Complaint.init)
    }

    func updateReport(_ complaint: Complaint) async throws -> Complaint {
        struct Body: Encodable { let description: String; let category_id: String; let latitude: Double; let longitude: Double; let public_location_label: String }
        let body = Body(description: complaint.title, category_id: complaint.category.rawValue, latitude: complaint.coordinate.latitude, longitude: complaint.coordinate.longitude, public_location_label: complaint.locationName)
        let rows: [ReportRow] = try await request("/rest/v1/reports?id=eq.\(complaint.id.uuidString)", method: "PATCH", body: body, headers: ["Prefer": "return=representation"])
        guard let row = rows.first else { throw SupabaseError.invalidResponse }; return Complaint.init(row)
    }

    func deleteReport(_ id: UUID) async throws { try await requestNoContent("/rest/v1/reports?id=eq.\(id.uuidString)", method: "DELETE") }

    func fetchComments(for reportID: UUID) async throws -> [ReportComment] {
        var comments: [ReportComment] = try await request("/rest/v1/comments?select=*,author:profiles!comments_author_id_fkey(*)&report_id=eq.\(reportID.uuidString)&deleted_at=is.null&order=created_at.asc", method: "GET")
        guard let userID = session?.user.id, !comments.isEmpty else { return comments }
        let ids = comments.map { $0.id.uuidString }.joined(separator: ",")
        // Likes are supplementary data; a missing or not-yet-migrated likes table
        // must not prevent the comments themselves from being displayed.
        let liked: [LikedCommentRow] = (try? await request("/rest/v1/comment_likes?select=comment_id&user_id=eq.\(userID.uuidString)&comment_id=in.(\(ids))", method: "GET")) ?? []
        let likedIDs = Set(liked.map(\.commentID))
        for index in comments.indices { comments[index].isLiked = likedIDs.contains(comments[index].id) }
        return comments
    }

    func fetchMyComments() async throws -> [ReportComment] {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        return try await request("/rest/v1/comments?select=*,author:profiles!comments_author_id_fkey(*)&author_id=eq.\(userID.uuidString)&deleted_at=is.null&order=created_at.desc", method: "GET")
    }

    func deleteComment(_ id: UUID) async throws {
        struct Body: Encodable { let deleted_at: Date }
        try await requestNoContent("/rest/v1/comments?id=eq.\(id.uuidString)", method: "PATCH", body: Body(deleted_at: .now))
    }

    func uploadAvatar(_ data: Data) async throws -> String {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        let path = "\(userID.uuidString.lowercased())/avatar.jpg"
        var request = URLRequest(url: endpointURL("/storage/v1/object/avatars/\(path)")); request.httpMethod = "PUT"; request.httpBody = data
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(session?.accessToken ?? configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization"); request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type"); request.setValue("true", forHTTPHeaderField: "x-upsert")
        let (responseData, response) = try await URLSession.shared.data(for: request); try validate(response, data: responseData); return path
    }

    func publicAvatarURL(for path: String?) -> URL? { guard let path, !path.isEmpty else { return nil }; return endpointURL("/storage/v1/object/public/avatars/\(path)") }
    func reportImageURL(for path: String) -> URL { endpointURL("/storage/v1/object/public/report-images/\(path)") }

    func addComment(reportID: UUID, body: String) async throws -> ReportComment {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        let row = NewCommentRow(reportID: reportID, authorID: userID, body: body)
        let comments: [ReportComment] = try await request("/rest/v1/comments", method: "POST", body: row, headers: ["Prefer": "return=representation"])
        guard let comment = comments.first else { throw SupabaseError.invalidResponse }
        return comment
    }

    func toggleCommentLike(commentID: UUID, enabled: Bool) async throws {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        if enabled {
            try await requestWithoutResponse("/rest/v1/comment_likes", method: "POST", body: CommentLikeRow(commentID: commentID, userID: userID), headers: ["Prefer": "return=minimal"])
        } else {
            try await requestNoContent("/rest/v1/comment_likes?comment_id=eq.\(commentID.uuidString)&user_id=eq.\(userID.uuidString)", method: "DELETE")
        }
    }

    func createReport(description: String, category: ComplaintCategory, coordinate: CLLocationCoordinate2D, locationName: String, images: [Data]) async throws -> Complaint {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        let row = NewReportRow(authorID: userID, description: description, categoryID: category.rawValue, latitude: coordinate.latitude, longitude: coordinate.longitude, publicLocationLabel: locationName)
        let reports: [ReportRow] = try await request("/rest/v1/reports", method: "POST", body: row, headers: ["Prefer": "return=representation"])
        guard let report = reports.first else { throw SupabaseError.invalidResponse }
        var uploadedPaths: [String] = []
        for imageData in images.prefix(3) {
            let path = "\(report.id.uuidString)/\(UUID().uuidString).jpg"
            try await upload(imageData, path: path)
            let media = NewMediaRow(reportID: report.id, uploaderID: userID, storagePath: path)
            try await requestWithoutResponse("/rest/v1/report_media", method: "POST", body: media, headers: ["Prefer": "return=minimal"])
            uploadedPaths.append(path)
        }
        var complaint = Complaint.init(report)
        complaint.imagePaths = uploadedPaths
        return complaint
    }

    func toggleSeen(for reportID: UUID, enabled: Bool) async throws {
        guard let userID = session?.user.id else { throw SupabaseError.notAuthenticated }
        if enabled {
            let body = SupportRow(reportID: reportID, userID: userID, supportType: "seen")
            try await requestWithoutResponse("/rest/v1/report_support", method: "POST", body: body, headers: ["Prefer": "return=minimal"])
        } else {
            try await requestNoContent("/rest/v1/report_support?report_id=eq.\(reportID.uuidString)&user_id=eq.\(userID.uuidString)&support_type=eq.seen", method: "DELETE")
        }
    }

    private func upload(_ data: Data, path: String) async throws {
        var request = URLRequest(url: endpointURL("/storage/v1/object/report-images/\(path)"))
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session?.accessToken ?? configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
    }

    private func request<T: Decodable, B: Encodable>(_ path: String, method: String, body: B? = nil, headers: [String: String] = [:], authenticated: Bool = true) async throws -> T {
        var request = URLRequest(url: endpointURL(path))
        request.httpMethod = method
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \((authenticated ? session?.accessToken : nil) ?? configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let body { request.httpBody = try JSONEncoder.rezil.encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder.rezil.decode(T.self, from: data)
    }

    private func request<T: Decodable>(_ path: String, method: String) async throws -> T {
        try await request(path, method: method, body: Optional<String>.none as String?)
    }

    private func requestNoContent(_ path: String, method: String) async throws {
        var request = URLRequest(url: endpointURL(path))
        request.httpMethod = method
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session?.accessToken ?? configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
    }

    private func requestNoContent<B: Encodable>(_ path: String, method: String, body: B) async throws {
        var request = URLRequest(url: endpointURL(path)); request.httpMethod = method
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(session?.accessToken ?? configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONEncoder.rezil.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request); try validate(response, data: data)
    }

    private func requestWithoutResponse<B: Encodable>(_ path: String, method: String, body: B? = nil, headers: [String: String] = [:]) async throws {
        var request = URLRequest(url: endpointURL(path))
        request.httpMethod = method
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session?.accessToken ?? configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let body {
            request.httpBody = try JSONEncoder.rezil.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
    }

    private func validate(_ response: URLResponse, data: Data = Data()) throws {
        guard let response = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw SupabaseError.server(SupabaseError.readableMessage(from: data))
        }
    }

    private func endpointURL(_ path: String) -> URL {
        // URL.appending(path:) percent-encodes query separators such as '?'.
        URL(string: path, relativeTo: configuration.supabaseURL)!.absoluteURL
    }
}

struct SupabaseAuthResponse: Codable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey { case accessToken = "access_token", refreshToken = "refresh_token", user }
}

private struct ReportRow: Decodable {
    let id: UUID
    let authorID: UUID
    let description: String
    let categoryID: String
    let latitude: Double
    let longitude: Double
    let publicLocationLabel: String
    let createdAt: Date
    let supportCount: Int
    let commentCount: Int
    let author: Profile?
    let media: [MediaRow]?

    enum CodingKeys: String, CodingKey { case id; case authorID = "author_id"; case description; case categoryID = "category_id"; case latitude; case longitude; case publicLocationLabel = "public_location_label"; case createdAt = "created_at"; case supportCount = "support_count"; case commentCount = "comment_count"; case author; case media }
}

private extension Complaint {
    init(_ row: ReportRow) {
        id = row.id; authorID = row.authorID; title = row.description; category = ComplaintCategory(rawValue: row.categoryID) ?? .other
        coordinate = .init(latitude: row.latitude, longitude: row.longitude); locationName = row.publicLocationLabel
        createdAt = row.createdAt; supportCount = row.supportCount; commentCount = row.commentCount; isSupported = false; authorProfile = row.author; imagePaths = row.media?.map(\.storagePath) ?? []
    }
}

private struct NewReportRow: Encodable { let authorID: UUID; let description: String; let categoryID: String; let latitude: Double; let longitude: Double; let publicLocationLabel: String; enum CodingKeys: String, CodingKey { case authorID = "author_id"; case description; case categoryID = "category_id"; case latitude; case longitude; case publicLocationLabel = "public_location_label" } }
private struct NewMediaRow: Encodable { let reportID: UUID; let uploaderID: UUID; let storagePath: String; enum CodingKeys: String, CodingKey { case reportID = "report_id"; case uploaderID = "uploader_id"; case storagePath = "storage_path" } }
private struct SupportRow: Encodable { let reportID: UUID; let userID: UUID; let supportType: String; enum CodingKeys: String, CodingKey { case reportID = "report_id"; case userID = "user_id"; case supportType = "support_type" } }
private struct SupportedReportRow: Decodable { let reportID: UUID; enum CodingKeys: String, CodingKey { case reportID = "report_id" } }
private struct LikedCommentRow: Decodable { let commentID: UUID; enum CodingKeys: String, CodingKey { case commentID = "comment_id" } }
private struct CommentLikeRow: Codable { let commentID: UUID; let userID: UUID; enum CodingKeys: String, CodingKey { case commentID = "comment_id"; case userID = "user_id" } }
private struct NewCommentRow: Encodable { let reportID: UUID; let authorID: UUID; let body: String; enum CodingKeys: String, CodingKey { case reportID = "report_id"; case authorID = "author_id"; case body } }
private struct MediaRow: Decodable { let storagePath: String; enum CodingKeys: String, CodingKey { case storagePath = "storage_path" } }

enum JWTToken {
    static func expirationDate(from token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var encodedPayload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encodedPayload += String(repeating: "=", count: (4 - encodedPayload.count % 4) % 4)
        guard let data = Data(base64Encoded: encodedPayload),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expiration = payload["exp"] as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: expiration.doubleValue)
    }

    static func needsRefresh(_ token: String, now: Date = .now) -> Bool {
        guard let expirationDate = expirationDate(from: token) else { return true }
        return expirationDate.timeIntervalSince(now) <= 60
    }
}
