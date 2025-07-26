import Foundation

enum MealType: String, Codable, CaseIterable {
    case restaurant
    case homemade
}

enum MealPrivacy: String, Codable, CaseIterable {
    case `public`
    case friendsOnly = "friends_only"
    case `private`
}

enum MealStatus: String, CaseIterable, Codable {
    case draft
    case published  
    case archived
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .published: return "Published"
        case .archived: return "Archived"
        }
    }
}

enum CollaborationStatus: String, Codable, CaseIterable {
    case active
    case completed
    case cancelled
}