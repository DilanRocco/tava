import SwiftUI
import CoreLocation
import MessageUI

enum DiscoveryCategory: String, CaseIterable {
    case all = "All"
    case people = "People"
    case restaurants = "Restaurants"
    case meals = "Meals"
    case trending = "Trending"
    case contacts = "Contacts"
}
    
struct DiscoveryView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    
    @StateObject private var discoveryService: HybridDiscoveryFeedService
    @StateObject private var contactService: ContactService
    
    @State private var searchText = ""
    @State private var selectedCategory: DiscoveryCategory = .all
    @State private var showingProfile = false
    @State private var showingContactsSheet = false
    @State private var showingMessageComposer = false
    @State private var selectedContactForInvite: Contact?
    
    init() {
        self._discoveryService = StateObject(wrappedValue: HybridDiscoveryFeedService(supabase: SupabaseClient.shared))
        self._contactService = StateObject(wrappedValue: ContactService(supabase: SupabaseClient.shared))
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
            NavigationView {
                ProfileView()
                    .environmentObject(supabase)
                    .environmentObject(locationService)
                    .environmentObject(mealService)
            }
        }
        .sheet(isPresented: $showingContactsSheet) {
            ContactsSheet()
                .environmentObject(contactService)
        }
        .sheet(isPresented: $showingMessageComposer) {
            if let contact = selectedContactForInvite {
                MessageComposerView(contact: contact) { success in
                    if success {
                        Task {
                            await contactService.sendInvite(to: contact)
                        }
                    }
                    showingMessageComposer = false
                    selectedContactForInvite = nil
                }
            }
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
        VStack(spacing: 16) {
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
                
                VStack(spacing: 4) {
                    Text("Tava")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Discover • Connect • Share")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    showingContactsSheet = true
                }) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
            }
            
            // Contact sync banner if contacts not loaded
            if contactService.contactsPermissionStatus != .authorized && !contactService.contacts.isEmpty == false {
                contactSyncBanner
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
            if !searchText.isEmpty {
                // Search Results
                if discoveryService.searchLoading {
                    LoadingView()
                        .padding(.top, 40)
                } else if discoveryService.searchResults.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results Found",
                        subtitle: "Try adjusting your search terms or browse by category"
                    )
                    .foregroundColor(.white)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(discoveryService.searchResults) { item in
                            searchResultCard(for: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
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
                    case .contacts:
                        contactsContentView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .refreshable {
            await discoveryService.refreshCurrentCategory(selectedCategory)
        }
    }
    
    private var allContentView: some View {
        VStack(spacing: 24) {
            if discoveryService.mainFeedLoading {
                LoadingView()
                    .padding(.top, 40)
            } else {
                // Trending Section
                if !discoveryService.trendingMeals.isEmpty {
                    VStack(spacing: 16) {
                        SectionHeader(title: "Trending Now", action: {
                            selectedCategory = .trending
                        })
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(discoveryService.trendingMeals.prefix(5)) { meal in
                                    TrendingCard(meal: meal)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Discover People Section
                if !discoveryService.trendingPeople.isEmpty {
                    VStack(spacing: 16) {
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
                        }
                    }
                }
                
                // Popular Restaurants Section
                if !discoveryService.popularRestaurants.isEmpty {
                    VStack(spacing: 16) {
                        SectionHeader(title: "Popular Restaurants", action: {
                            selectedCategory = .restaurants
                        })
                        
                        VStack(spacing: 12) {
                            ForEach(discoveryService.popularRestaurants.prefix(3)) { restaurant in
                                RestaurantCard(restaurant: restaurant)
                            }
                        }
                    }
                }
                
                // Show empty state if no content
                if discoveryService.trendingMeals.isEmpty && 
                   discoveryService.trendingPeople.isEmpty && 
                   discoveryService.popularRestaurants.isEmpty {
                    EmptyStateView(
                        icon: "globe.americas",
                        title: "Welcome to Tava!",
                        subtitle: "Start by exploring restaurants, connecting with friends, or sharing your first meal"
                    )
                    .foregroundColor(.white)
                    .padding(.top, 40)
                }
            }
        }
    }
    
    private var peopleContentView: some View {
        LazyVStack(spacing: 12) {
            if discoveryService.peopleLoading {
                LoadingView()
                    .padding(.top, 40)
            } else if discoveryService.trendingPeople.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No People Found",
                    subtitle: "Invite friends to join you on Tava and discover great meals together!"
                )
                .foregroundColor(.white)
            } else {
                ForEach(discoveryService.trendingPeople) { person in
                    PersonCard(person: person) {
                        Task {
                            await discoveryService.toggleFollow(for: person)
                        }
                    }
                }
            }
        }
    }
    
    private var restaurantsContentView: some View {
        LazyVStack(spacing: 12) {
            if discoveryService.restaurantsLoading {
                LoadingView()
                    .padding(.top, 40)
            } else if discoveryService.popularRestaurants.isEmpty {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "No Restaurants Found",
                    subtitle: "We're still finding great restaurants near you. Check back soon!"
                )
                .foregroundColor(.white)
            } else {
                ForEach(discoveryService.popularRestaurants) { restaurant in
                    RestaurantCard(restaurant: restaurant)
                }
            }
        }
    }
    
    private var mealsContentView: some View {
        Group {
            if discoveryService.mealsLoading {
                LoadingView()
                    .padding(.top, 40)
            } else if discoveryService.trendingMeals.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle",
                    title: "No Meals Yet",
                    subtitle: "Start exploring and sharing your favorite meals!"
                )
                .foregroundColor(.white)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    ForEach(discoveryService.trendingMeals) { meal in
                        MealDiscoveryCard(meal: meal)
                    }
                }
            }
        }
    }
    
    private var trendingContentView: some View {
        LazyVStack(spacing: 12) {
            if discoveryService.mealsLoading {
                LoadingView()
                    .padding(.top, 40)
            } else if discoveryService.trendingMeals.isEmpty {
                EmptyStateView(
                    icon: "flame",
                    title: "Nothing Trending Yet",
                    subtitle: "Be the first to share amazing meals and start the trend!"
                )
                .foregroundColor(.white)
            } else {
                ForEach(discoveryService.trendingMeals) { meal in
                    TrendingCard(meal: meal)
                }
            }
        }
    }
    
    private var contactSyncBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.badge.plus")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Find Friends on Tava")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Connect with friends and discover new meals together")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Sync") {
                Task {
                    let granted = await contactService.requestContactsPermission()
                    if granted {
                        await contactService.loadContacts()
                    }
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .cornerRadius(20)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private var contactsContentView: some View {
        LazyVStack(spacing: 16) {
            if contactService.contactsPermissionStatus != .authorized {
                contactPermissionView
            } else if contactService.isLoadingContacts {
                LoadingView()
            } else {
                contactsListView
            }
        }
    }
    
    private var contactPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Find Friends on Tava")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Connect your contacts to find friends who are already on Tava and invite those who aren't")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button("Connect Contacts") {
                Task {
                    let granted = await contactService.requestContactsPermission()
                    if granted {
                        await contactService.loadContacts()
                    }
                }
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
    
    private var contactsListView: some View {
        VStack(spacing: 20) {
            // Friends on Tava section
            if !contactService.contactsOnApp().isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Friends on Tava")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(contactService.contactsOnApp().count)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    ForEach(contactService.contactsOnApp()) { contact in
                        ContactCard(contact: contact, isOnApp: true) {
                            if let userId = contact.userId {
                                Task {
                                    await contactService.sendFriendRequest(to: userId)
                                }
                            }
                        }
                    }
                }
            }
            
            // Invite friends section
            if !contactService.contactsNotOnApp().isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Invite to Tava")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(contactService.contactsNotOnApp().count)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    ForEach(contactService.contactsNotOnApp().prefix(10)) { contact in
                        ContactCard(contact: contact, isOnApp: false) {
                            selectedContactForInvite = contact
                            showingMessageComposer = true
                        }
                    }
                    
                    if contactService.contactsNotOnApp().count > 10 {
                        Button("Show All (\(contactService.contactsNotOnApp().count))") {
                            // Show all contacts
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    }
                }
            }
            
            if contactService.contacts.isEmpty {
                Text("No contacts found")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeData() async {
        await discoveryService.loadMainDiscoveryFeed(refresh: true)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await discoveryService.loadTrendingPeople(refresh: true)
            }
            group.addTask {
                await discoveryService.loadPopularRestaurants(
                    refresh: true,
                    loadMore: false,
                    location: locationService.location?.coordinate
                )
            }
            group.addTask {
                await discoveryService.loadTrendingMeals(refresh: true)
            }
        }
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
        case .contacts:
            if contactService.contactsPermissionStatus == .authorized {
                await contactService.loadContacts()
            }
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
    var person: DiscoveryPerson
    var onFollow: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.7))
                .frame(width: 50, height: 50)
                .overlay(
                    Group {
                        if let avatarUrl = person.avatarUrl {
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
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        }
                    }
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(person.username)
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
                Text(person.isFollowing ? "Following" : "Follow")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(person.isFollowing ? Color.gray : Color.orange)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
    
    private func buildPersonSubtitle() -> String {
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
}

struct RestaurantCard: View {
    var restaurant: DiscoveryRestaurant
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Group {
                        if let imageUrl = restaurant.imageUrl {
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
                Text(restaurant.name)
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
        var parts: [String] = []
        
        if !restaurant.categories.isEmpty {
            parts.append(restaurant.categories.first!)
        }
        
        parts.append(String(repeating: "$", count: restaurant.priceRange))
        
        if let rating = restaurant.rating {
            parts.append("\(String(format: "%.1f", rating))⭐")
        }
        
        if let distance = restaurant.distance {
            parts.append("\(String(format: "%.1f", distance)) mi away")
        }
        
        return parts.joined(separator: " • ")
    }
}

struct TrendingCard: View {
    var meal: DiscoveryMeal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.3))
                .frame(width: 140, height: 140)
                .overlay(
                    Group {
                        if let imageUrl = meal.imageUrl {
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
            
            Text(meal.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text("\(meal.likesCount) likes")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 140)
    }
}

struct MealDiscoveryCard: View {
    var meal: DiscoveryMeal
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Group {
                        if let imageUrl = meal.imageUrl {
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
            
            Text(meal.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
        }
    }
}

// MARK: - Contact Components

struct ContactCard: View {
    let contact: Contact
    let isOnApp: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isOnApp ? Color.orange.opacity(0.7) : Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(contact.displayName.prefix(1).uppercased()))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let phone = contact.phoneNumber {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if let email = contact.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: action) {
                Text(isOnApp ? "Add Friend" : "Invite")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(isOnApp ? Color.orange : Color.blue)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

struct ContactsSheet: View {
    @EnvironmentObject var contactService: ContactService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if contactService.contactsPermissionStatus != .authorized {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Connect your contacts to find friends on Tava")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Button("Allow Access") {
                            Task {
                                let granted = await contactService.requestContactsPermission()
                                if granted {
                                    await contactService.loadContacts()
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                } else {
                    List {
                        Section("Friends on Tava (\(contactService.contactsOnApp().count))") {
                            ForEach(contactService.contactsOnApp()) { contact in
                                ContactRow(contact: contact, isOnApp: true)
                            }
                        }
                        
                        Section("Invite to Tava (\(contactService.contactsNotOnApp().count))") {
                            ForEach(contactService.contactsNotOnApp()) { contact in
                                ContactRow(contact: contact, isOnApp: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    let isOnApp: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(contact.displayName)
                    .font(.body)
                
                if let phone = contact.phoneNumber {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isOnApp {
                Button("Add Friend") {
                    // Add friend action
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            } else {
                Button("Invite") {
                    // Invite action
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
}

struct MessageComposerView: UIViewControllerRepresentable {
    let contact: Contact
    let completion: (Bool) -> Void
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = context.coordinator
        
        if let phoneNumber = contact.phoneNumber {
            composer.recipients = [phoneNumber]
        }
        
        composer.body = "Hey! I'm using Tava to discover and share amazing meals. Join me on the app! Download it here: https://apps.apple.com/app/tava"
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let completion: (Bool) -> Void
        
        init(completion: @escaping (Bool) -> Void) {
            self.completion = completion
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.completion(result == .sent)
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading contacts...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
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