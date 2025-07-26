import Foundation
import CoreLocation

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

// Note: FeedMealData and FeedMealItem are now in Models/FeedItem.swift
// Note: MealType, MealPrivacy, MealStatus are now in Models/MealTypes.swift



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