//
//  DraftMeal.swift
//  tava
//
//  Created by dilan on 7/20/25.
//

import Foundation
import Supabase

@MainActor
class DraftMealService: ObservableObject {
    private let supabase = SupabaseClient.shared.client
    private let localStorageKey = "draft_meals"
    
    @Published var draftMeals: [MealWithPhotos] = []
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        Task {
            await loadDraftMeals()
        }
    }
    
    // MARK: - Load Draft Meals
    
    func loadDraftMeals() async {
        isLoading = true
        error = nil
        
        // Try to load from server first
        do {
            let serverDrafts = try await loadDraftMealsFromServer()
            draftMeals = serverDrafts
            
            // Save to local storage as backup
            saveDraftMealsToLocal(serverDrafts)
        } catch {
            // Fallback to local storage
            let localDrafts = loadDraftMealsFromLocal()
            draftMeals = localDrafts
            self.error = "Loaded offline drafts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func loadDraftMealsFromServer() async throws -> [MealWithPhotos] {
        guard let userId = supabase.auth.currentUser?.id else {
            throw DraftMealError.notAuthenticated
        }
        
        // Get draft meals
        let mealsResponse: [Meal] = try await supabase
            .from("meals")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: MealStatus.draft.rawValue)
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        // Get photos for these meals
        var mealsWithPhotos: [MealWithPhotos] = []
        
        for meal in mealsResponse {
            let photos: [Photo] = try await supabase
                .from("photos")
                .select()
                .eq("meal_id", value: meal.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            mealsWithPhotos.append(MealWithPhotos(meal: meal, photos: photos))
        }
        
        return mealsWithPhotos
    }
    
    // MARK: - Create Draft Meal
    
    func createDraftMeal() async throws -> MealWithPhotos {
        guard let userId = supabase.auth.currentUser?.id else {
            throw DraftMealError.notAuthenticated
        }
        
        let newMeal = Meal(
            id: UUID(),
            userId: userId,
            restaurantId: nil,
            mealType: .homemade,
            title: nil,
            description: nil,
            ingredients: nil,
            tags: [],
            privacy: .public,
            location: nil,
            rating: nil,
            status: .draft,
            cost: nil,
            eatenAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let mealInsert = MealInsert(
            id: newMeal.id.uuidString,
            user_id: userId.uuidString,
            restaurant_id: nil,
            meal_type: newMeal.mealType.rawValue,
            title: nil,
            description: nil,
            ingredients: nil,
            tags: [],
            privacy: newMeal.privacy.rawValue,
            location: nil,
            rating: nil,
            cost: nil,
            status: MealStatus.draft.rawValue,
            eaten_at: ISO8601DateFormatter().string(from: newMeal.eatenAt),
            created_at: ISO8601DateFormatter().string(from: newMeal.createdAt),
            updated_at: ISO8601DateFormatter().string(from: newMeal.updatedAt),
            last_activity_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await supabase
            .from("meals")
            .insert(mealInsert)
            .execute()
        
        let mealWithPhotos = MealWithPhotos(meal: newMeal, photos: [])
        draftMeals.insert(mealWithPhotos, at: 0)
        
        // Update local storage
        saveDraftMealsToLocal(draftMeals)
        
        return mealWithPhotos
    }
    
    // MARK: - Add Photo to Meal
    
    func addPhoto(to mealId: UUID, imageData: Data, course: Course?) async throws -> Photo {
        guard let userId = supabase.auth.currentUser?.id else {
            throw DraftMealError.notAuthenticated
        }
        
        // Upload image to storage
        let fileName = "\(mealId.uuidString)/\(UUID().uuidString).jpg"
        let filePath = "meal-photos/\(fileName)"
        
        try await supabase.storage
            .from("meal-photos")
            .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // Get public URL
        let publicURL = try supabase.storage
            .from("meal-photos")
            .getPublicURL(path: filePath)
        
        // Create photo record
        let newPhoto = Photo(
            id: UUID(),
            mealId: mealId,
            collaborativeMealId: nil,
            userId: userId,
            storagePath: filePath,
            url: publicURL.absoluteString,
            altText: nil,
            isPrimary: false,
            course: course,
            createdAt: Date()
        )
        
        let photoInsert = PhotoInsert(
            id: newPhoto.id.uuidString,
            meal_id: mealId.uuidString,
            collaborative_meal_id: nil,
            user_id: userId.uuidString,
            storage_path: filePath,
            url: publicURL.absoluteString,
            alt_text: nil,
            is_primary: false,
            course: course?.rawValue,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await supabase
            .from("photos")
            .insert(photoInsert)
            .execute()
        
        // Update local state
        if let index = draftMeals.firstIndex(where: { $0.meal.id == mealId }) {
            var updatedMeal = draftMeals[index]
            updatedMeal = MealWithPhotos(
                meal: updatedMeal.meal,
                photos: updatedMeal.photos + [newPhoto]
            )
            draftMeals[index] = updatedMeal
            
            // Update meal's updated_at timestamp
            try await updateMealTimestamp(mealId: mealId)
            
            // Update local storage
            saveDraftMealsToLocal(draftMeals)
        }
        
        return newPhoto
    }
    
    // MARK: - Update Photo Course
    
    func updatePhotoCourse(photoId: UUID, course: Course?) async throws {
        try await supabase
            .from("photos")
            .update(["course": course?.rawValue])
            .eq("id", value: photoId.uuidString)
            .execute()
        
        // Update local state
        for (mealIndex, meal) in draftMeals.enumerated() {
            if let photoIndex = meal.photos.firstIndex(where: { $0.id == photoId }) {
                var updatedPhotos = meal.photos
                var updatedPhoto = updatedPhotos[photoIndex]
                updatedPhoto = Photo(
                    id: updatedPhoto.id,
                    mealId: updatedPhoto.mealId,
                    collaborativeMealId: updatedPhoto.collaborativeMealId,
                    userId: updatedPhoto.userId,
                    storagePath: updatedPhoto.storagePath,
                    url: updatedPhoto.url,
                    altText: updatedPhoto.altText,
                    isPrimary: updatedPhoto.isPrimary,
                    course: course,
                    createdAt: updatedPhoto.createdAt
                )
                updatedPhotos[photoIndex] = updatedPhoto
                
                draftMeals[mealIndex] = MealWithPhotos(
                    meal: meal.meal,
                    photos: updatedPhotos
                )
                break
            }
        }
        
        saveDraftMealsToLocal(draftMeals)
    }
    
    // MARK: - Publish Course
    
    func publishCourse(mealId: UUID, course: Course) async throws {
        // This could create a separate published meal or update status
        // For now, let's assume we're just marking photos as published
        // You might want to implement a more complex publishing system
        
        try await updateMealTimestamp(mealId: mealId)
    }
    
    // MARK: - Delete Draft Meal
    
    func deleteDraftMeal(mealId: UUID) async throws {
        // Delete photos first
        let photos = draftMeals.first(where: { $0.meal.id == mealId })?.photos ?? []
        
        for photo in photos {
            // Delete from storage
            try await supabase.storage
                .from("meal-photos")
                .remove(paths: [photo.storagePath])
            
            // Delete from database
            try await supabase
                .from("photos")
                .delete()
                .eq("id", value: photo.id.uuidString)
                .execute()
        }
        
        // Delete meal
        try await supabase
            .from("meals")
            .delete()
            .eq("id", value: mealId.uuidString)
            .execute()
        
        // Update local state
        draftMeals.removeAll { $0.meal.id == mealId }
        saveDraftMealsToLocal(draftMeals)
    }
    
    // MARK: - Private Helpers
    
    private func updateMealTimestamp(mealId: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try await supabase
            .from("meals")
            .update(["updated_at": now, "last_activity_at": now])
            .eq("id", value: mealId.uuidString)
            .execute()
    }
    
    // MARK: - Local Storage
    
    private func saveDraftMealsToLocal(_ meals: [MealWithPhotos]) {
        do {
            let data = try JSONEncoder().encode(meals)
            UserDefaults.standard.set(data, forKey: localStorageKey)
        } catch {
            print("Failed to save drafts locally: \(error)")
        }
    }
    
    private func loadDraftMealsFromLocal() -> [MealWithPhotos] {
        guard let data = UserDefaults.standard.data(forKey: localStorageKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([MealWithPhotos].self, from: data)
        } catch {
            print("Failed to load drafts from local storage: \(error)")
            return []
        }
    }
    
    
    
        
        func publishEntireMeal(mealId: UUID, title: String?, description: String?, privacy: MealPrivacy = .public) async throws {
            guard let mealIndex = draftMeals.firstIndex(where: { $0.meal.id == mealId }) else {
                throw DraftMealError.invalidData
            }
            
            let draftMeal = draftMeals[mealIndex]
            
            // Update the meal status to published with new details
            let now = Date()
            let updatedMeal = Meal(
                id: draftMeal.meal.id,
                userId: draftMeal.meal.userId,
                restaurantId: draftMeal.meal.restaurantId,
                mealType: draftMeal.meal.mealType,
                title: title,
                description: description,
                ingredients: draftMeal.meal.ingredients,
                tags: draftMeal.meal.tags,
                privacy: privacy,
                location: draftMeal.meal.location,
                rating: draftMeal.meal.rating,
                status: .published,
                cost: draftMeal.meal.cost,
                eatenAt: draftMeal.meal.eatenAt,
                createdAt: draftMeal.meal.createdAt,
                updatedAt: now
            )
            
            // Update in database
            try await supabase
                .from("meals")
                .update([
                    "title": title,
                    "description": description,
                    "privacy": privacy.rawValue,
                    "status": MealStatus.published.rawValue,
                    "updated_at": ISO8601DateFormatter().string(from: now),
                    "last_activity_at": ISO8601DateFormatter().string(from: now)
                ])
                .eq("id", value: mealId.uuidString)
                .execute()
            
            // Remove from drafts
            draftMeals.removeAll { $0.meal.id == mealId }
            saveDraftMealsToLocal(draftMeals)
        }
        
        private func createPublishedMealFromCourse(originalMeal: Meal, course: Course, photos: [Photo]) async throws -> Meal {
            guard let userId = supabase.auth.currentUser?.id else {
                throw DraftMealError.notAuthenticated
            }
            
            let newMealId = UUID()
            let now = Date()
            
            let publishedMeal = Meal(
                id: newMealId,
                userId: userId,
                restaurantId: originalMeal.restaurantId,
                mealType: originalMeal.mealType,
                title: "\(course.displayName) Course",
                description: nil,
                ingredients: originalMeal.ingredients,
                tags: originalMeal.tags + [course.rawValue],
                privacy: originalMeal.privacy,
                location: originalMeal.location,
                rating: originalMeal.rating,
                status: .published,
                cost: originalMeal.cost,
                eatenAt: originalMeal.eatenAt,
                createdAt: now,
                updatedAt: now
            )
            
            let mealInsert = MealInsert(
                id: newMealId.uuidString,
                user_id: userId.uuidString,
                restaurant_id: originalMeal.restaurantId?.uuidString,
                meal_type: originalMeal.mealType.rawValue,
                title: publishedMeal.title,
                description: nil,
                ingredients: originalMeal.ingredients,
                tags: publishedMeal.tags,
                privacy: originalMeal.privacy.rawValue,
                location: nil, // You might want to handle location serialization
                rating: originalMeal.rating,
                cost: originalMeal.cost,
                status: MealStatus.published.rawValue,
                eaten_at: ISO8601DateFormatter().string(from: originalMeal.eatenAt),
                created_at: ISO8601DateFormatter().string(from: now),
                updated_at: ISO8601DateFormatter().string(from: now),
                last_activity_at: ISO8601DateFormatter().string(from: now)
            )
            
            // Insert the new published meal
            try await supabase
                .from("meals")
                .insert(mealInsert)
                .execute()
            
            // Update photos to point to the new published meal
            for photo in photos {
                try await supabase
                    .from("photos")
                    .update(["meal_id": newMealId.uuidString])
                    .eq("id", value: photo.id.uuidString)
                    .execute()
            }
            
            return publishedMeal
        }
}


enum DraftMealError: Error, LocalizedError {
    case notAuthenticated
    case uploadFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to save meals"
        case .uploadFailed:
            return "Failed to upload photo"
        case .invalidData:
            return "Invalid meal data"
        }
    }
}
