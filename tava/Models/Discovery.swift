import Foundation
import SwiftUI

// MARK: - Models

import Foundation

// MARK: - Immutable Data Models with Copy Methods

struct DiscoveryItemData: Codable {
    // User data
    let userId: String?
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let bio: String?
    let followersCount: Int?
    let mutualFriendsCount: Int?
    let isFollowing: Bool?
    
    // Restaurant data
    let restaurantId: String?
    let restaurantName: String?
    let restaurantAddress: String?
    let restaurantRating: Double?
    let restaurantPriceRange: Int?
    let restaurantDistance: Double?
    let restaurantImageUrl: String?
    let restaurantCategories: [String]?
    
    // Meal data
    let mealId: String?
    let mealTitle: String?
    let mealDescription: String?
    let mealImageUrl: String?
    let mealRating: Int?
    let mealLikesCount: Int?
    let mealCommentsCount: Int?
    let mealTags: [String]?
    let mealCreatedAt: Date?
    let mealAuthor: String?
    
    // General
    let title: String?
    let subtitle: String?
    let imageUrl: String?
    let actionText: String?
    
    // MARK: - Copy Methods for Immutable Updates
    
    func updatingFollowStatus(isFollowing: Bool, followersCount: Int? = nil) -> DiscoveryItemData {
        return DiscoveryItemData(
            userId: self.userId,
            username: self.username,
            displayName: self.displayName,
            avatarUrl: self.avatarUrl,
            bio: self.bio,
            followersCount: followersCount ?? self.followersCount,
            mutualFriendsCount: self.mutualFriendsCount,
            isFollowing: isFollowing,
            restaurantId: self.restaurantId,
            restaurantName: self.restaurantName,
            restaurantAddress: self.restaurantAddress,
            restaurantRating: self.restaurantRating,
            restaurantPriceRange: self.restaurantPriceRange,
            restaurantDistance: self.restaurantDistance,
            restaurantImageUrl: self.restaurantImageUrl,
            restaurantCategories: self.restaurantCategories,
            mealId: self.mealId,
            mealTitle: self.mealTitle,
            mealDescription: self.mealDescription,
            mealImageUrl: self.mealImageUrl,
            mealRating: self.mealRating,
            mealLikesCount: self.mealLikesCount,
            mealCommentsCount: self.mealCommentsCount,
            mealTags: self.mealTags,
            mealCreatedAt: self.mealCreatedAt,
            mealAuthor: self.mealAuthor,
            title: self.title,
            subtitle: self.subtitle,
            imageUrl: self.imageUrl,
            actionText: self.actionText
        )
    }
    
    func updatingMealEngagement(likesCount: Int? = nil, commentsCount: Int? = nil) -> DiscoveryItemData {
        return DiscoveryItemData(
            userId: self.userId,
            username: self.username,
            displayName: self.displayName,
            avatarUrl: self.avatarUrl,
            bio: self.bio,
            followersCount: self.followersCount,
            mutualFriendsCount: self.mutualFriendsCount,
            isFollowing: self.isFollowing,
            restaurantId: self.restaurantId,
            restaurantName: self.restaurantName,
            restaurantAddress: self.restaurantAddress,
            restaurantRating: self.restaurantRating,
            restaurantPriceRange: self.restaurantPriceRange,
            restaurantDistance: self.restaurantDistance,
            restaurantImageUrl: self.restaurantImageUrl,
            restaurantCategories: self.restaurantCategories,
            mealId: self.mealId,
            mealTitle: self.mealTitle,
            mealDescription: self.mealDescription,
            mealImageUrl: self.mealImageUrl,
            mealRating: self.mealRating,
            mealLikesCount: likesCount ?? self.mealLikesCount,
            mealCommentsCount: commentsCount ?? self.mealCommentsCount,
            mealTags: self.mealTags,
            mealCreatedAt: self.mealCreatedAt,
            mealAuthor: self.mealAuthor,
            title: self.title,
            subtitle: self.subtitle,
            imageUrl: self.imageUrl,
            actionText: self.actionText
        )
    }
}

struct DiscoveryFeedItem: Identifiable, Codable {
    let id = UUID()
    let type: DiscoveryItemType
    let data: DiscoveryItemData
    let timestamp: Date
    let priority: Int
    
    enum CodingKeys: String, CodingKey {
        case type, data, timestamp, priority
    }
    
    // MARK: - Copy Methods
    
    func updatingData(_ newData: DiscoveryItemData) -> DiscoveryFeedItem {
        return DiscoveryFeedItem(
            type: self.type,
            data: newData,
            timestamp: self.timestamp,
            priority: self.priority
        )
    }
    
    func updatingFollowStatus(isFollowing: Bool) -> DiscoveryFeedItem {
        let newFollowersCount = (data.followersCount ?? 0) + (isFollowing ? 1 : -1)
        let updatedData = data.updatingFollowStatus(
            isFollowing: isFollowing,
            followersCount: newFollowersCount
        )
        return updatingData(updatedData)
    }
}

// MARK: - Enhanced Person Model with Copy Methods

struct DiscoveryPerson: Identifiable, Codable {
    let id: String
    let username: String
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let followersCount: Int
    let mutualFriendsCount: Int
    let isFollowing: Bool
    let recentMealsCount: Int
    let joinedAt: Date
    
    // MARK: - Copy Methods
    
