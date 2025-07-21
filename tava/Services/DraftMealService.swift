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

    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    init() {
        Task {
            await loadDraftMeals()
        }
    }
    
    private func saveImageLocally(_ imageData: Data) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        do {
            try imageData.write(to: filePath)
            return filePath.lastPathComponent
        } catch {
            print("Failed to save image locally: \(error)")
            return nil
        }
    }

    private func loadLocalImage(fileName: String) -> Data? {
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        return try? Data(contentsOf: filePath)
    }

    private func deleteLocalImage(fileName: String) {
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        try? fileManager.removeItem(at: filePath)
    }
    // MARK: - Load Draft Meals
    
    func loadDraftMeals() async {
        isLoading = true
        error = nil
        
        let localDrafts = loadDraftMealsFromLocal()
        draftMeals = localDrafts
            

        
        isLoading = false
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
    
    let mealWithPhotos = MealWithPhotos(meal: newMeal, photos: [])
    draftMeals.insert(mealWithPhotos, at: 0)
    
    // Save locally only
    saveDraftMealsToLocal(draftMeals)
    
    return mealWithPhotos
}
    
    // MARK: - Add Photo to Meal
    
    func addPhoto(to mealId: UUID, imageData: Data, course: Course?) async throws -> Photo {
        guard let userId = supabase.auth.currentUser?.id else {
            throw DraftMealError.notAuthenticated
        }
        
        // Save image locally instead of uploading
        guard let localFileName = saveImageLocally(imageData) else {
            throw DraftMealError.uploadFailed
        }
        
        // Create photo with local file path
        let newPhoto = Photo(
            id: UUID(),
            mealId: mealId,
            collaborativeMealId: nil,
            userId: userId,
            storagePath: localFileName, // Store local file name here temporarily
            url: localFileName, // Use local file name as URL temporarily
            altText: nil,
            isPrimary: false,
            course: course,
            createdAt: Date()
        )
        
        // Update local state
        if let index = draftMeals.firstIndex(where: { $0.meal.id == mealId }) {
            var updatedMeal = draftMeals[index]
            updatedMeal = MealWithPhotos(
                meal: updatedMeal.meal,
                photos: updatedMeal.photos + [newPhoto]
            )
            draftMeals[index] = updatedMeal
            
            // Save to local storage only
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
    // Clean up local files
        if let meal = draftMeals.first(where: { $0.meal.id == mealId }) {
            for photo in meal.photos {
                deleteLocalImage(fileName: photo.storagePath)
            }
        }
        
        // Remove from local state
        draftMeals.removeAll { $0.meal.id == mealId }
        deleteDraftMealFromLocal(mealId: mealId)
    }
    
    private func deleteDraftMealFromLocal(mealId: UUID) {
        draftMeals.removeAll { $0.meal.id == mealId }

        var drafts = UserDefaults.standard.object(forKey: localStorageKey) as? [MealWithPhotos] ?? []
        print(drafts.count)
        drafts.removeAll { $0.meal.id == mealId }
        print(drafts.count)
        UserDefaults.standard.set(drafts, forKey: localStorageKey)
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
    
    func saveDraftMealsToLocal(_ meals: [MealWithPhotos]) {
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
            
            // First, create the meal in the database
            let newMeal = Meal(
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
                updatedAt: Date()
            )
            
            let mealInsert = MealInsert(
                id: newMeal.id.uuidString,
                user_id: newMeal.userId.uuidString,
                restaurant_id: nil,
                meal_type: newMeal.mealType.rawValue,
                title: title,
                description: description,
                ingredients: nil,
                tags: [],
                privacy: privacy.rawValue,
                location: nil,
                rating: nil,
                cost: nil,
                status: MealStatus.published.rawValue,
                eaten_at: ISO8601DateFormatter().string(from: newMeal.eatenAt),
                created_at: ISO8601DateFormatter().string(from: newMeal.createdAt),
                updated_at: ISO8601DateFormatter().string(from: newMeal.updatedAt),
                last_activity_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // Insert meal
            try await supabase
                .from("meals")
                .insert(mealInsert)
                .execute()
            
            // Now upload all the local photos
            for localPhoto in draftMeal.photos {
                // Load the local image data
                guard let imageData = loadLocalImage(fileName: localPhoto.storagePath) else {
                    continue
                }
                
                // Upload to Supabase storage
                let fileName = "\(mealId.uuidString)/\(UUID().uuidString).jpg"
                let filePath = "meal-photos/\(fileName)"
                
                try await supabase.storage
                    .from("meal-photos")
                    .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))
                
                // Get public URL
                let publicURL = try supabase.storage
                    .from("meal-photos")
                    .getPublicURL(path: filePath)
                
                // Create photo record in database
                let photoInsert = PhotoInsert(
                    id: localPhoto.id.uuidString,
                    meal_id: mealId.uuidString,
                    collaborative_meal_id: nil,
                    user_id: newMeal.userId.uuidString,
                    storage_path: filePath,
                    url: publicURL.absoluteString,
                    alt_text: nil,
                    is_primary: false,
                    course: localPhoto.course?.rawValue,
                    created_at: ISO8601DateFormatter().string(from: localPhoto.createdAt)
                )
                
                try await supabase
                    .from("photos")
                    .insert(photoInsert)
                    .execute()
                
                // Delete the local file
                deleteLocalImage(fileName: localPhoto.storagePath)
            }
            
            // Remove from drafts
            draftMeals.removeAll { $0.meal.id == mealId }
            deleteDraftMealFromLocal(mealId: mealId)
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
