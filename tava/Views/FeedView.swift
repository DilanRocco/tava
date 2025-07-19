import SwiftUI

struct FeedView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    
    @State private var currentIndex = 0
    @State private var showingProfile = false
    @State private var showingComments = false
    @State private var selectedMealId: String = ""
    
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
                        ForEach(Array(mealService.feedMeals.enumerated()), id: \.element.id) { index, meal in
                            FeedItemView(
                                meal: meal,
                                geometry: geometry,
                                onProfileTap: {
                                    showingProfile = true
                                },
                                onCommentTap: {
                                    selectedMealId = meal.id
                                    showingComments = true
                                }
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
                .environmentObject(googlePlacesService)
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(mealId: selectedMealId)
        }
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
    
    var body: some View {
        ZStack {
            ZStack {
               
                if let photoUrl = meal.photoUrl, !photoUrl.isEmpty {
                    AsyncImage(url: URL(string: photoUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } placeholder: {
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
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                } else {
                    // Fallback when no image
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
                        .overlay(
                            Image(systemName: "photo.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
                
                // Dark overlay for text readability
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            
            // Content overlay
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
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
                            
                            Spacer()
                        }
                        
                        // Meal info
                        VStack(alignment: .leading, spacing: 8) {
                            if let mealTitle = meal.mealTitle {
                                Text(mealTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            if let description = meal.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(3)
                            }
                            
                            // Tags
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
                                
                                Spacer()
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 100)
                    
                    // Right side - action buttons
                    VStack(spacing: 20) {
                        // Like button
                        VStack(spacing: 4) {
                            Button(action: {
                                isLiked.toggle()
                            }) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(isLiked ? .red : .white)
                                    .scaleEffect(isLiked ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.3), value: isLiked)
                            }
                            
                            Text("\(meal.likesCount + (isLiked ? 1 : 0))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        // Comment button
                        VStack(spacing: 4) {
                            Button(action: onCommentTap) {
                                Image(systemName: "message")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            Text("\(meal.commentsCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        // Bookmark button
                        VStack(spacing: 4) {
                            Button(action: {
                                isBookmarked.toggle()
                            }) {
                                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.title2)
                                    .foregroundColor(isBookmarked ? .orange : .white)
                                    .scaleEffect(isBookmarked ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3), value: isBookmarked)
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
                            }
                            
                            Text("Share")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(activityItems: [meal.shareText])
        }
    }
}

// MARK: - Supporting Views and Models

struct FeedMealItem: Identifiable {
    let id: String // meal_id from database
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

struct CommentsView: View {
    let mealId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Comments for meal")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                
                Text("Comments feature coming soon!")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .navigationTitle("Comments")
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

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 