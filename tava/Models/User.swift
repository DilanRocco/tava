import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let phone: String?
    let email: String?
    let locationEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarUrl = "avatar_url"
        case phone
        case email
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

struct Contact: Codable, Identifiable {
    let id: UUID
    let name: String
    let phoneNumber: String?
    let email: String?
    let isOnApp: Bool
    let userId: UUID?
    
    init(name: String, phoneNumber: String?, email: String?, isOnApp: Bool, userId: UUID?) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.isOnApp = isOnApp
        self.userId = userId
    }
    
    var displayName: String {
        return name.isEmpty ? (phoneNumber ?? email ?? "Unknown") : name
    }
}

struct ContactInvite: Codable, Identifiable {
    let id: UUID
    let inviterId: UUID
    let contactName: String
    let contactPhone: String?
    let contactEmail: String?
    let sentAt: Date
    let status: InviteStatus
    
    enum InviteStatus: String, Codable, CaseIterable {
        case sent = "sent"
        case delivered = "delivered"
        case opened = "opened"
        case joined = "joined"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case inviterId = "inviter_id"
        case contactName = "contact_name"
        case contactPhone = "contact_phone"
        case contactEmail = "contact_email"
        case sentAt = "sent_at"
        case status
    }
}

struct FriendSuggestion: Codable, Identifiable {
    let userId: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let mutualFriendsCount: Int
    let isFromContacts: Bool
    let contactName: String?
    
    var id: UUID { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case mutualFriendsCount = "mutual_friends_count"
        case isFromContacts = "is_from_contacts"
        case contactName = "contact_name"
    }
} 