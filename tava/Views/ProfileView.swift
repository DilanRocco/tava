import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var mealService: MealService
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    profileHeader
                    
                    // Stats Section
                    statsSection
                    
                    // Content Tabs
                    contentTabs
                    
                    // Content based on selected tab
                    contentView
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .task {
            await mealService.fetchUserFeed()
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            Button(action: {
                showingEditProfile = true
            }) {
                if let avatarUrl = supabase.currentUser?.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                    )
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                        )
                }
            }
            
            // Name and username
            VStack(spacing: 4) {
                Text(supabase.currentUser?.displayName ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("@\(supabase.currentUser?.username ?? "username")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Bio
            if let bio = supabase.currentUser?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Edit Profile Button
            Button("Edit Profile") {
                showingEditProfile = true
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.orange)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private var statsSection: some View {
        HStack {
            StatView(title: "Meals", value: "\(mealService.userMeals.count)")
            
            Divider()
                .frame(height: 40)
            
            StatView(title: "Following", value: "0") // TODO: Implement following count
            
            Divider()
                .frame(height: 40)
            
            StatView(title: "Followers", value: "0") // TODO: Implement followers count
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
    
    private var contentTabs: some View {
        HStack {
            Button(action: { selectedTab = 0 }) {
                VStack(spacing: 4) {
                    Image(systemName: "grid.3x3")
                        .font(.title3)
                    Text("Grid")
                        .font(.caption)
                }
                .foregroundColor(selectedTab == 0 ? .orange : .gray)
            }
            
            Spacer()
            
            Button(action: { selectedTab = 1 }) {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                    Text("List")
                        .font(.caption)
                }
                .foregroundColor(selectedTab == 1 ? .orange : .gray)
            }
            
            Spacer()
            
            Button(action: { selectedTab = 2 }) {
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                    Text("Saved")
                        .font(.caption)
                }
                .foregroundColor(selectedTab == 2 ? .orange : .gray)
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0:
            mealsGridView
        case 1:
            mealsListView
        case 2:
            savedMealsView
        default:
            EmptyView()
        }
    }
    
    private var mealsGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(mealService.userMeals) { meal in
                NavigationLink(destination: MealDetailView(meal: meal)) {
                    if let photo = meal.primaryPhoto, !photo.url.isEmpty {
                        AsyncImage(url: URL(string: photo.url)) { image in
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                        }
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .foregroundColor(.gray)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 0)
    }
    
    private var mealsListView: some View {
        LazyVStack(spacing: 16) {
            ForEach(mealService.userMeals) { meal in
                MealCardView(meal: meal)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }
    
    private var savedMealsView: some View {
        VStack {
            Image(systemName: "heart")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No saved meals yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Meals you save will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 60)
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

 