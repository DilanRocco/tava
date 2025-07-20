import SwiftUI

struct IdentifiableString: Identifiable {
    let id: String
}

struct FeedView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService

    
    @State private var currentIndex = 0
    @State private var showingProfile = false
    @State private var selectedMealId: IdentifiableString? = nil

    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if mealService.isLoading && mealService.feedMeals.isEmpty {
                    // Loading state
                    VStack {
                        ProgressView()
                            .tint(.orange)
                        Text("Loading feed...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                } else if mealService.feedMeals.isEmpty {
                    // Empty state
                    VStack {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        Text("No meals in your feed")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.top)
                        Text("Follow other users to see their meals here!")
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    // Vertical scrolling feed
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(mealService.feedMeals, id: \.id) { meal in
                                FeedItemView(
                                    meal: meal,
                                    geometry: geometry,
                                    onProfileTap: {
                                        showingProfile = true
                                    },
                                    onCommentTap: { handleComment(for: meal)}
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .refreshable {
                        await mealService.fetchFeedData()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .task {
            await mealService.fetchFeedData()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
                .environmentObject(supabase)
                .environmentObject(locationService)
                .environmentObject(mealService)
                
        }
        .sheet(item: $selectedMealId) { wrapped in
            CommentsView(mealId: wrapped.id)
        }

    }
    private func handleComment(for meal: FeedMealItem) {
        selectedMealId = IdentifiableString(id: meal.id)
    }
}

struct FeedItemView: View {
    let meal: FeedMealItem
    let geometry: GeometryProxy
    let onProfileTap: () -> Void
    let onCommentTap: () -> Void
    
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var showingShare = false
    @State private var showHeart = false
    
    var body: some View {
        ZStack {
            // Background layer with consistent frame
            ZStack {
                if let photoUrl = meal.photoUrl, !photoUrl.isEmpty {
                    AsyncImage(url: URL(string: photoUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } placeholder: {
                        // Placeholder with exact same dimensions as loaded image
                        RoundedRectangle(cornerRadius: 0)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.orange.opacity(0.3),
                                        Color.black.opacity(0.7)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                } else {
                    // Fallback when no image - same dimensions
                    RoundedRectangle(cornerRadius: 0)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.3),
                                    Color.black.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(
                            Image(systemName: "photo.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
                
                // Dark overlay for text readability - at top
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.7),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            
            // Double-tap heart animation
            if showHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .scaleEffect(showHeart ? 1.5 : 0.5)
                    .opacity(showHeart ? 0.8 : 0)
                    .animation(.easeOut(duration: 0.8), value: showHeart)
            }
            
            // Content overlay with fixed positioning
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    // Left side - meal info
                    VStack(alignment: .leading, spacing: 12) {
                        // User info
                        HStack {
                            Button(action: onProfileTap) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text((meal.displayName ?? meal.username).prefix(1))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.displayName ?? meal.username)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(meal.location)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer(minLength: 0)
                        }
                        
                        // Meal info
                        VStack(alignment: .leading, spacing: 8) {
                            if let mealTitle = meal.mealTitle {
                                Text(mealTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if let description = meal.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // Tags
                            if !meal.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(meal.tags, id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.black.opacity(0.3))
                                                .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal, 0)
                                }
                                .frame(height: 28) // Fixed height for tags scroll view
                            }
                            
                            // Rating and time
                            HStack {
                                if let rating = meal.rating {
                                    HStack(spacing: 2) {
                                        ForEach(0..<5) { index in
                                            Image(systemName: index < rating ? "star.fill" : "star")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                
                                Text("•")
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(meal.timeAgo)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right side - action buttons
                    VStack(spacing: 20) {
                        // Like button
                        VStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    isLiked.toggle()
                                }
                            }) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(isLiked ? .red : .white)
                                    .scaleEffect(isLiked ? 1.2 : 1.0)
                                    .frame(width: 24, height: 24) // Fixed frame
                            }
                            
                            Text("\(meal.likesCount + (isLiked ? 1 : 0))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(minWidth: 20)
                        }
                        
                        // Comment button
                        VStack(spacing: 4) {
                            Button(action: onCommentTap) {
                                Image(systemName: "message")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24) // Fixed frame
                            }
                            
                            Text("\(meal.commentsCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(minWidth: 20)
                        }
                        
                        // Bookmark button
                        VStack(spacing: 4) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    isBookmarked.toggle()
                                }
                            }) {
                                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.title2)
                                    .foregroundColor(isBookmarked ? .orange : .white)
                                    .scaleEffect(isBookmarked ? 1.1 : 1.0)
                                    .frame(width: 24, height: 24) // Fixed frame
                            }
                            
                            Text("Save")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        // Share button
                        VStack(spacing: 4) {
                            Button(action: {
                                showingShare = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24) // Fixed frame
                            }
                            
                            Text("Share")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }

                    .frame(width: 80) // Fixed width for button column
                }
                .padding(.top, 20) // Add top padding instead of bottom
                .padding(.horizontal, 0)
                
                Spacer() // Push content to top
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height) // Constrain entire view
        .clipped()
        .onTapGesture(count: 2, perform: {
            handleDoubleTap()
        })
        .sheet(isPresented: $showingShare) {
            ShareSheet(activityItems: [meal.shareText])
        }
    }

    private func handleDoubleTap() {
        // Like the post
        if !isLiked {
            isLiked = true
        }
        
        // Show heart animation
        showHeart = true
        
        // Hide heart after 0.8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showHeart = false
        }
    }
}

// MARK: - Supporting Views and Models

struct FeedMealItem: Identifiable {
    let id: String
    let userId: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let mealTitle: String?
    let description: String?
    let mealType: String // 'restaurant' or 'homemade'
    let location: String
    let tags: [String]
    let rating: Int?
    let eatenAt: Date
    let likesCount: Int
    let commentsCount: Int
    let bookmarksCount: Int
    let photoUrl: String?
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: eatenAt, relativeTo: Date())
    }
    
    var shareText: String {
        let title = mealTitle ?? "meal"
        return "\(title) at \(location) - Check out this amazing meal on Tava!"
    }
}






struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
