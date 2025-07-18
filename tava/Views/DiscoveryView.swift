import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    
    @State private var searchText = ""
    @State private var selectedCategory: DiscoveryCategory = .all
    @State private var showingProfile = false
    
    enum DiscoveryCategory: String, CaseIterable {
        case all = "All"
        case people = "People"
        case restaurants = "Restaurants"
        case meals = "Meals"
        case trending = "Trending"
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
                .environmentObject(googlePlacesService)
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
    
    private var allContentView: some View {
        VStack(spacing: 20) {
            // Trending Section
            SectionHeader(title: "Trending Now", action: {
                selectedCategory = .trending
            })
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { index in
                        TrendingCard(index: index)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Discover People Section
            SectionHeader(title: "Discover People", action: {
                selectedCategory = .people
            })
            
            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    PersonCard(index: index)
                }
            }
            
            // Popular Restaurants Section
            SectionHeader(title: "Popular Restaurants", action: {
                selectedCategory = .restaurants
            })
            
            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    RestaurantCard(index: index)
                }
            }
        }
    }
    
    private var peopleContentView: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<10) { index in
                PersonCard(index: index)
            }
        }
    }
    
    private var restaurantsContentView: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<10) { index in
                RestaurantCard(index: index)
            }
        }
    }
    
    private var mealsContentView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(0..<20) { index in
                MealDiscoveryCard(index: index)
            }
        }
    }
    
    private var trendingContentView: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<10) { index in
                TrendingCard(index: index)
            }
        }
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
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.7))
                .frame(width: 50, height: 50)
                .overlay(
                    Text("\(index + 1)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("User \(index + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Food enthusiast • \(Int.random(in: 10...100)) mutual friends")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Follow") {
                // Follow action
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.orange)
            .cornerRadius(20)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

struct RestaurantCard: View {
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(.orange)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Restaurant \(index + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Italian • $$ • 4.5⭐ • 0.5 mi away")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

struct TrendingCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.3))
                .frame(width: 140, height: 140)
                .overlay(
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                )
            
            Text("Trending Meal \(index + 1)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text("\(Int.random(in: 100...1000)) likes")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 140)
    }
}

struct MealDiscoveryCard: View {
    let index: Int
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(.orange)
                )
            
            Text("Meal \(index + 1)")
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