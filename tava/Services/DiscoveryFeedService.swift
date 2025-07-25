import Foundation
import SwiftUI
import CoreLocation

// MARK: - Discovery Models




enum TrendingTimeframe: String, CaseIterable {
    case day = "day"
    case week = "week"
    case month = "month"
    case all = "all"
}

// MARK: - Response Models

struct MainFeedResponse: Codable {
    let items: [DiscoveryFeedItem]
    let hasMore: Bool
    let nextCursor: String?
}

struct PeopleResponse: Codable {
    let people: [DiscoveryPerson]
    let hasMore: Bool
    let nextCursor: String?
}

struct RestaurantsResponse: Codable {
    let restaurants: [DiscoveryRestaurant]
    let hasMore: Bool
    let nextCursor: String?
}

struct MealsResponse: Codable {
    let meals: [DiscoveryMeal]
    let hasMore: Bool
    let nextCursor: String?
}

struct SearchResponse: Codable {
    let items: [DiscoveryFeedItem]
    let totalCount: Int
    let hasMore: Bool
}

struct ActionResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Search Filters

struct SearchFilters: Codable {
    let location: CLLocationCoordinate2D?
    let priceRange: ClosedRange<Int>?
    let rating: Double?
    let distance: Double?
    let cuisineTypes: [String]?
    let dietaryRestrictions: [String]?
}

// MARK: - Hybrid Discovery Feed Service

@MainActor
class HybridDiscoveryFeedService: ObservableObject {
    // MARK: - Published Properties
    
    // Main hybrid feed (All tab)
    @Published var mainFeed: [DiscoveryFeedItem] = []
    @Published var mainFeedLoading = false
    @Published var mainFeedError: Error?
    
    // Category-specific data
    @Published var trendingPeople: [DiscoveryPerson] = []
    @Published var peopleLoading = false
    @Published var peopleError: Error?
    @Published var peopleCursor: String?
    @Published var peopleHasMore = true
    
    @Published var popularRestaurants: [DiscoveryRestaurant] = []
    @Published var restaurantsLoading = false
    @Published var restaurantsError: Error?
    @Published var restaurantsCursor: String?
    @Published var restaurantsHasMore = true
    
    @Published var trendingMeals: [DiscoveryMeal] = []
    @Published var mealsLoading = false
    @Published var mealsError: Error?
    @Published var mealsCursor: String?
    @Published var mealsHasMore = true
    
    // Search
    @Published var searchResults: [DiscoveryFeedItem] = []
    @Published var searchLoading = false
    @Published var searchError: Error?
    
    // General state
    @Published var isRefreshing = false
    
    private let supabase: SupabaseClient
    private var mainFeedCursor: String?
    private var mainFeedHasMore = true
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    // MARK: - Main Hybrid Feed (All Tab)
    
    func loadMainDiscoveryFeed(refresh: Bool = false) async {
        guard !mainFeedLoading else { return }
        
        if refresh {
            mainFeedCursor = nil
            mainFeedHasMore = true
            mainFeed = []
        }
        
        guard mainFeedHasMore else { return }
        
        mainFeedLoading = true
        mainFeedError = nil
        
        do {
            let response = try await callEdgeFunction(
                "discovery-feed",
                parameters: [
                    "cursor": mainFeedCursor as Any,
                    "limit": 20
                ]
            )
            
            let feedResponse = try JSONDecoder().decode(MainFeedResponse.self, from: response)
            
            if refresh {
                mainFeed = feedResponse.items
            } else {
                mainFeed.append(contentsOf: feedResponse.items)
            }
            
            mainFeedCursor = feedResponse.nextCursor
            mainFeedHasMore = feedResponse.hasMore
            
        } catch {
            mainFeedError = error
            print("Main feed error: \(error)")
        }
        
        mainFeedLoading = false
    }
    
    // MARK: - Category-Specific Loading
    
    func loadTrendingPeople(refresh: Bool = false, loadMore: Bool = false) async {
        guard !peopleLoading else { return }
        
        if refresh {
            peopleCursor = nil
            peopleHasMore = true
            trendingPeople = []
        }
        
        guard peopleHasMore || refresh else { return }
        
        peopleLoading = true
        peopleError = nil
        
        do {
            let response = try await callEdgeFunction(
                "discovery-people",
                parameters: [
                    "cursor": peopleCursor as Any,
                    "limit": loadMore ? 10 : 20,
                    "include_mutual_friends": true
                ]
            )
            
            let peopleResponse = try JSONDecoder().decode(PeopleResponse.self, from: response)
            
            if refresh || !loadMore {
                trendingPeople = peopleResponse.people
            } else {
                trendingPeople.append(contentsOf: peopleResponse.people)
            }
            
            peopleCursor = peopleResponse.nextCursor
            peopleHasMore = peopleResponse.hasMore
            
        } catch {
            peopleError = error
            print("People loading error: \(error)")
        }
        
        peopleLoading = false
    }
    
