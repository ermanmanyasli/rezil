import Foundation
import CoreLocation

enum ComplaintCategory: String, CaseIterable, Identifiable, Codable {
    case road = "Yol", sidewalk = "Kaldırım", trash = "Çöp", lighting = "Aydınlatma", accessibility = "Erişilebilirlik", other = "Diğer"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .road: "car.fill"
        case .sidewalk: "figure.walk"
        case .trash: "trash.fill"
        case .lighting: "lightbulb.fill"
        case .accessibility: "figure.roll"
        case .other: "exclamationmark.bubble.fill"
        }
    }
}

struct Complaint: Identifiable, Codable, Equatable {
    let id: UUID
    let authorID: UUID
    var title: String
    var category: ComplaintCategory
    var coordinate: CLLocationCoordinate2D
    var locationName: String
    var createdAt: Date
    var supportCount: Int
    var commentCount: Int
    var isSupported: Bool
    var imageData: Data? = nil
    var imagePaths: [String] = []
    var authorProfile: Profile? = nil

    init(id: UUID, authorID: UUID, title: String, category: ComplaintCategory, coordinate: CLLocationCoordinate2D, locationName: String, createdAt: Date, supportCount: Int, commentCount: Int, isSupported: Bool, imageData: Data? = nil, imagePaths: [String] = [], authorProfile: Profile? = nil) {
        self.id = id; self.authorID = authorID; self.title = title; self.category = category; self.coordinate = coordinate
        self.locationName = locationName; self.createdAt = createdAt; self.supportCount = supportCount; self.commentCount = commentCount; self.isSupported = isSupported; self.imageData = imageData; self.imagePaths = imagePaths; self.authorProfile = authorProfile
    }

    enum CodingKeys: String, CodingKey {
        case id, authorID, title, category, latitude, longitude, locationName, createdAt, supportCount, commentCount, isSupported, imageData, imagePaths, authorProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        authorID = try container.decode(UUID.self, forKey: .authorID)
        title = try container.decode(String.self, forKey: .title)
        category = ComplaintCategory(rawValue: try container.decode(String.self, forKey: .category)) ?? .other
        coordinate = CLLocationCoordinate2D(
            latitude: try container.decode(Double.self, forKey: .latitude),
            longitude: try container.decode(Double.self, forKey: .longitude)
        )
        locationName = try container.decode(String.self, forKey: .locationName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        supportCount = try container.decode(Int.self, forKey: .supportCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        isSupported = try container.decode(Bool.self, forKey: .isSupported)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        authorProfile = try container.decodeIfPresent(Profile.self, forKey: .authorProfile)
        imagePaths = try container.decodeIfPresent([String].self, forKey: .imagePaths) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(authorID, forKey: .authorID)
        try container.encode(title, forKey: .title)
        try container.encode(category.rawValue, forKey: .category)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(supportCount, forKey: .supportCount)
        try container.encode(commentCount, forKey: .commentCount)
        try container.encode(isSupported, forKey: .isSupported)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encodeIfPresent(authorProfile, forKey: .authorProfile)
        try container.encode(imagePaths, forKey: .imagePaths)
    }

    static func == (lhs: Complaint, rhs: Complaint) -> Bool {
        lhs.id == rhs.id && lhs.authorID == rhs.authorID && lhs.title == rhs.title && lhs.category == rhs.category && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude && lhs.locationName == rhs.locationName && lhs.createdAt == rhs.createdAt && lhs.supportCount == rhs.supportCount && lhs.commentCount == rhs.commentCount && lhs.isSupported == rhs.isSupported && lhs.imageData == rhs.imageData && lhs.authorProfile == rhs.authorProfile
    }
}

struct ReportComment: Identifiable, Codable, Equatable {
    let id: UUID
    let reportID: UUID
    let authorID: UUID
    let body: String
    let createdAt: Date
    let authorProfile: Profile?
    var likeCount: Int
    var isLiked: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case reportID = "report_id"
        case authorID = "author_id"
        case body
        case createdAt = "created_at", authorProfile = "author"
        case likeCount = "like_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reportID = try c.decode(UUID.self, forKey: .reportID)
        authorID = try c.decode(UUID.self, forKey: .authorID)
        body = try c.decode(String.self, forKey: .body)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        authorProfile = try c.decodeIfPresent(Profile.self, forKey: .authorProfile)
        likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(reportID, forKey: .reportID)
        try c.encode(authorID, forKey: .authorID)
        try c.encode(body, forKey: .body)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(authorProfile, forKey: .authorProfile)
        try c.encode(likeCount, forKey: .likeCount)
    }
}

extension JSONEncoder {
    static var rezil: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var rezil: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
