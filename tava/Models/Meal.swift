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

// MARK: - Feed Data Models

struct FeedMealData: Codable, Identifiable {
    let mealId: UUID
    let userId: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let mealTitle: String?
    let mealDescription: String?
    let mealType: MealType
    let locationText: String
    let tags: [String]
    let rating: Int?
    let eatenAt: Date
    let likesCount: Int
    let commentsCount: Int
    let bookmarksCount: Int
    var photoFilePath: String?
    
    var id: UUID { mealId }
    
    enum CodingKeys: String, CodingKey {
        case mealId = "meal_id"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case mealTitle = "meal_title"
        case mealDescription = "meal_description"
        case mealType = "meal_type"
        case locationText = "location_text"
        case tags
        case rating
        case eatenAt = "eaten_at"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case bookmarksCount = "bookmarks_count"
        case photoFilePath = "primary_photo_file_path"
    }
    
    // Convert to FeedMealItem for UI
    func toFeedMealItem() -> FeedMealItem {
        return FeedMealItem(
            id: mealId.uuidString,
            userId: userId.uuidString,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            mealTitle: mealTitle,
            description: mealDescription,
            mealType: mealType.rawValue,
            location: locationText,
            tags: tags,
            rating: rating,
            eatenAt: eatenAt,
            likesCount: likesCount,
            commentsCount: commentsCount,
            bookmarksCount: bookmarksCount,
            photoUrl: photoFilePath
        )
    }
} 