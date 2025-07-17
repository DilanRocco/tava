import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let locationEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarUrl = "avatar_url"
        case locationEnabled = "location_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserFollow: Codable, Identifiable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
} 