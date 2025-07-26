import Foundation



struct MealReaction: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let mealId: UUID
    let reactionType: ReactionType
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mealId = "meal_id"
        case reactionType = "reaction_type"
        case createdAt = "created_at"
    }
}

enum ReactionType: String, Codable, CaseIterable {
    case like
    case love
    case yum
    case fire
    case wow
    
    var emoji: String {
        switch self {
        case .like: return "👍"
        case .love: return "❤️"
        case .yum: return "😋"
        case .fire: return "🔥"
        case .wow: return "😍"
        }
    }
    
    var displayName: String {
        switch self {
        case .like: return "Like"
        case .love: return "Love"
        case .yum: return "Yum"
        case .fire: return "Fire"
        case .wow: return "Wow"
        }
    }
} 