    func loadPopularRestaurants(refresh: Bool = false, loadMore: Bool = false, location: CLLocationCoordinate2D? = nil) async {
        guard !restaurantsLoading else { return }
        
        if refresh {
            restaurantsCursor = nil
            restaurantsHasMore = true
            popularRestaurants = []
        }
        
        guard restaurantsHasMore || refresh else { return }
        
        restaurantsLoading = true
        restaurantsError = nil
        
        do {
            var parameters: [String: Any] = [
                "cursor": restaurantsCursor as Any,
                "limit": loadMore ? 10 : 20
            ]
            
            if let location = location {
                parameters["latitude"] = location.latitude
                parameters["longitude"] = location.longitude
                parameters["radius_miles"] = 25
            }
            
            let response = try await callEdgeFunction("discovery-restaurants", parameters: parameters)
            let restaurantsResponse = try JSONDecoder().decode(RestaurantsResponse.self, from: response)
            
            if refresh || !loadMore {
                popularRestaurants = restaurantsResponse.restaurants
            } else {
                popularRestaurants.append(contentsOf: restaurantsResponse.restaurants)
            }
            
            restaurantsCursor = restaurantsResponse.nextCursor
            restaurantsHasMore = restaurantsResponse.hasMore
            
        } catch {
            restaurantsError = error
            print("Restaurants loading error: \(error)")
        }
        
        restaurantsLoading = false
    }
    
    func loadTrendingMeals(refresh: Bool = false, loadMore: Bool = false, timeframe: TrendingTimeframe = .week) async {
        guard !mealsLoading else { return }
        
        if refresh {
            mealsCursor = nil
            mealsHasMore = true
            trendingMeals = []
        }
        
        guard mealsHasMore || refresh else { return }
        
        mealsLoading = true
        mealsError = nil
        
        do {
            let response = try await callEdgeFunction(
                "discovery-meals",
                parameters: [
                    "cursor": mealsCursor as Any,
                    "limit": loadMore ? 10 : 20,
                    "timeframe": timeframe.rawValue,
                    "sort": "trending"
                ]
            )
            
            let mealsResponse = try JSONDecoder().decode(MealsResponse.self, from: response)
            
            if refresh || !loadMore {
                trendingMeals = mealsResponse.meals
            } else {
                trendingMeals.append(contentsOf: mealsResponse.meals)
            }
            
            mealsCursor = mealsResponse.nextCursor
            mealsHasMore = mealsResponse.hasMore
            
        } catch {
            mealsError = error
            print("Meals loading error: \(error)")
        }
        
        mealsLoading = false
    }
    
    // MARK: - Search
    
    func searchDiscovery(query: String, category: DiscoveryCategory = .all, filters: SearchFilters? = nil) async {
        guard !query.isEmpty, !searchLoading else { return }
        
        searchLoading = true
        searchError = nil
        searchResults = []
        
        do {
            var parameters: [String: Any] = [
                "query": query,
                "category": category.rawValue,
                "limit": 20
            ]
            
            if let filters = filters {
                parameters["filters"] = try JSONEncoder().encode(filters)
            }
            
            let response = try await callEdgeFunction("discovery-search", parameters: parameters)
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: response)
            
            searchResults = searchResponse.items
            
        } catch {
            searchError = error
            print("Search error: \(error)")
        }
        
