import SwiftUI
import CoreLocation

  enum DiscoveryCategory: String, CaseIterable {
        case all = "All"
        case people = "People"
        case restaurants = "Restaurants"
        case meals = "Meals"
        case trending = "Trending"
    }
    
struct DiscoveryView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    
    @StateObject private var discoveryService: HybridDiscoveryFeedService
    
    @State private var searchText = ""
    @State private var selectedCategory: DiscoveryCategory = .all
    @State private var showingProfile = false
    
  
    
    init() {
        self._discoveryService = StateObject(wrappedValue: HybridDiscoveryFeedService(supabase: SupabaseClient.shared))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Profile Button
                headerView
                
                // Search Bar
                searchBarView
                
                // Category Filter
                categoryFilterView
                
                // Content
                contentView
            }
            .navigationBarHidden(true)
            .background(Color.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(supabase)
                .environmentObject(locationService)
                .environmentObject(mealService)
        }
        .task {
            await initializeData()
        }
        .onChange(of: selectedCategory) { _ in
            Task {
                await loadCategoryData()
            }
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                Task {
                    await discoveryService.searchDiscovery(query: newValue, category: selectedCategory)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                showingProfile = true
            }) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )
            }
            
            Spacer()
            
            Text("Discovery")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                // Notifications action
            }) {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search people, restaurants, meals...", text: $searchText)
                .foregroundColor(.white)
                .placeholder(when: searchText.isEmpty) {
                    Text("Search people, restaurants, meals...")
                        .foregroundColor(.gray)
                }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(DiscoveryCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }
    
    private var contentView: some View {
        ScrollView {
            if !searchText.isEmpty && !discoveryService.searchResults.isEmpty {
                // Search Results
                LazyVStack(spacing: 16) {
                    ForEach(discoveryService.searchResults) { item in
                        searchResultCard(for: item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            } else {
                // Regular content based on category
                LazyVStack(spacing: 16) {
                    switch selectedCategory {
                    case .all:
                        allContentView
                    case .people:
                        peopleContentView
                    case .restaurants:
                        restaurantsContentView
                    case .meals:
                        mealsContentView
                    case .trending:
                        trendingContentView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }
    
    private var allContentView: some View {
        VStack(spacing: 20) {
            // Trending Section
            SectionHeader(title: "Trending Now", action: {
                selectedCategory = .trending
            })
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(discoveryService.trendingMeals.prefix(5)) { meal in
                        TrendingCard(meal: meal)
                    }
                    // Fallback placeholders if no data
                    if discoveryService.trendingMeals.isEmpty {
                        ForEach(0..<5) { index in
                            TrendingCard(index: index)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Discover People Section
            SectionHeader(title: "Discover People", action: {
                selectedCategory = .people
            })
            
            VStack(spacing: 12) {
                ForEach(discoveryService.trendingPeople.prefix(3)) { person in
                    PersonCard(person: person) {
                        Task {
                            await discoveryService.toggleFollow(for: person)
                        }
                    }
                }
                // Fallback placeholders if no data
                if discoveryService.trendingPeople.isEmpty {
                    ForEach(0..<3) { index in
                        PersonCard(index: index)
                    }
                }
            }
            
            // Popular Restaurants Section
            SectionHeader(title: "Popular Restaurants", action: {
                selectedCategory = .restaurants
            })
            
            VStack(spacing: 12) {
                ForEach(discoveryService.popularRestaurants.prefix(3)) { restaurant in
                    RestaurantCard(restaurant: restaurant)
                }
                // Fallback placeholders if no data
                if discoveryService.popularRestaurants.isEmpty {
                    ForEach(0..<3) { index in
                        RestaurantCard(index: index)
                    }
                }
            }
        }
    }
    
    private var peopleContentView: some View {
        LazyVStack(spacing: 12) {
            ForEach(discoveryService.trendingPeople) { person in
                PersonCard(person: person) {
                    Task {
                        await discoveryService.toggleFollow(for: person)
                    }
                }
            }
            // Fallback placeholders if no data
            if discoveryService.trendingPeople.isEmpty {
                ForEach(0..<10) { index in
                    PersonCard(index: index)
                }
            }
        }
    }
    
    private var restaurantsContentView: some View {
        LazyVStack(spacing: 12) {
            ForEach(discoveryService.popularRestaurants) { restaurant in
                RestaurantCard(restaurant: restaurant)
            }
            // Fallback placeholders if no data
            if discoveryService.popularRestaurants.isEmpty {
                ForEach(0..<10) { index in
                    RestaurantCard(index: index)
                }
            }
        }
    }
    
    private var mealsContentView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(discoveryService.trendingMeals) { meal in
                MealDiscoveryCard(meal: meal)
            }
            // Fallback placeholders if no data
            if discoveryService.trendingMeals.isEmpty {
                ForEach(0..<20) { index in
                    MealDiscoveryCard(index: index)
                }
            }
        }
    }
    
    private var trendingContentView: some View {
        LazyVStack(spacing: 12) {
            ForEach(discoveryService.trendingMeals) { meal in
                TrendingCard(meal: meal)
            }
            // Fallback placeholders if no data
            if discoveryService.trendingMeals.isEmpty {
                ForEach(0..<10) { index in
                    TrendingCard(index: index)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeData() async {
        await discoveryService.loadMainDiscoveryFeed(refresh: true)
        
        async let peopleTask = discoveryService.loadTrendingPeople(refresh: true)
        async let restaurantsTask = discoveryService.loadPopularRestaurants(
            refresh: true,
            loadMore: false,
            location: locationService.location?.coordinate
        )
        async let mealsTask = discoveryService.loadTrendingMeals(refresh: true)
        
        await peopleTask
        await restaurantsTask
        await mealsTask
    }
    
    private func loadCategoryData() async {
        switch selectedCategory {
        case .all:
            break
        case .people:
            await discoveryService.loadTrendingPeople(refresh: true)
        case .restaurants:
            await discoveryService.loadPopularRestaurants(
                refresh: true,
                loadMore: false,
                location: locationService.location?.coordinate
            )
        case .meals, .trending:
            await discoveryService.loadTrendingMeals(refresh: true)
        }
    }
    
    private func searchResultCard(for item: DiscoveryFeedItem) -> some View {
        Group {
            switch item.type {
            case .suggestedPerson:
                if let person = createPersonFromData(item.data) {
                    PersonCard(person: person) {
                        Task {
                            await discoveryService.toggleFollow(for: person)
                        }
                    }
                }
            case .popularRestaurant:
                if let restaurant = createRestaurantFromData(item.data) {
                    RestaurantCard(restaurant: restaurant)
                }
            case .trendingMeal, .featuredMeal:
                if let meal = createMealFromData(item.data) {
                    TrendingCard(meal: meal)
                }
            case .nearbyActivity:
                EmptyView()
            }
        }
    }
    
    // Helper conversion functions
    private func createPersonFromData(_ data: DiscoveryItemData) -> DiscoveryPerson? {
        guard let userId = data.userId,
              let username = data.username else { return nil }
        
        return DiscoveryPerson(
            id: userId,
            username: username,
            displayName: data.displayName,
            bio: data.bio,
            avatarUrl: data.avatarUrl,
            followersCount: data.followersCount ?? 0,
            mutualFriendsCount: data.mutualFriendsCount ?? 0,
            isFollowing: data.isFollowing ?? false,
            recentMealsCount: 0,
            joinedAt: Date()
        )
    }
    
    private func createRestaurantFromData(_ data: DiscoveryItemData) -> DiscoveryRestaurant? {
        guard let restaurantId = data.restaurantId,
              let name = data.restaurantName else { return nil }
        
        return DiscoveryRestaurant(
            id: restaurantId,
            name: name,
            address: data.restaurantAddress ?? "",
            city: nil,
            rating: data.restaurantRating,
            priceRange: data.restaurantPriceRange ?? 1,
            categories: data.restaurantCategories ?? [],
            distance: data.restaurantDistance,
            imageUrl: data.restaurantImageUrl,
            recentMealsCount: 0,
            averageMealRating: nil
        )
    }
    
    private func createMealFromData(_ data: DiscoveryItemData) -> DiscoveryMeal? {
        guard let mealId = data.mealId,
              let title = data.mealTitle else { return nil }
        
        let author = DiscoveryPerson(
            id: UUID().uuidString,
            username: data.mealAuthor ?? "unknown",
            displayName: nil,
            bio: nil,
            avatarUrl: nil,
            followersCount: 0,
            mutualFriendsCount: 0,
            isFollowing: false,
            recentMealsCount: 0,
            joinedAt: Date()
        )
        
        return DiscoveryMeal(
            id: mealId,
            title: title,
            description: data.mealDescription,
            imageUrl: data.mealImageUrl,
            rating: data.mealRating,
            likesCount: data.mealLikesCount ?? 0,
            commentsCount: data.mealCommentsCount ?? 0,
            tags: data.mealTags ?? [],
            createdAt: data.mealCreatedAt ?? Date(),
            author: author,
            restaurant: nil
        )
    }
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color.clear)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .opacity(isSelected ? 0 : 1)
                )
        }
    }
}

struct SectionHeader: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button("See All", action: action)
                .font(.subheadline)
                .foregroundColor(.orange)
        }
    }
}

struct PersonCard: View {
    var index: Int? = nil
    var person: DiscoveryPerson? = nil
    var onFollow: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.7))
                .frame(width: 50, height: 50)
                .overlay(
                    Group {
                        if let person = person, let avatarUrl = person.avatarUrl {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            }
                            .clipShape(Circle())
                        } else {
                            Text("\(index != nil ? index! + 1 : 1)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(person?.username ?? "User \(index != nil ? index! + 1 : 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(buildPersonSubtitle())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                onFollow?()
            }) {
                Text(person?.isFollowing == true ? "Following" : "Follow")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(person?.isFollowing == true ? Color.gray : Color.orange)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private func buildPersonSubtitle() -> String {
        if let person = person {
            var parts: [String] = []
            if let bio = person.bio {
                parts.append(bio)
            } else {
                parts.append("Food enthusiast")
            }
            if person.mutualFriendsCount > 0 {
                parts.append("\(person.mutualFriendsCount) mutual friends")
            }
            return parts.joined(separator: " • ")
        }
        return "Food enthusiast • \(Int.random(in: 10...100)) mutual friends"
    }
}

struct RestaurantCard: View {
    var index: Int? = nil
    var restaurant: DiscoveryRestaurant? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Group {
                        if let restaurant = restaurant, let imageUrl = restaurant.imageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "fork.knife")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "fork.knife")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                    }
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant?.name ?? "Restaurant \(index != nil ? index! + 1 : 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(buildRestaurantSubtitle())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private func buildRestaurantSubtitle() -> String {
        if let restaurant = restaurant {
            var parts: [String] = []
            
            if !restaurant.categories.isEmpty {
                parts.append(restaurant.categories.first!)
            } else {
                parts.append("Italian")
            }
            
            parts.append(String(repeating: "$", count: restaurant.priceRange))
            
            if let rating = restaurant.rating {
                parts.append("\(rating)⭐")
            } else {
                parts.append("4.5⭐")
            }
            
            if let distance = restaurant.distance {
                parts.append("\(String(format: "%.1f", distance)) mi away")
            } else {
                parts.append("0.5 mi away")
            }
            
            return parts.joined(separator: " • ")
        }
        return "Italian • $$ • 4.5⭐ • 0.5 mi away"
    }
}

struct TrendingCard: View {
    var index: Int? = nil
    var meal: DiscoveryMeal? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.3))
                .frame(width: 140, height: 140)
                .overlay(
                    Group {
                        if let meal = meal, let imageUrl = meal.imageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "flame.fill")
                                    .font(.title)
                                    .foregroundColor(.orange)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "flame.fill")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                    }
                )
            
            Text(meal?.title ?? "Trending Meal \(index != nil ? index! + 1 : 1)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text("\(meal?.likesCount ?? Int.random(in: 100...1000)) likes")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 140)
    }
}

struct MealDiscoveryCard: View {
    var index: Int? = nil
    var meal: DiscoveryMeal? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Group {
                        if let meal = meal, let imageUrl = meal.imageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.orange)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.orange)
                        }
                    }
                )
            
            Text(meal?.title ?? "Meal \(index != nil ? index! + 1 : 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}