    func updatingFollowStatus(isFollowing: Bool) -> DiscoveryPerson {
        return DiscoveryPerson(
            id: self.id,
            username: self.username,
            displayName: self.displayName,
            bio: self.bio,
            avatarUrl: self.avatarUrl,
            followersCount: self.followersCount + (isFollowing ? 1 : -1),
            mutualFriendsCount: self.mutualFriendsCount,
            isFollowing: isFollowing,
            recentMealsCount: self.recentMealsCount,
            joinedAt: self.joinedAt
        )
    }
    
    func updatingProfile(displayName: String? = nil, bio: String? = nil, avatarUrl: String? = nil) -> DiscoveryPerson {
        return DiscoveryPerson(
            id: self.id,
            username: self.username,
            displayName: displayName ?? self.displayName,
            bio: bio ?? self.bio,
            avatarUrl: avatarUrl ?? self.avatarUrl,
            followersCount: self.followersCount,
            mutualFriendsCount: self.mutualFriendsCount,
            isFollowing: self.isFollowing,
            recentMealsCount: self.recentMealsCount,
            joinedAt: self.joinedAt
        )
    }
}

// MARK: - Enhanced Meal Model with Copy Methods

struct DiscoveryMeal: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let imageUrl: String?
    let rating: Int?
    let likesCount: Int
    let commentsCount: Int
    let tags: [String]
    let createdAt: Date
    let author: DiscoveryPerson
    let restaurant: DiscoveryRestaurant?
    
    // MARK: - Copy Methods
    
    func updatingEngagement(likesCount: Int? = nil, commentsCount: Int? = nil) -> DiscoveryMeal {
        return DiscoveryMeal(
            id: self.id,
            title: self.title,
            description: self.description,
            imageUrl: self.imageUrl,
            rating: self.rating,
            likesCount: likesCount ?? self.likesCount,
            commentsCount: commentsCount ?? self.commentsCount,
            tags: self.tags,
            createdAt: self.createdAt,
            author: self.author,
            restaurant: self.restaurant
        )
    }
    
    func updatingAuthor(_ newAuthor: DiscoveryPerson) -> DiscoveryMeal {
        return DiscoveryMeal(
            id: self.id,
            title: self.title,
            description: self.description,
            imageUrl: self.imageUrl,
            rating: self.rating,
            likesCount: self.likesCount,
            commentsCount: self.commentsCount,
            tags: self.tags,
            createdAt: self.createdAt,
            author: newAuthor,
            restaurant: self.restaurant
        )
    }
}

// MARK: - Alternative: Using Builder Pattern

class DiscoveryItemDataBuilder {
    private var data: DiscoveryItemData
    
    init(from existing: DiscoveryItemData) {
        self.data = existing
    }
    
    func setFollowStatus(_ isFollowing: Bool) -> DiscoveryItemDataBuilder {
        self.data = data.updatingFollowStatus(isFollowing: isFollowing)
        return self
    }
    
    func setFollowersCount(_ count: Int) -> DiscoveryItemDataBuilder {
        self.data = data.updatingFollowStatus(
            isFollowing: data.isFollowing ?? false,
            followersCount: count
        )
        return self
    }
    
    func setMealLikes(_ count: Int) -> DiscoveryItemDataBuilder {
        self.data = data.updatingMealEngagement(likesCount: count)
        return self
    }
    
    func build() -> DiscoveryItemData {
        return data
    }
}

// MARK: - Alternative: Using KeyPath-based Updates

extension DiscoveryItemData {
    func updating<T>(_ keyPath: WritableKeyPath<DiscoveryItemData, T>, to value: T) -> DiscoveryItemData {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

// Note: This requires making properties var, so it's not ideal for immutability

// MARK: - Best Practice: Focused Update Methods

extension DiscoveryItemData {
    // Specific, focused update methods are better than generic ones
    
    func togglingFollow() -> DiscoveryItemData {
        let newIsFollowing = !(isFollowing ?? false)
        let newFollowersCount = (followersCount ?? 0) + (newIsFollowing ? 1 : -1)
        
        return updatingFollowStatus(
            isFollowing: newIsFollowing,
            followersCount: newFollowersCount
        )
    }
    
    func incrementingLikes() -> DiscoveryItemData {
        return updatingMealEngagement(
            likesCount: (mealLikesCount ?? 0) + 1
        )
    }
    
    func decrementingLikes() -> DiscoveryItemData {
        return updatingMealEngagement(
            likesCount: max(0, (mealLikesCount ?? 0) - 1)
        )
    }
}



enum DiscoveryItemType: String, Codable, CaseIterable {
    case trendingMeal = "trending_meal"
    case suggestedPerson = "suggested_person"
    case popularRestaurant = "popular_restaurant"
    case nearbyActivity = "nearby_activity"
    case featuredMeal = "featured_meal"
}




struct DiscoveryRestaurant: Identifiable, Codable {
    let id: String
    let name: String
    let address: String
    let city: String?
    let rating: Double?
    let priceRange: Int
    let categories: [String]
    let distance: Double?
    let imageUrl: String?
    let recentMealsCount: Int
    let averageMealRating: Double?
    
    var formattedAddress: String {
        var components: [String] = [address]
        if let city = city { components.append(city) }
        return components.joined(separator: ", ")
    }
    
    var priceRangeDisplay: String {
        return String(repeating: "$", count: min(priceRange, 4))
    }
}


