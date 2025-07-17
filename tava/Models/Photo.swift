import Foundation
import SwiftUI

struct Photo: Codable, Identifiable, Hashable {
    let id: UUID
    let mealId: UUID?
    let collaborativeMealId: UUID?
    let userId: UUID
    let storagePath: String
    let url: String
    let altText: String?
    let isPrimary: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case collaborativeMealId = "collaborative_meal_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case url
        case altText = "alt_text"
        case isPrimary = "is_primary"
        case createdAt = "created_at"
    }
}

struct PhotoUpload {
    let image: UIImage
    let mealId: UUID?
    let collaborativeMealId: UUID?
    let altText: String?
    let isPrimary: Bool
    
    var fileName: String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let mealIdentifier = mealId?.uuidString.prefix(8) ?? collaborativeMealId?.uuidString.prefix(8) ?? "unknown"
        return "meal_\(mealIdentifier)_\(timestamp).jpg"
    }
    
    var storagePath: String {
        let userId = "current_user" // This would be the actual user ID in practice
        return "meals/\(userId)/\(fileName)"
    }
} 