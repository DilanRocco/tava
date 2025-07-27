import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var mealService: MealService
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Profile Content Section
                Section {
                    VStack(spacing: 24) {
                        profileHeader
                        statsSection
                    }
                    .padding(.bottom, 20)
                } header: {
                    EmptyView()
                }
                
                // Sticky Tab Section
                Section {
                    // Content based on selected tab
                    contentView
                        .animation(.easeInOut(duration: 0.15), value: selectedTab)
                } header: {
                    stickyTabHeader
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.primary)
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
            await mealService.fetchUserMeals()
            await mealService.fetchSavedMeals()
            
            let storagePaths = mealService.userMeals.compactMap { $0.primaryPhoto?.storagePath }
            ImageCacheManager.preloadImages(storagePaths)
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Avatar with edit overlay
            ZStack(alignment: .bottomTrailing) {
                Button(action: { showingEditProfile = true }) {
                    Group {
                        if let avatarUrl = supabase.currentUser?.avatarUrl, !avatarUrl.isEmpty {
                            AsyncImage(url: URL(string: avatarUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                        } else {
                            Circle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                }
                
                // Edit indicator
                Circle()
                    .fill(Color.orange)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .offset(x: -5, y: -5)
            }
            
            // User info
            VStack(spacing: 8) {
                Text(supabase.currentUser?.displayName ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("@\(supabase.currentUser?.username ?? "username")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let bio = supabase.currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Edit Profile") {
                    showingEditProfile = true
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Share") {
                    // Share profile action
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Meals", value: "\(mealService.userMeals.count)", icon: "fork.knife", color: .orange)
            StatCard(title: "Following", value: "0", icon: "person.2.fill", color: .blue)
            StatCard(title: "Followers", value: "0", icon: "person.2.fill", color: .purple)
        }
        .padding(.horizontal, 20)
    }
    
    private var stickyTabHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                TabButton(
                    title: tabTitles[index],
                    icon: tabIcons[index],
                    isSelected: selectedTab == index
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var tabTitles: [String] {
        ["Grid", "List", "Saved"]
    }
    
    private var tabIcons: [String] {
        ["square.grid.3x3", "list.bullet", "heart.fill"]
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0:
            gridView
        case 1:
            listView
        case 2:
            savedView
        default:
            EmptyView()
        }
    }
    
    private var gridView: some View {
        LazyVStack(spacing: 0) {
            if mealService.userMeals.isEmpty && !mealService.isLoading {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "No meals yet",
                    subtitle: "Start sharing your culinary adventures!"
                )
                .padding(.top, 80)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3),
                    spacing: 1
                ) {
                    ForEach(mealService.userMeals) { meal in
                        GridMealItem(meal: meal)
                    }
                }
            }
        }
        .refreshable {
            await mealService.fetchUserMeals()
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 0) {
            if mealService.userMeals.isEmpty && !mealService.isLoading {
                EmptyStateView(
                    icon: "list.bullet",
                    title: "No meals yet",
                    subtitle: "Start sharing your culinary adventures!"
                )
                .padding(.top, 80)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(mealService.userMeals) { meal in
                        MealCardView(meal: meal)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 20)
            }
        }
        .refreshable {
            await mealService.fetchUserMeals()
        }
    }
    
    private var savedView: some View {
        LazyVStack(spacing: 0) {
            if mealService.isLoadingSavedMeals {
                LoadingStateView(message: "Loading saved meals...")
                    .padding(.top, 80)
            } else if mealService.savedMeals.isEmpty {
                EmptyStateView(
                    icon: "heart",
                    title: "No saved meals yet",
                    subtitle: "Meals you save will appear here"
                )
                .padding(.top, 80)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(mealService.savedMeals) { meal in
                        MealCardView(meal: meal)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 20)
            }
        }
        .refreshable {
            await mealService.fetchSavedMeals()
        }
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .foregroundColor(isSelected ? .orange : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Rectangle()
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color.clear)
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .orange : .clear)
                    .animation(.easeInOut(duration: 0.2), value: isSelected),
                alignment: .bottom
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



struct GridMealItem: View {
    let meal: MealWithDetails
    
    var body: some View {
        Group {
            if let photo = meal.primaryPhoto, !photo.storagePath.isEmpty {
                CachedAsyncImage(storagePath: photo.storagePath) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
}

struct LoadingStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}




