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
    let course: Course?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case collaborativeMealId = "collaborative_meal_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case url
        case course
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
    let course: Course?
    let isPrimary: Bool
    
    var fileName: String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let mealIdentifier = mealId?.uuidString.prefix(8) ?? collaborativeMealId?.uuidString.prefix(8) ?? "unknown"
        return "meal_\(mealIdentifier)_\(timestamp).webp"
    }
    
    var storagePath: String {
        let userId = "current_user" // This would be the actual user ID in practice
        return "meals/\(userId)/\(fileName)"
    }
} 


import Foundation

enum Course: String, Codable, CaseIterable, Hashable {
    case appetizer
    case soup
    case salad
    case entree
    case side
    case dessert
    case drink
    case cocktail
    case wine
    case beer
    case bread
    case amuse
    case palate = "palate_cleanser"
    case cheese
    case coffee
    case tea
    case other
    
    var displayName: String {
        switch self {
        case .appetizer: return "Appetizer"
        case .soup: return "Soup"
        case .salad: return "Salad"
        case .entree: return "Entree"
        case .side: return "Side"
        case .dessert: return "Dessert"
        case .drink: return "Drink"
        case .cocktail: return "Cocktail"
        case .wine: return "Wine"
        case .beer: return "Beer"
        case .bread: return "Bread"
        case .amuse: return "Amuse Bouche"
        case .palate: return "Palate Cleanser"
        case .cheese: return "Cheese Course"
        case .coffee: return "Coffee"
        case .tea: return "Tea"
        case .other: return "Other"
        }
    }
    
    var emoji: String {
        switch self {
        case .appetizer: return "🥗"
        case .soup: return "🍲"
        case .salad: return "🥙"
        case .entree: return "🍽️"
        case .side: return "🍟"
        case .dessert: return "🍰"
        case .drink: return "🥤"
        case .cocktail: return "🍹"
        case .wine: return "🍷"
        case .beer: return "🍺"
        case .bread: return "🍞"
        case .amuse: return "🥄"
        case .palate: return "🧊"
        case .cheese: return "🧀"
        case .coffee: return "☕"
        case .tea: return "🍵"
        case .other: return "🍴"
        }
    }
}

struct PhotoInsert: Codable {
    let id: String
    let meal_id: String?
    let collaborative_meal_id: String?
    let user_id: String
    let storage_path: String
    let url: String
    let alt_text: String?
    let is_primary: Bool
    let course: String?
    let created_at: String
}

// For local storage and UI
struct DraftPhoto: Codable, Identifiable {
    let id: UUID
    let localImageData: Data?
    let url: String?
    let course: Course?
    let isUploaded: Bool
    let createdAt: Date
    
    init(imageData: Data, course: Course? = nil) {
        self.id = UUID()
        self.localImageData = imageData
        self.url = nil
        self.course = course
        self.isUploaded = false
        self.createdAt = Date()
    }
}
