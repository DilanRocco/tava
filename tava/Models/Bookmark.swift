import Foundation

struct Bookmark: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let mealId: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mealId = "meal_id"
        case createdAt = "created_at"
    }
}

struct MealComment: Codable, Identifiable, Hashable {
    let id: UUID
    let mealId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

