import Foundation

// MARK: - Database Query Response Models
// These models match the exact structure returned from database queries

struct MealQueryResult: Codable {
    let id: String
    let user_id: String
    let restaurant_id: String?
    let meal_type: String
    let title: String?
    let description: String?
    let ingredients: String?
    let tags: [String]?
    let privacy: String
    let rating: Int?
    let cost: Double?
    let eaten_at: String
    let created_at: String
    let updated_at: String
    let status: String
    
    // Nested objects from joins
    let users: UserData?
    let restaurants: RestaurantData?
    let photos: [PhotoData]?
    let meal_reactions: [ReactionData]?
}

struct UserData: Codable {
    let id: String
    let username: String
    let display_name: String?
    let bio: String?
    let avatar_url: String?
}

struct RestaurantData: Codable {
    let id: String
    let google_place_id: String?
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let latitude: Double?
    let longitude: Double?
    let rating: Double?
    let price_range: Int?
    let google_maps_url: String?
    let image_url: String?
}

struct PhotoData: Codable {
    let id: String
    let meal_id: String?
    let collaborative_meal_id: String?
    let user_id: String
    let url: String
    let storage_path: String
    let alt_text: String?
    let is_primary: Bool?
    let course: String?
    let created_at: String?
}

struct ReactionData: Codable {
    let id: String
    let user_id: String
    let reaction_type: String
}

struct CommentQueryData: Codable, Identifiable {
    let meal_id: String
    let comment_id: String
    let parent_comment_id: String?
    let user_id: String
    let username: String
    let display_name: String?
    let avatar_url: String?
    let content: String
    let created_at: Date
    let updated_at: Date
    let likes_count: Int
    let replies_count: Int
    let user_has_liked: Bool
    
    var id: String { comment_id }
    
    func toComment() -> Comment {
        return Comment(
            id: UUID(uuidString: comment_id) ?? UUID(),
            mealId: UUID(uuidString: meal_id) ?? UUID(),
            parentCommentId: parent_comment_id != nil ? UUID(uuidString: parent_comment_id!) : nil,
            userId: UUID(uuidString: user_id) ?? UUID(),
            username: username,
            displayName: display_name,
            avatarUrl: avatar_url,
            content: content,
            createdAt: created_at,
            updatedAt: updated_at,
            likesCount: likes_count,
            repliesCount: replies_count,
            userHasLiked: user_has_liked,
            replies: []
        )
    }
}