        searchLoading = false
    }
    
    // MARK: - User Actions
    
    func toggleFollow(for person: DiscoveryPerson) async {
        let wasFollowing = person.isFollowing
        let newFollowingState = !wasFollowing
        
        // Optimistic update using functional approach
        updatePerson(withId: person.id) { person in
            person.updatingFollowStatus(isFollowing: newFollowingState)
        }
        
        updateMainFeedItem(
            where: { $0.type == .suggestedPerson && $0.data.userId == person.id }
        ) { item in
            item.updatingFollowStatus(isFollowing: newFollowingState)
        }
        
        do {
            try await callEdgeFunction(
                "user-actions",
                parameters: [
                    "action": wasFollowing ? "unfollow" : "follow",
                    "target_user_id": person.id
                ]
            )
            // Success - optimistic update was correct
            
        } catch {
            // Revert optimistic update
            updatePerson(withId: person.id) { person in
                person.updatingFollowStatus(isFollowing: wasFollowing)
            }
            
            updateMainFeedItem(
                where: { $0.type == .suggestedPerson && $0.data.userId == person.id }
            ) { item in
                item.updatingFollowStatus(isFollowing: wasFollowing)
            }
            
            print("Follow action error: \(error)")
        }
    }
    
    func toggleMealLike(for meal: DiscoveryMeal) async {
        let wasLiked = false // You'd need to track this in your meal model
        let newLikesCount = meal.likesCount + (wasLiked ? -1 : 1)
        
        // Optimistic update
        updateMealEngagement(mealId: meal.id, likesCount: newLikesCount)
        
        do {
            try await callEdgeFunction(
                "user-actions",
                parameters: [
                    "action": "toggle_like",
                    "meal_id": meal.id
                ]
            )
        } catch {
            // Revert on error
            updateMealEngagement(mealId: meal.id, likesCount: meal.likesCount)
            print("Like action error: \(error)")
        }
    }
    
    func toggleBookmark(for meal: DiscoveryMeal) async {
        do {
            try await callEdgeFunction(
                "user-actions",
                parameters: [
                    "action": "toggle_bookmark",
                    "meal_id": meal.id
                ]
            )
        } catch {
            print("Bookmark error: \(error)")
        }
    }
    
    // MARK: - Refresh and Load More
    
    func refreshCurrentCategory(_ category: DiscoveryCategory) async {
        isRefreshing = true
        
        switch category {
        case .all:
            await loadMainDiscoveryFeed(refresh: true)
        case .people:
            await loadTrendingPeople(refresh: true)
        case .restaurants:
            await loadPopularRestaurants(refresh: true)
        case .meals, .trending:
            await loadTrendingMeals(refresh: true)
        }
        
        isRefreshing = false
    }
    
    func loadMoreContent(for category: DiscoveryCategory) async {
        switch category {
        case .all:
            await loadMainDiscoveryFeed(refresh: false)
        case .people:
            await loadTrendingPeople(loadMore: true)
        case .restaurants:
            await loadPopularRestaurants(loadMore: true)
        case .meals, .trending:
            await loadTrendingMeals(loadMore: true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updatePerson(withId personId: String, transform: (DiscoveryPerson) -> DiscoveryPerson) {
        trendingPeople = trendingPeople.map { person in
            person.id == personId ? transform(person) : person
        }
    }
    
    private func updateMainFeedItem(where predicate: (DiscoveryFeedItem) -> Bool, transform: (DiscoveryFeedItem) -> DiscoveryFeedItem) {
        mainFeed = mainFeed.map { item in
            predicate(item) ? transform(item) : item
        }
        
        searchResults = searchResults.map { item in
            predicate(item) ? transform(item) : item
        }
    }
    
    private func updateMealEngagement(mealId: String, likesCount: Int? = nil, commentsCount: Int? = nil) {
        // Update trending meals
        if let likesCount = likesCount {
            trendingMeals = trendingMeals.map { meal in
                meal.id == mealId ? meal.updatingEngagement(likesCount: likesCount) : meal
            }
        }
        
        // Update in main feed
        mainFeed = mainFeed.map { item in
            if (item.type == .trendingMeal || item.type == .featuredMeal) && item.data.mealId == mealId {
                let updatedData = item.data.updatingMealEngagement(
                    likesCount: likesCount,
                    commentsCount: commentsCount
                )
                return item.updatingData(updatedData)
            }
            return item
        }
    }
    
    private func callEdgeFunction(_ functionName: String, parameters: [String: Any]) async throws -> Data {
        // Mock implementation - replace with actual Supabase call
        try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...2_000_000_000))
        
        // In real implementation:
        // let response = try await supabase.functions.invoke(functionName, parameters: parameters)
        // return response.data
        
        return try generateMockResponse(for: functionName, parameters: parameters)
    }
    
    private func generateMockResponse(for functionName: String, parameters: [String: Any]) throws -> Data {
        switch functionName {
        case "discovery-feed":
            let response = MainFeedResponse(
                items: generateMockFeedItems(count: 10),
                hasMore: Bool.random(),
                nextCursor: UUID().uuidString
            )
            return try JSONEncoder().encode(response)
            
        case "discovery-people":
            let response = PeopleResponse(
                people: generateMockPeople(count: 10),
                hasMore: Bool.random(),
                nextCursor: UUID().uuidString
            )
            return try JSONEncoder().encode(response)
            
        case "discovery-restaurants":
            let response = RestaurantsResponse(
                restaurants: generateMockRestaurants(count: 10),
                hasMore: Bool.random(),
                nextCursor: UUID().uuidString
            )
            return try JSONEncoder().encode(response)
            
        case "discovery-meals":
            let response = MealsResponse(
                meals: generateMockMeals(count: 10),
                hasMore: Bool.random(),
                nextCursor: UUID().uuidString
            )
            return try JSONEncoder().encode(response)
            
        case "discovery-search":
            let response = SearchResponse(
                items: generateMockFeedItems(count: 5),
                totalCount: 50,
                hasMore: true
            )
            return try JSONEncoder().encode(response)
            
        case "user-actions":
            let response = ActionResponse(success: true, message: "Action completed")
            return try JSONEncoder().encode(response)
            
        default:
            throw NSError(domain: "MockError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Function not found"])
        }
    }
    
    // MARK: - Mock Data Generators
    
    private func generateMockFeedItems(count: Int) -> [DiscoveryFeedItem] {
        return (0..<count).map { index in
            let type = DiscoveryItemType.allCases.randomElement() ?? .trendingMeal
            let data = generateMockData(for: type, index: index)
            
            return DiscoveryFeedItem(
                type: type,
                data: data,
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400)),
                priority: Int.random(in: 1...10)
            )
        }
    }
    
    private func generateMockPeople(count: Int) -> [DiscoveryPerson] {
        return (0..<count).map { index in
            DiscoveryPerson(
                id: UUID().uuidString,
                username: "foodie\(index + 1)",
                displayName: "Food Enthusiast \(index + 1)",
                bio: generateRandomBio(),
                avatarUrl: nil,
                followersCount: Int.random(in: 50...500),
                mutualFriendsCount: Int.random(in: 0...20),
                isFollowing: Bool.random(),
                recentMealsCount: Int.random(in: 5...50),
                joinedAt: Date().addingTimeInterval(-Double.random(in: 0...31536000))
            )
        }
    }
    
    private func generateMockRestaurants(count: Int) -> [DiscoveryRestaurant] {
        let cuisines = ["Italian", "Mexican", "Japanese", "Chinese", "American", "Thai", "Indian", "French"]
        
        return (0..<count).map { index in
            DiscoveryRestaurant(
                id: UUID().uuidString,
                name: "Restaurant \(index + 1)",
                address: "\(100 + index) Main St",
                city: "New York",
                rating: Double.random(in: 3.5...5.0),
                priceRange: Int.random(in: 1...4),
                categories: cuisines.shuffled().prefix(2).map({$0}),
                distance: Double.random(in: 0.1...5.0),
                imageUrl: nil,
                recentMealsCount: Int.random(in: 10...100),
                averageMealRating: Double.random(in: 3.0...5.0)
            )
        }
    }
    
    private func generateMockMeals(count: Int) -> [DiscoveryMeal] {
        return (0..<count).map { index in
            DiscoveryMeal(
                id: UUID().uuidString,
                title: "Amazing Meal \(index + 1)",
                description: "This was absolutely delicious! Perfect combination of flavors.",
                imageUrl: nil,
                rating: Int.random(in: 3...5),
                likesCount: Int.random(in: 10...500),
                commentsCount: Int.random(in: 0...50),
                tags: ["Italian", "Pasta", "Dinner"].shuffled().prefix(3).map({$0}),
                createdAt: Date().addingTimeInterval(-Double.random(in: 0...604800)),
                author: generateMockPeople(count: 1)[0],
                restaurant: nil
            )
        }
    }
    
    private func generateMockData(for type: DiscoveryItemType, index: Int) -> DiscoveryItemData {
        switch type {
        case .suggestedPerson:
            return DiscoveryItemData(
                userId: UUID().uuidString,
                username: "user\(index)",
                displayName: "User \(index)",
                avatarUrl: nil,
                bio: generateRandomBio(),
                followersCount: Int.random(in: 50...500),
                mutualFriendsCount: Int.random(in: 0...20),
                isFollowing: false,
                restaurantId: nil, restaurantName: nil, restaurantAddress: nil,
                restaurantRating: nil, restaurantPriceRange: nil, restaurantDistance: nil,
                restaurantImageUrl: nil, restaurantCategories: nil,
                mealId: nil, mealTitle: nil, mealDescription: nil,
                mealImageUrl: nil, mealRating: nil, mealLikesCount: nil,
                mealCommentsCount: nil, mealTags: nil, mealCreatedAt: nil, mealAuthor: nil,
                title: "User \(index)", subtitle: generateRandomBio(), imageUrl: nil, actionText: "Follow"
            )
            
        case .popularRestaurant:
            return DiscoveryItemData(
                userId: nil, username: nil, displayName: nil, avatarUrl: nil, bio: nil,
                followersCount: nil, mutualFriendsCount: nil, isFollowing: nil,
                restaurantId: UUID().uuidString,
                restaurantName: "Restaurant \(index)",
                restaurantAddress: "\(100 + index) Main St",
                restaurantRating: Double.random(in: 3.5...5.0),
                restaurantPriceRange: Int.random(in: 1...4),
                restaurantDistance: Double.random(in: 0.1...5.0),
                restaurantImageUrl: nil,
                restaurantCategories: ["Italian", "Casual Dining"],
                mealId: nil, mealTitle: nil, mealDescription: nil,
                mealImageUrl: nil, mealRating: nil, mealLikesCount: nil,
                mealCommentsCount: nil, mealTags: nil, mealCreatedAt: nil, mealAuthor: nil,
                title: "Restaurant \(index)", subtitle: "Italian • $$ • 4.5⭐", imageUrl: nil, actionText: nil
            )
            
        case .trendingMeal, .featuredMeal:
            return DiscoveryItemData(
                userId: nil, username: nil, displayName: nil, avatarUrl: nil, bio: nil,
                followersCount: nil, mutualFriendsCount: nil, isFollowing: nil,
                restaurantId: nil, restaurantName: nil, restaurantAddress: nil,
                restaurantRating: nil, restaurantPriceRange: nil, restaurantDistance: nil,
                restaurantImageUrl: nil, restaurantCategories: nil,
                mealId: UUID().uuidString,
                mealTitle: "Amazing Meal \(index)",
                mealDescription: "This was absolutely delicious!",
                mealImageUrl: nil,
                mealRating: Int.random(in: 3...5),
                mealLikesCount: Int.random(in: 10...500),
                mealCommentsCount: Int.random(in: 0...50),
                mealTags: ["Italian", "Pasta"],
                mealCreatedAt: Date(),
                mealAuthor: "chef\(index)",
                title: "Amazing Meal \(index)", subtitle: "\(Int.random(in: 10...500)) likes", imageUrl: nil, actionText: nil
            )
            
        case .nearbyActivity:
            return DiscoveryItemData(
                userId: nil, username: nil, displayName: nil, avatarUrl: nil, bio: nil,
                followersCount: nil, mutualFriendsCount: nil, isFollowing: nil,
                restaurantId: nil, restaurantName: nil, restaurantAddress: nil,
                restaurantRating: nil, restaurantPriceRange: nil, restaurantDistance: nil,
                restaurantImageUrl: nil, restaurantCategories: nil,
                mealId: nil, mealTitle: nil, mealDescription: nil,
                mealImageUrl: nil, mealRating: nil, mealLikesCount: nil,
                mealCommentsCount: nil, mealTags: nil, mealCreatedAt: nil, mealAuthor: nil,
                title: "Nearby Activity \(index)", subtitle: "Check out what's happening around you", imageUrl: nil, actionText: "Explore"
            )
        }
    }
    
    private func generateRandomBio() -> String {
        let bios = [
            "Food enthusiast and home chef",
            "Always hunting for the best local eats",
            "Pasta lover and wine connoisseur",
            "Plant-based foodie exploring NYC",
            "Professional chef sharing my favorites",
            "Weekend warrior in the kitchen",
            "Coffee addict and brunch expert"
        ]
        return bios.randomElement() ?? "Food lover"
    }
}

// MARK: - Extensions

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

extension Array where Element: Identifiable {
    func updating(itemWithId id: Element.ID, transform: (Element) -> Element) -> [Element] {
        return map { item in
            item.id == id ? transform(item) : item
        }
    }
}

// MARK: - Mock Dependencies (for compilation)
