import Foundation
import Helpers
import UIKit
import CoreLocation

@MainActor
class MealService: ObservableObject {
    private let supabase = SupabaseClient.shared
    
    @Published var meals: [MealWithDetails] = []
    @Published var userMeals: [MealWithDetails] = []
    @Published var nearbyMeals: [MealWithDetails] = []
    @Published var feedMeals: [FeedMealItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    @Published var comments: [Comment] = []
    @Published var isLoadingComments = false
    
    
    @Published var draftMeals: [MealWithPhotos] = []
    @Published var isLoadingDrafts = false
    // MARK: - Feed Operations
    
    func fetchFeedData(limit: Int = 20, offset: Int = 0) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let currentUserId = supabase.currentUser?.id else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            // FeedParams is now in Models/FeedItem.swift
            
            let params = FeedParams(
                user_uuid: currentUserId.uuidString,
                limit_count: limit,
                offset_count: offset
            )
            
            print("🔑 Calling Edge Function with params: \(params)")
            
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(formatter)
            // Call Edge Function - it returns the data directly
            let functionResponse: [FeedMealData] = try await supabase.client.functions
                .invoke("pull_user_feed", options: .init(body: params), decoder: decoder)
            print("🔑 Function Response received")

            // Convert to UI models
            let feedItems = functionResponse.map { $0.toFeedMealItem() }
            
            if offset == 0 {
                self.feedMeals = feedItems
            } else {
                self.feedMeals.append(contentsOf: feedItems)
            }
            
        } catch {
            self.error = error
            print("❌ Failed to fetch feed data: \(error)")
            
            // Debug the actual error
            if let data = error as? DecodingError {
                print("❌ Decoding error details: \(data)")
            }
        }
    }
    
    private func decodeResponse(data: Data, offset: Int) throws {
        guard !data.isEmpty else {
            print("🔑 Empty data")
            self.feedMeals = []
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode([FeedMealData].self, from: data)
        print("🔑 Successfully decoded \(response.count) feed items")
        
        let feedMealsItems = response.map { $0.toFeedMealItem() }
        
        if offset == 0 {
            self.feedMeals = feedMealsItems
        } else {
            self.feedMeals.append(contentsOf: feedMealsItems)
        }
    }
    
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
        print("🌍 fetchNearbyMeals called - Location: (\(location.coordinate.latitude), \(location.coordinate.longitude)), Radius: \(radius)m")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let currentUserId = supabase.currentUser?.id else {
                print("❌ No current user for nearby meals")
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            print("👤 Current user ID: \(currentUserId)")
            
            // Create parameters for the edge function
            // NearbyMealsParams is now in Models/FeedItem.swift
            
            
            print("🗺️ Fetching nearby meals with radius: \(radius)m from \(location.coordinate)")
            
            // Use direct query to get full restaurant data for map clustering
            let meals = try await fetchMealsWithRestaurants(
                center: location,
                radius: radius,
                currentUserId: currentUserId
            )
            self.nearbyMeals = meals
            
            print("✅ Fetched \(nearbyMeals.count) meals with restaurants")
            
        } catch {
            self.error = error
            print("❌ Failed to fetch nearby meals: \(error)")
        }
    }
    

   

    func toggleReaction(mealId: String, reactionType: ReactionType, isLiked: Bool) async throws {
        let mealId = UUID(uuidString: mealId) ?? UUID()
        print("Toggling reaction for meal \(mealId) with type \(reactionType) and isLiked \(isLiked)")
        if isLiked {
            print("Adding reaction for meal \(mealId) with type \(reactionType)")
            try await addReaction(mealId: mealId, reactionType: reactionType)
        } else {
            try await removeReaction(mealId: mealId)
        }
        
    }
    func addBookmark(mealId: String) async throws {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let mealId = UUID(uuidString: mealId) ?? UUID()
        let bookmark = Bookmark(
            id: UUID(),
            userId: currentUserId,
            mealId: mealId,
            createdAt: Date()
        )
        
        try await supabase.client
            .from("bookmarks")
            .insert([bookmark])
            .execute()
        print("Bookmark added for meal \(mealId)")
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
        print("Reaction added for meal \(mealId) with type \(reactionType)")
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
    
    // MARK: - Comment Models (now in Models/QueryModels.swift)
    
    
    
    // Add these published properties to MealService
    
    
    // MARK: - Comment Operations
    
    func fetchComments(for mealId: String, limit: Int = 20, offset: Int = 0) async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        
        do {
            // CommentParams is now in Models/FeedItem.swift
            
            let params = CommentParams(
                target_meal_id: mealId,
                parent_limit: limit,
                parent_offset: offset
            )
            
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(formatter)
            
            print(params)
            let response: [CommentQueryData] = try await supabase.client.rpc(
                "get_meal_comments",
                params: params
            ).execute().value
            
            let parentComments = response.map { commentData -> Comment in
                let comment = commentData.toComment()
                return comment
            }
            
            if offset == 0 {
                self.comments = parentComments
            } else {
                self.comments.append(contentsOf: parentComments)
            }
            
        } catch {
            self.error = error
            print("❌ Failed to fetch comments: \(error)")
            
            // Let's also check what type of error this is
            if let postgrestError = error as? PostgrestError {
                print("❌ PostgrestError details:")
                print("   Code: \(postgrestError.code ?? "nil")")
                print("   Message: \(postgrestError.message)")
                print("   Detail: \(postgrestError.detail ?? "nil")")
                print("   Hint: \(postgrestError.hint ?? "nil")")
            }
        }
    }
    
    func fetchReplies(for parentCommentId: String, limit: Int = 5, offset: Int = 0) async -> [Comment] {
        do {
            // ReplyParams is now in Models/FeedItem.swift
            
            let params = ReplyParams(
                target_parent_id: parentCommentId,
                reply_limit: limit,
                reply_offset: offset
            )
            
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(formatter)
            
            let response: [CommentQueryData] = try await supabase.client.rpc(
                "get_comment_replies", // New function name
                params: params
            ).execute().value
            
            return response.map { commentData -> Comment in
                commentData.toComment()
            }
            
        } catch {
            print("❌ Failed to fetch replies: \(error)")
            return []
        }
    }
    
    func addComment(to mealId: String, content: String, parentCommentId: String? = nil) async throws -> Comment {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "ValidationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Comment cannot be empty"])
        }
    
        do {
            // AddCommentParams is now in Models/FeedItem.swift
            
            let params = AddCommentParams(
                target_meal_id: mealId,
                comment_content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                parent_id: parentCommentId
            )
            
            let response: String = try await supabase.client.rpc(
                "add_meal_comment",
                params: params
            ).execute().value
            
            print("✅ Comment added with ID: \(response)")
            
            // Create the new comment object
            guard let currentUserId = supabase.currentUser?.id else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            let newComment = Comment(
                id: UUID(uuidString: response) ?? UUID(),
                mealId: UUID(uuidString: mealId) ?? UUID(),
                parentCommentId: parentCommentId != nil ? UUID(uuidString: parentCommentId!) : nil,
                userId: currentUserId,
                username: "You", // Placeholder
                displayName: nil,
                avatarUrl: nil,
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: Date(),
                updatedAt: Date(),
                likesCount: 0,
                repliesCount: 0,
                userHasLiked: false,
                replies: []
            )
            
            // Simply append to the appropriate list
            if let parentId = parentCommentId {
                // Adding a reply - find parent and add to its replies
                if let parentIndex = comments.firstIndex(where: { $0.id.uuidString == parentId }) {
                    comments[parentIndex] = comments[parentIndex].withReplies(comments[parentIndex].replies + [newComment])
                }
            } else {
                // Adding a parent comment - add to beginning of main list
                comments.insert(newComment, at: comments.count)
            }
            
            return newComment
        
        } catch {
            print("❌ Failed to add comment: \(error)")
            throw NSError(domain: "CommentError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to add comment",
                NSLocalizedFailureReasonErrorKey: error.localizedDescription
            ])
        }
    }
    
    func likeComment(commentId: String) async throws {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let reaction = [
            "id": UUID().uuidString,
            "user_id": currentUserId.uuidString,
            "comment_id": commentId,
            "reaction_type": "like",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            try await supabase.client
                .from("comment_reactions")
                .upsert([reaction])
                .execute()
            
            // Update local state
            updateCommentLikeStatus(commentId: commentId, isLiked: true, increment: 1)
            
        } catch {
            print("❌ Failed to like comment: \(error)")
            throw error
        }
    }
    
    func unlikeComment(commentId: String) async throws {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        do {
            try await supabase.client
                .from("comment_reactions")
                .delete()
                .eq("comment_id", value: commentId)
                .eq("user_id", value: currentUserId)
                .execute()
            
            // Update local state
            updateCommentLikeStatus(commentId: commentId, isLiked: false, increment: -1)
            
        } catch {
            print("❌ Failed to unlike comment: \(error)")
            throw error
        }
    }
    
    func loadMoreReplies(for parentCommentIndex: Int, mealId: String) async {
        guard parentCommentIndex < comments.count else { return }
        
        let parentComment = comments[parentCommentIndex]
        let currentRepliesCount = parentComment.replies.count
        
        let newReplies = await fetchReplies(
            for: parentComment.id.uuidString,
            limit: 5,
            offset: currentRepliesCount
        )
        
        if !newReplies.isEmpty {
            comments[parentCommentIndex].replies.append(contentsOf: newReplies)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func updateCommentLikeStatus(commentId: String, isLiked: Bool, increment: Int) {
        // Update parent comments
        if let index = comments.firstIndex(where: { $0.id.uuidString == commentId }) {
            let updatedLikesCount = max(0, comments[index].likesCount + increment)
            comments[index] = comments[index].withLikeStatus(isLiked: isLiked, likesCount: updatedLikesCount)
            return
        }
        
        // Update replies
        for parentIndex in comments.indices {
            if let replyIndex = comments[parentIndex].replies.firstIndex(where: { $0.id.uuidString == commentId }) {
                let updatedLikesCount = max(0, comments[parentIndex].replies[replyIndex].likesCount + increment)
                let updatedReply = comments[parentIndex].replies[replyIndex].withLikeStatus(isLiked: isLiked, likesCount: updatedLikesCount)
                
                var updatedReplies = comments[parentIndex].replies
                updatedReplies[replyIndex] = updatedReply
                comments[parentIndex] = comments[parentIndex].withReplies(updatedReplies)
                return
            }
        }
    }
}

// MARK: - MealService Extensions for Restaurant Map
extension MealService {
    
    // MARK: - Fetch Nearby Meals with Restaurant Data
    
    
    // MARK: - Direct Database Query for Meals with Restaurants
func fetchMealsWithRestaurants(
    center: CLLocation,
    radius: Int,
    currentUserId: UUID
) async throws -> [MealWithDetails] {
    
    // Query model types are now in Models/QueryModels.swift
    
    // Query meals with restaurant data within radius
    let queryResult: [MealQueryResult] = try await supabase.client
        .from("meals")
        .select("""
            *,
            users!user_id(*),
            restaurants!restaurant_id(*),
            photos(*),
            meal_reactions(*)
        """)
        .eq("meal_type", value: "restaurant")
        .eq("privacy", value: "public")
        .not("restaurant_id", operator: .is, value: "null")
        .order("eaten_at", ascending: false)
        .limit(200)
        .execute()
        .value
    
    print("🔍 Query returned \(queryResult.count) meals")
    
    // Filter by location radius and convert to MealWithDetails
    let mealDetails = queryResult.compactMap { result -> MealWithDetails? in
        guard let userData = result.users,
              let restaurantData = result.restaurants else {
            print("❌ Missing user or restaurant data for meal \(result.id)")
            return nil
        }
        
        print("🏪 Processing restaurant: \(restaurantData.name)")
        print("📍 Location: lat: \(restaurantData.latitude ?? 0), lng: \(restaurantData.longitude ?? 0)")
        
        // Get coordinates from new separate columns
        guard let latitude = restaurantData.latitude,
              let longitude = restaurantData.longitude else {
            print("⚠️ Skipping \(restaurantData.name) - no valid location coordinates")
            return nil
        }
        
        let restaurantLocation = CLLocation(
            latitude: latitude,
            longitude: longitude
        )
        let distance = center.distance(from: restaurantLocation)
        
        if distance > Double(radius) {
            print("🚫 Skipping \(restaurantData.name) - distance: \(Int(distance))m > radius: \(radius)m")
            return nil // Outside radius
        }
        
        print("✅ Including \(restaurantData.name) - distance: \(Int(distance))m")
        
        // Parse dates
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Create User
        let user = User(
            id: UUID(uuidString: userData.id) ?? UUID(),
            username: userData.username,
            displayName: userData.display_name,
            bio: userData.bio,
            avatarUrl: userData.avatar_url,
            locationEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Create Location from separate coordinates
        let locationPoint = LocationPoint(
            latitude: latitude,
            longitude: longitude
        )
        
        // Create Restaurant
        let restaurant = Restaurant(
            id: UUID(uuidString: restaurantData.id) ?? UUID(),
            googlePlaceId: restaurantData.google_place_id,
            name: restaurantData.name,
            address: restaurantData.address,
            city: restaurantData.city,
            state: restaurantData.state,
            postalCode: nil,
            country: "US",
            phone: nil,
            location: locationPoint,  // Using the LocationPoint directly
            rating: restaurantData.rating,
            priceRange: restaurantData.price_range,
            categories: [],
            hours: nil,
            googleMapsUrl: restaurantData.google_maps_url,
            imageUrl: restaurantData.image_url,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Create Meal
        let meal = Meal(
            id: UUID(uuidString: result.id) ?? UUID(),
            userId: UUID(uuidString: result.user_id) ?? UUID(),
            restaurant: restaurant,
            mealType: MealType(rawValue: result.meal_type) ?? .restaurant,
            title: result.title,
            description: result.description,
            ingredients: result.ingredients,
            tags: result.tags ?? [],
            privacy: .public,
            location: locationPoint,
            rating: result.rating,
            status: .published,
            cost: result.cost.map { Decimal($0) },
            eatenAt: dateFormatter.date(from: result.eaten_at) ?? Date(),
            createdAt: dateFormatter.date(from: result.created_at) ?? Date(),
            updatedAt: dateFormatter.date(from: result.updated_at) ?? Date(),
            
        )
        
        // Create Photos
        let photos = result.photos?.map { photoData in
            Photo(
                id: UUID(uuidString: photoData.id) ?? UUID(),
                mealId: meal.id,
                collaborativeMealId: photoData.collaborative_meal_id.flatMap { UUID(uuidString: $0) },
                userId: UUID(uuidString: photoData.user_id) ?? UUID(),
                storagePath: photoData.storage_path,
                url: photoData.url,
                altText: photoData.alt_text,
                isPrimary: photoData.is_primary ?? false,
                course: photoData.course.flatMap { Course(rawValue: $0) },
                createdAt: dateFormatter.date(from: photoData.created_at ?? "") ?? Date()
            )
        } ?? []
        
        // Create Reactions
        let reactions = result.meal_reactions?.map { reactionData in
            MealReaction(
                id: UUID(uuidString: reactionData.id) ?? UUID(),
                userId: UUID(uuidString: reactionData.user_id) ?? UUID(),
                mealId: meal.id,
                reactionType: ReactionType(rawValue: reactionData.reaction_type) ?? .like,
                createdAt: Date()
            )
        } ?? []
        
        // Check if current user has reacted
        let _ = reactions.first { $0.userId == currentUserId }
        
        // Count reactions by type
        var reactionCounts: [ReactionType: Int] = [:]
        for reaction in reactions {
            reactionCounts[reaction.reactionType, default: 0] += 1
        }
        
        return MealWithDetails(
            meal: meal,
            user: user,
            restaurant: restaurant,
            photos: photos,
            reactions: reactions,
            distance: Int(distance)
        )
    }
    
    print("📊 Returning \(mealDetails.count) meals within radius")
    return mealDetails.sorted { $0.meal.eatenAt > $1.meal.eatenAt }
}

    func fetchMealsForRestaurant(restaurantId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard supabase.currentUser?.id != nil else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            // Query model types are now in Models/QueryModels.swift
            
            // Query all meals for this specific restaurant
            let queryResult: [MealQueryResult] = try await supabase.client
                .from("meals")
                .select("""
                    *,
                    users!user_id(*),
                    restaurants!restaurant_id(*),
                    photos(*),
                    meal_reactions(*)
                """)
                .eq("restaurant_id", value: restaurantId)
                .eq("privacy", value: "public")
                .order("eaten_at", ascending: false)
                .execute()
                .value
            
            print("🍽️ Found \(queryResult.count) meals for restaurant \(restaurantId)")
            
            // Convert to MealWithDetails
            let mealDetails = queryResult.compactMap { result -> MealWithDetails? in
                guard let userData = result.users,
                      let restaurantData = result.restaurants else {
                    return nil
                }
                
                // Parse dates
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                // Create User
                let user = User(
                    id: UUID(uuidString: userData.id) ?? UUID(),
                    username: userData.username,
                    displayName: userData.display_name,
                    bio: userData.bio,
                    avatarUrl: userData.avatar_url,
                    locationEnabled: true,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                // Create Location from coordinates
                let locationPoint = LocationPoint(
                    latitude: restaurantData.latitude ?? 0,
                    longitude: restaurantData.longitude ?? 0
                )
                
                // Create Restaurant
                let restaurant = Restaurant(
                    id: UUID(uuidString: restaurantData.id) ?? UUID(),
                    googlePlaceId: restaurantData.google_place_id,
                    name: restaurantData.name,
                    address: restaurantData.address,
                    city: restaurantData.city,
                    state: restaurantData.state,
                    postalCode: nil,
                    country: "US",
                    phone: nil,
                    location: locationPoint,
                    rating: restaurantData.rating,
                    priceRange: restaurantData.price_range,
                    categories: [],
                    hours: nil,
                    googleMapsUrl: restaurantData.google_maps_url,
                    imageUrl: restaurantData.image_url,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                // Create Meal
                let meal = Meal(
                    id: UUID(uuidString: result.id) ?? UUID(),
                    userId: UUID(uuidString: result.user_id) ?? UUID(),
                    restaurant: restaurant,
                    mealType: MealType(rawValue: result.meal_type) ?? .restaurant,
                    title: result.title,
                    description: result.description,
                    ingredients: result.ingredients,
                    tags: result.tags ?? [],
                    privacy: .public,
                    location: locationPoint,
                    rating: result.rating,
                    status: .published,
                    cost: result.cost.map { Decimal($0) },
                    eatenAt: dateFormatter.date(from: result.eaten_at) ?? Date(),
                    createdAt: dateFormatter.date(from: result.created_at) ?? Date(),
                    updatedAt: dateFormatter.date(from: result.updated_at) ?? Date()
                )
                
                // Create Photos
                let photos = result.photos?.map { photoData in
                    Photo(
                        id: UUID(uuidString: photoData.id) ?? UUID(),
                        mealId: meal.id,
                        collaborativeMealId: photoData.collaborative_meal_id.flatMap { UUID(uuidString: $0) },
                        userId: UUID(uuidString: photoData.user_id) ?? UUID(),
                        storagePath: photoData.storage_path,
                        url: photoData.url,
                        altText: photoData.alt_text,
                        isPrimary: photoData.is_primary ?? false,
                        course: photoData.course.flatMap { Course(rawValue: $0) },
                        createdAt: dateFormatter.date(from: photoData.created_at ?? "") ?? Date()
                    )
                } ?? []
                
                // Create Reactions
                let reactions = result.meal_reactions?.map { reactionData in
                    MealReaction(
                        id: UUID(uuidString: reactionData.id) ?? UUID(),
                        userId: UUID(uuidString: reactionData.user_id) ?? UUID(),
                        mealId: meal.id,
                        reactionType: ReactionType(rawValue: reactionData.reaction_type) ?? .like,
                        createdAt: Date()
                    )
                } ?? []
                
                // Calculate distance if we have user location
                let distance: Int? = nil // Restaurant detail view doesn't need distance
                
                return MealWithDetails(
                    meal: meal,
                    user: user,
                    restaurant: restaurant,
                    photos: photos,
                    reactions: reactions,
                    distance: distance ?? 0
                )
            }
            
            // Store in a restaurant-specific cache or update nearbyMeals
            // For now, we'll update nearbyMeals to include all restaurant meals
            self.nearbyMeals = self.nearbyMeals.filter { $0.restaurant?.id.uuidString != restaurantId } + mealDetails
            
        } catch {
            self.error = error
            print("❌ Failed to fetch meals for restaurant: \(error)")
        }
    }
    
    func getMealsForRestaurant(restaurantId: String) -> [MealWithDetails] {
        // Return cached meals for this specific restaurant from nearbyMeals
        return nearbyMeals.filter { $0.restaurant?.id.uuidString == restaurantId }
            .sorted { $0.meal.eatenAt > $1.meal.eatenAt }
    }
}

// MARK: - MealWithDetails Extension

