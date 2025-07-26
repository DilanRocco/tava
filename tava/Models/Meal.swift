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
    let restaurant: Restaurant?
    let mealType: MealType
    let title: String?
    let description: String?
    let ingredients: String?
    let tags: [String]
    let privacy: MealPrivacy
    let location: LocationPoint?
    let rating: Int?
    let status: MealStatus
    let cost: Decimal?
    let eatenAt: Date
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties for UI
    var displayTitle: String {
        return title ?? (mealType == .homemade ? "Homemade Meal" : "Restaurant Meal")
    }
    


    var isDraft: Bool { status == .draft }
    var isPublished: Bool { status == .published }
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
    let distance: Int
    
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
    var photoUrl: String?
    let userHasLiked: Bool
    let userHasBookmarked: Bool
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
        case photoUrl = "photo_url"
        case userHasLiked = "user_has_liked"
        case userHasBookmarked = "user_has_bookmarked"
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
            photoUrl: photoUrl,
            userHasLiked: userHasLiked,
            userHasBookmarked: userHasBookmarked
        )
    }
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



struct MealWithPhotos: Identifiable, Codable, Equatable {
    let meal: Meal
    let photos: [Photo]
    
    var id: UUID { meal.id }
    
    var primaryPhoto: Photo? {
        photos.first { $0.isPrimary } ?? photos.first
    }
    
    var coursesSummary: String {
        let courses = Set(photos.compactMap { $0.course })
        if courses.isEmpty { return "No categories" }
        return courses.map { $0.displayName }.sorted().joined(separator: ", ")
    }
    
    var photoCount: Int { photos.count }
    
    // Convenience properties
    var isDraft: Bool { meal.isDraft }
    var isPublished: Bool { meal.isPublished }

    
}

struct MealInsert: Codable {
    let id: String
    let user_id: String
    let restaurant_id: String?
    let meal_type: String
    let title: String?
    let description: String?
    let ingredients: String?
    let tags: [String]
    let privacy: String
    let location: String?
    let rating: Int?
    let cost: Decimal?
    let status: String
    let eaten_at: String
    let created_at: String
    let updated_at: String
    let last_activity_at: String
}


extension MealWithPhotos {
    func updating(
        title: String? = nil,
        description: String? = nil,
        privacy: MealPrivacy? = nil,
        mealType: MealType? = nil,
        restaurant: Restaurant?? = nil, // Double optional to allow setting to nil
        rating: Int? = nil,
        ingredients: String? = nil,
        tags: [String]? = nil
    ) -> MealWithPhotos {
        let updatedMeal = Meal(
            id: meal.id,
            userId: meal.userId,
            restaurant: restaurant ?? meal.restaurant,
            mealType: mealType ?? meal.mealType,
            title: title ?? meal.title,
            description: description ?? meal.description,
            ingredients: ingredients ?? meal.ingredients,
            tags: tags ?? meal.tags,
            privacy: privacy ?? meal.privacy,
            location: meal.location,
            rating: rating ?? meal.rating,
            status: meal.status,
            cost: meal.cost,
            eatenAt: meal.eatenAt,
            createdAt: meal.createdAt,
            updatedAt: Date()

        )

        return MealWithPhotos(meal: updatedMeal, photos: photos)
    }
}