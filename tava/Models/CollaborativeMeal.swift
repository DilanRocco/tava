import Foundation

struct CollaborativeMeal: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorId: UUID
    let restaurantId: UUID?
    let title: String
    let description: String?
    let status: CollaborationStatus
    let location: LocationPoint?
    let scheduledAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case restaurantId = "restaurant_id"
        case title
        case description
        case status
        case location
        case scheduledAt = "scheduled_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CollaborativeMealParticipant: Codable, Identifiable, Hashable {
    let id: UUID
    let collaborativeMealId: UUID
    let userId: UUID
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case collaborativeMealId = "collaborative_meal_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
}

struct CollaborativeMealWithDetails: Codable, Identifiable {
    let collaborativeMeal: CollaborativeMeal
    let creator: User
    let restaurant: Restaurant?
    let participants: [CollaborativeMealParticipant]
    let participantUsers: [User]
    let photos: [Photo]
    
    var id: UUID { collaborativeMeal.id }
    
    var isActive: Bool {
        collaborativeMeal.status == .active
    }
    
    var participantCount: Int {
        participants.count
    }
} 