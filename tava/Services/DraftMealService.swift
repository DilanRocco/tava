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
    private var googlePlacesService: GooglePlacesService
    
    @Published var draftMeals: [MealWithPhotos] = []
    @Published var isLoading = false
    @Published var error: String?

    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    init() {
        self.googlePlacesService = GooglePlacesService()
        loadDraftMeals()
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
    
    func loadDraftMeals() {
        isLoading = true
        error = nil
        
        let localDrafts = loadDraftMealsFromLocal()
        draftMeals = localDrafts
        print("draftMeals.count: \(draftMeals.count)")
            

        
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
        restaurant: nil,
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
        
        // Save updated drafts to local storage
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
    
    
    
        
        func publishEntireMeal(meal: Meal) async throws {
            guard let mealIndex = draftMeals.firstIndex(where: { $0.meal.id == meal.id }) else {
                throw DraftMealError.invalidData
            }
            
            let draftMeal = draftMeals[mealIndex]
            
            // Handle restaurant creation if needed
            let restaurantId = try await ensureRestaurantExists(for: meal.restaurant)
            
            // Create and insert the meal
            try await createMealInDatabase(meal: meal, restaurantId: restaurantId)
            
            // Upload photos and create photo records
            try await uploadMealPhotos(mealId: meal.id, photos: draftMeal.photos)
            
            // Clean up draft
            removeDraftMeal(mealId: meal.id)
        }
        
        // MARK: - Helper Functions
        
        private func ensureRestaurantExists(for restaurant: Restaurant?) async throws -> String? {
            guard let restaurant = restaurant else { return nil }
            
            // Check if restaurant already exists
            if let existingId = try await findExistingRestaurant(googlePlaceId: restaurant.googlePlaceId) {
                print("✅ Restaurant already exists: \(existingId)")
                return existingId
            }
            
            // Create new restaurant
            print("🆕 Creating new restaurant: \(restaurant.name)")
            return try await createRestaurantInDatabase(restaurant)
        }
        
        private func findExistingRestaurant(googlePlaceId: String?) async throws -> String? {
            guard let googlePlaceId = googlePlaceId else { return nil }
            
            struct RestaurantIdResponse: Codable {
                let id: String
            }
            
            let existing: [RestaurantIdResponse] = try await supabase
                .from("restaurants")
                .select("id")
                .eq("google_place_id", value: googlePlaceId)
                .execute()
                .value
            
            return existing.first?.id
        }
        
        private func createRestaurantInDatabase(_ restaurant: Restaurant) async throws -> String {
            struct RestaurantInsert: Codable {
                let id: String
                let google_place_id: String?
                let name: String
                let address: String?
                let city: String?
                let state: String?
                let postal_code: String?
                let country: String?
                let phone: String?
                let longitude: Double?
                let latitude: Double?
                let rating: Double?
                let price_range: Int?
                let categories: [GooglePlaceCategory]
                let hours: GoogleOpeningHours?
                let google_maps_url: String?
                let image_url: String?
                let created_at: String
                let updated_at: String
            }
            
            let restaurantInsert = RestaurantInsert(
                id: restaurant.id.uuidString,
                google_place_id: restaurant.googlePlaceId,
                name: restaurant.name,
                address: restaurant.address,
                city: restaurant.city,
                state: restaurant.state,
                postal_code: restaurant.postalCode,
                country: restaurant.country,
                phone: restaurant.phone,
                longitude: restaurant.location?.longitude,
                latitude: restaurant.location?.latitude,
                rating: restaurant.rating,
                price_range: restaurant.priceRange,
                categories: restaurant.categories,
                hours: restaurant.hours,
                google_maps_url: restaurant.googleMapsUrl,
                image_url: restaurant.imageUrl,
                created_at: ISO8601DateFormatter().string(from: restaurant.createdAt),
                updated_at: ISO8601DateFormatter().string(from: restaurant.updatedAt)
            )
            
            struct RestaurantResponse: Codable {
                let id: String
            }
            
            let response: RestaurantResponse = try await supabase
                .from("restaurants")
                .insert(restaurantInsert)
                .select("id")
                .single()
                .execute()
                .value
            
            print("✅ Created restaurant: \(response.id)")
            return response.id
        }
        
        private func createMealInDatabase(meal: Meal, restaurantId: String?) async throws {
            print("Creating meal: \(meal.id)")
            
            let mealInsert = MealInsert(
                id: meal.id.uuidString,
                user_id: meal.userId.uuidString,
                restaurant_id: restaurantId,
                meal_type: meal.mealType.rawValue,
                title: meal.title,
                description: meal.description,
                ingredients: meal.ingredients,
                tags: meal.tags,
                privacy: meal.privacy.rawValue,
                location: nil,
                rating: meal.rating,
                cost: meal.cost,
                status: MealStatus.published.rawValue,
                eaten_at: ISO8601DateFormatter().string(from: meal.eatenAt),
                created_at: ISO8601DateFormatter().string(from: meal.createdAt),
                updated_at: ISO8601DateFormatter().string(from: meal.updatedAt),
                last_activity_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("meals")
                .insert(mealInsert)
                .execute()
            
            print("✅ Created meal: \(meal.id)")
        }
        
        private func uploadMealPhotos(mealId: UUID, photos: [Photo]) async throws {
            for localPhoto in photos {
                try await uploadSinglePhoto(mealId: mealId, photo: localPhoto)
            }
        }
        
        private func uploadSinglePhoto(mealId: UUID, photo: Photo) async throws {
            // Load the local image data
            guard let imageData = loadLocalImage(fileName: photo.storagePath) else {
                print("⚠️ Could not load local image: \(photo.storagePath)")
                return
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
                id: photo.id.uuidString,
                meal_id: mealId.uuidString,
                collaborative_meal_id: nil,
                user_id: photo.userId.uuidString,
                storage_path: filePath,
                url: publicURL.absoluteString,
                alt_text: nil,
                is_primary: false,
                course: photo.course?.rawValue,
                created_at: ISO8601DateFormatter().string(from: photo.createdAt)
            )
            
            try await supabase
                .from("photos")
                .insert(photoInsert)
                .execute()
            
            // Delete the local file
            deleteLocalImage(fileName: photo.storagePath)
            
            print("✅ Uploaded photo: \(photo.id)")
        }
        
        private func removeDraftMeal(mealId: UUID) {
            draftMeals.removeAll { $0.meal.id == mealId }
            saveDraftMealsToLocal(draftMeals)
            print("✅ Removed draft meal: \(mealId)")
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