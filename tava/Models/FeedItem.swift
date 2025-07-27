import Foundation

// Import MealType from Meal.swift
// Note: This creates a circular dependency we need to resolve

// MARK: - UI Feed Models

struct FeedMealItem: Identifiable {
    let id: String
    let userId: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let mealTitle: String?
    let description: String?
    let mealType: String
    let location: String
    let tags: [String]
    let rating: Int?
    let eatenAt: Date
    let likesCount: Int
    let commentsCount: Int
    let bookmarksCount: Int
    let photoUrl: String?
    let photoStoragePath: String?
    let userHasLiked: Bool
    let userHasBookmarked: Bool

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: eatenAt, relativeTo: Date())
    }
    
    var shareText: String {
        
        let title = mealTitle ?? "Meal"
        return "\(title) at \(location) - Check out this amazing meal on Tava!"
    }
}

// MARK: - API Response Feed Models

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
    let primaryPhotoFilePath: String?
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
        case primaryPhotoFilePath = "primary_photo_file_path"
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
            photoStoragePath: primaryPhotoFilePath,
            userHasLiked: userHasLiked,
            userHasBookmarked: userHasBookmarked
        )
    }
}

// MARK: - API Request models for service layer
struct FeedParams: Codable {
    let user_uuid: String
    let limit_count: Int
    let offset_count: Int
}

struct CommentParams: Codable {
    let target_meal_id: String
    let parent_limit: Int
    let parent_offset: Int
}

struct ReplyParams: Codable {
    let target_parent_id: String
    let reply_limit: Int
    let reply_offset: Int
}

struct AddCommentParams: Codable {
    let target_meal_id: String
    let comment_content: String
    let parent_id: String?
}

struct NearbyMealsParams: Codable {
    let center_lat: Double
    let center_lng: Double
    let radius_meters: Double
    let user_uuid: String
    let limit_count: Int
    let include_friends_only: Bool
}