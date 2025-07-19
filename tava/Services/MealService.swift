import Foundation
import UIKit
import CoreLocation

@MainActor
class MealService: ObservableObject {
    private let supabase = SupabaseClient.shared
    
    @Published var meals: [MealWithDetails] = []
    @Published var userMeals: [MealWithDetails] = []
    @Published var nearbyMeals: [MealWithDetails] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Feed Operations
    
    func fetchUserFeed(limit: Int = 20, offset: Int = 0) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let currentUserId = supabase.currentUser?.id else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            // Use the database function for optimized feed retrieval
            // Note: For now we'll skip the RPC call and use direct queries
            // let response = try await supabase.client.rpc(
            //     "get_user_feed",
            //     params: [
            //         "user_uuid": currentUserId.uuidString,
            //         "limit_count": limit,
            //         "offset_count": offset
            //     ]
            // ).execute()
            
            // Parse and convert to MealWithDetails
            // This would need proper parsing based on the function return structure
            // For now, we'll use a direct query approach
            
            let mealsResponse: [Meal] = try await supabase.client
                .from("meals")
                .select("""
                    *, 
                    users(*),
                    restaurants(*),
                    photos(*),
                    meal_reactions(*)
                """)
                .in("user_id", values: await getFollowedUserIds() + [currentUserId])
                .order("eaten_at", ascending: false)
                .limit(limit)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            // Transform to MealWithDetails
            let mealDetails = await transformToMealWithDetails(meals: mealsResponse)
            
