import Foundation

struct Profile: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
    var avatarPath: String?
    var homeCity: String?
    var homeCountry: String?
    var reputationScore: Int
    let createdAt: Date

    var displayLocation: String { [homeCity, homeCountry].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: ", ") }
    enum CodingKeys: String, CodingKey { case id, displayName = "display_name", avatarPath = "avatar_path", homeCity = "home_city", homeCountry = "home_country", reputationScore = "reputation_score", createdAt = "created_at" }

    init(id: UUID, displayName: String, avatarPath: String?, homeCity: String?, homeCountry: String? = nil, reputationScore: Int, createdAt: Date) {
        self.id = id; self.displayName = displayName; self.avatarPath = avatarPath; self.homeCity = homeCity; self.homeCountry = homeCountry; self.reputationScore = reputationScore; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); displayName = try c.decode(String.self, forKey: .displayName)
        avatarPath = try c.decodeIfPresent(String.self, forKey: .avatarPath); homeCity = try c.decodeIfPresent(String.self, forKey: .homeCity); homeCountry = try c.decodeIfPresent(String.self, forKey: .homeCountry)
        reputationScore = try c.decodeIfPresent(Int.self, forKey: .reputationScore) ?? 0; createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}
