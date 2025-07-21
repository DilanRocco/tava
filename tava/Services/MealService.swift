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
    
    // MARK: - Feed Operations
    
    func fetchFeedData(limit: Int = 20, offset: Int = 0) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let currentUserId = supabase.currentUser?.id else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            
            struct FeedParams: Codable {
                let user_uuid: String
                let limit_count: Int
                let offset_count: Int
            }
            
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
    
    // Add these models and methods to your MealService class
    
    // MARK: - Comment Models
    struct CommentData: Codable, Identifiable {
        let meal_id: String
        let comment_id: String
        let parent_comment_id: String?
        let user_id: String
        let username: String
        let display_name: String?
        let avatar_url: String?
        let content: String
        let created_at: Date
        let updated_at: Date
        let likes_count: Int
        let replies_count: Int
        let user_has_liked: Bool
        
        var id: String { comment_id }
        
        func toComment() -> Comment {
            return Comment(
                id: UUID(uuidString: comment_id) ?? UUID(),
                mealId: UUID(uuidString: meal_id) ?? UUID(),
                parentCommentId: parent_comment_id != nil ? UUID(uuidString: parent_comment_id!) : nil,
                userId: UUID(uuidString: user_id) ?? UUID(),
                username: username,
                displayName: display_name,
                avatarUrl: avatar_url,
                content: content,
                createdAt: created_at,
                updatedAt: updated_at,
                likesCount: likes_count,
                repliesCount: replies_count,
                userHasLiked: user_has_liked,
                replies: []
            )
        }
    }
    
    
    
    // Add these published properties to MealService
    
    
    // MARK: - Comment Operations
    
    func fetchComments(for mealId: String, limit: Int = 20, offset: Int = 0) async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        
        do {
            struct CommentParams: Codable {
                let target_meal_id: String
                let parent_limit: Int
                let parent_offset: Int
            }
            
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
            let response: [CommentData] = try await supabase.client.rpc(
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
            struct ReplyParams: Codable {
                let target_parent_id: String
                let reply_limit: Int
                let reply_offset: Int
            }
            
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
            
            let response: [CommentData] = try await supabase.client.rpc(
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
            struct AddCommentParams: Codable {
                let target_meal_id: String
                let comment_content: String
                let parent_id: String?
            }
            
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
        
        struct CommentReaction: Codable {
            let id: String
            let user_id: String
            let comment_id: String
            let reaction_type: String
            let created_at: String
        }
        
        let reaction = CommentReaction(
            id: UUID().uuidString,
            user_id: currentUserId.uuidString,
            comment_id: commentId,
            reaction_type: "like",
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
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