            if offset == 0 {
                self.meals = mealDetails
            } else {
                self.meals.append(contentsOf: mealDetails)
            }
            
        } catch {
            self.error = error
            print("Failed to fetch user feed: \(error)")
        }
    }
    
    func fetchNearbyMeals(location: CLLocation, radius: Int = 5000) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let currentUserId = supabase.currentUser?.id else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            // Note: For now we'll skip the RPC call and use direct queries
            // let response = try await supabase.client.rpc(
            //     "get_nearby_meals",
            //     params: [
            //         "center_lat": location.coordinate.latitude,
            //         "center_lng": location.coordinate.longitude,
            //         "radius_meters": Double(radius),
            //         "user_uuid": currentUserId.uuidString
            //     ]
            // ).execute()
            
            // Parse response and transform to MealWithDetails
            // For now, use direct query
            let mealsResponse: [Meal] = try await supabase.client
                .from("meals")
                .select("""
                    *, 
                    users(*),
                    restaurants(*),
                    photos(*),
                    meal_reactions(*)
                """)
                .eq("meal_type", value: "restaurant")
                .eq("privacy", value: "public")
                .not("location", operator: .is, value: "null")
                .execute()
                .value
            
            let mealDetails = await transformToMealWithDetails(meals: mealsResponse)
            self.nearbyMeals = mealDetails
            
        } catch {
            self.error = error
            print("Failed to fetch nearby meals: \(error)")
        }
    }
    
    // MARK: - Meal CRUD Operations
    
    func createMeal(
        mealType: MealType,
        title: String?,
        description: String?,
        ingredients: String?,
        tags: [String],
        privacy: MealPrivacy,
        location: LocationPoint?,
        rating: Int?,
        cost: Decimal?,
        restaurantId: UUID?,
        photos: [UIImage]
    ) async throws -> Meal {
        print("Creating meal with \(photos.count) photos 432")
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Create the meal
        let newMeal = Meal(
            id: UUID(),
            userId: currentUserId,
            restaurantId: restaurantId,
            mealType: mealType,
            title: title,
            description: description,
            ingredients: ingredients,
            tags: tags,
            privacy: privacy,
            location: location,
            rating: rating,
            cost: cost,
            eatenAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Insert meal into database with proper null handling for PostGIS
        do {
            // Create a PostGIS-compatible meal structure
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
                let location: String? // PostGIS POINT format or nil
                let rating: Int?
                let cost: Decimal?
                let eaten_at: String
                let created_at: String
                let updated_at: String
            }
            
            let mealInsert = MealInsert(
                id: newMeal.id.uuidString,
                user_id: newMeal.userId.uuidString,
                restaurant_id: newMeal.restaurantId?.uuidString,
                meal_type: newMeal.mealType.rawValue,
                title: newMeal.title,
                description: newMeal.description,
                ingredients: newMeal.ingredients,
                tags: newMeal.tags,
                privacy: newMeal.privacy.rawValue,
                location: newMeal.location.map { "POINT(\($0.longitude) \($0.latitude))" },
                rating: newMeal.rating,
                cost: newMeal.cost,
                eaten_at: ISO8601DateFormatter().string(from: newMeal.eatenAt),
                created_at: ISO8601DateFormatter().string(from: newMeal.createdAt),
                updated_at: ISO8601DateFormatter().string(from: newMeal.updatedAt)
            )
            
            try await supabase.client
                .from("meals")
                .insert([mealInsert])
                .execute()
            print("Inserted meal into database")
        } catch {
            print("Failed to insert meal into database: \(error)")
            throw NSError(domain: "DatabaseError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to save meal to database",
                NSLocalizedFailureReasonErrorKey: error.localizedDescription
            ])
        }
        
        // Upload photos
        for (index, image) in photos.enumerated() {
            print("Uploading photo \(index + 1) of \(photos.count)")
            let photoUpload = PhotoUpload(
                image: image,
                mealId: newMeal.id,
                collaborativeMealId: nil,
                altText: nil,
                isPrimary: index == 0
            )
            
            do {
                let photoUrl = try await supabase.uploadPhoto(image: image, path: photoUpload.storagePath)
                
                let photo = Photo(
                    id: UUID(),
                    mealId: newMeal.id,
                    collaborativeMealId: nil,
                    userId: currentUserId,
                    storagePath: photoUpload.storagePath,
                    url: photoUrl,
                    altText: photoUpload.altText,
                    isPrimary: photoUpload.isPrimary,
                    createdAt: Date()
                )
                
                try await supabase.client
                    .from("photos")
                    .insert([photo])
                    .execute()
                print("Uploaded photo \(index + 1) of \(photos.count)")
            } catch {
                print("Failed to upload photo \(index + 1): \(error)")
                // If this is the first (primary) photo, this is a critical error
                if index == 0 {
                    throw NSError(domain: "PhotoUploadError", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to upload primary photo",
                        NSLocalizedFailureReasonErrorKey: error.localizedDescription
                    ])
                } else {
                    // For non-primary photos, log the error but continue
                    print("Warning: Skipping photo \(index + 1) due to upload error")
                    continue
                }
            }
        }
        
        return newMeal
    }
    
    func deleteMeal(mealId: UUID) async throws {
        do {
            // First, delete associated photos from storage
            let photos: [Photo] = try await supabase.client
                .from("photos")
                .select()
                .eq("meal_id", value: mealId)
                .execute()
                .value
            
            for photo in photos {
                do {
                    try await supabase.deletePhoto(path: photo.storagePath)
                    print("Deleted photo from storage: \(photo.storagePath)")
                } catch {
                    print("Warning: Failed to delete photo \(photo.storagePath): \(error)")
                    // Continue with deletion even if photo storage cleanup fails
                }
            }
            
            // Delete the meal (cascading deletes will handle photos, reactions, etc.)
            try await supabase.client
                .from("meals")
                .delete()
                .eq("id", value: mealId)
                .execute()
            
            print("Successfully deleted meal: \(mealId)")
        } catch {
            print("Failed to delete meal \(mealId): \(error)")
            throw NSError(domain: "DeleteError", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to delete meal",
                NSLocalizedFailureReasonErrorKey: error.localizedDescription
            ])
        }
    }
    
    func addReaction(mealId: UUID, reactionType: ReactionType) async throws {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let reaction = MealReaction(
            id: UUID(),
            userId: currentUserId,
            mealId: mealId,
            reactionType: reactionType,
            createdAt: Date()
        )
        
        try await supabase.client
            .from("meal_reactions")
            .upsert([reaction])
            .execute()
    }
    
    func removeReaction(mealId: UUID) async throws {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        try await supabase.client
            .from("meal_reactions")
            .delete()
            .eq("meal_id", value: mealId)
            .eq("user_id", value: currentUserId)
            .execute()
    }
    
    // MARK: - Helper Methods
    
    private func getFollowedUserIds() async -> [UUID] {
        do {
            guard let currentUserId = supabase.currentUser?.id else { return [] }
            
            let follows: [UserFollow] = try await supabase.client
                .from("user_follows")
                .select("following_id")
                .eq("follower_id", value: currentUserId)
                .execute()
                .value
            
            return follows.map { $0.followingId }
        } catch {
            print("Failed to fetch followed users: \(error)")
            return []
        }
    }
    
    private func transformToMealWithDetails(meals: [Meal]) async -> [MealWithDetails] {
        // This would implement the actual transformation logic
        // For now, return empty array - this would need proper implementation
        // based on the actual response structure from Supabase
        return []
    }
} 
