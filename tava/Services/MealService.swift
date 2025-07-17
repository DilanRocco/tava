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
        
        // Insert meal into database
        try await supabase.client
            .from("meals")
            .insert([newMeal])
            .execute()
        
        // Upload photos
        for (index, image) in photos.enumerated() {
            let photoUpload = PhotoUpload(
                image: image,
                mealId: newMeal.id,
                collaborativeMealId: nil,
                altText: nil,
                isPrimary: index == 0
            )
            
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
        }
        
        return newMeal
    }
    
    func deleteMeal(mealId: UUID) async throws {
        // First, delete associated photos from storage
        let photos: [Photo] = try await supabase.client
            .from("photos")
            .select()
            .eq("meal_id", value: mealId)
            .execute()
            .value
        
        for photo in photos {
            try await supabase.deletePhoto(path: photo.storagePath)
        }
        
        // Delete the meal (cascading deletes will handle photos, reactions, etc.)
        try await supabase.client
            .from("meals")
            .delete()
            .eq("id", value: mealId)
            .execute()
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
