import Foundation

struct Profile: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
    var avatarPath: String?
    var reputationScore: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey { case id, displayName = "display_name", avatarPath = "avatar_path", reputationScore = "reputation_score", createdAt = "created_at" }

    init(id: UUID, displayName: String, avatarPath: String?, reputationScore: Int, createdAt: Date) {
        self.id = id; self.displayName = displayName; self.avatarPath = avatarPath; self.reputationScore = reputationScore; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? "Kullanıcı"
        avatarPath = try c.decodeIfPresent(String.self, forKey: .avatarPath)
        reputationScore = try c.decodeIfPresent(Int.self, forKey: .reputationScore) ?? 0
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? .distantPast
    }
}
