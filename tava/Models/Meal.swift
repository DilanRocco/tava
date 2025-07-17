import Foundation
import CoreLocation

enum MealType: String, Codable, CaseIterable {
    case restaurant
    case homemade
}

enum MealPrivacy: String, Codable, CaseIterable {
    case `public`
    case friendsOnly = "friends_only"
    case `private`
}

enum CollaborationStatus: String, Codable, CaseIterable {
    case active
    case completed
    case cancelled
}

struct Meal: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let restaurantId: UUID?
    let mealType: MealType
    let title: String?
    let description: String?
    let ingredients: String?
    let tags: [String]
    let privacy: MealPrivacy
    let location: LocationPoint?
    let rating: Int?
    let cost: Decimal?
    let eatenAt: Date
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties for UI
    var displayTitle: String {
        return title ?? (mealType == .homemade ? "Homemade Meal" : "Restaurant Meal")
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case restaurantId = "restaurant_id"
        case mealType = "meal_type"
        case title
        case description
        case ingredients
        case tags
        case privacy
        case location
        case rating
        case cost
        case eatenAt = "eaten_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LocationPoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    var clLocation: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from clLocation: CLLocation) {
        self.latitude = clLocation.coordinate.latitude
        self.longitude = clLocation.coordinate.longitude
    }
}

struct MealWithDetails: Codable, Identifiable {
    let meal: Meal
    let user: User
    let restaurant: Restaurant?
    let photos: [Photo]
    let reactions: [MealReaction]
    
    var id: UUID { meal.id }
    
    var primaryPhoto: Photo? {
        photos.first { $0.isPrimary } ?? photos.first
    }
    
    var reactionCount: Int {
        reactions.count
    }
} 