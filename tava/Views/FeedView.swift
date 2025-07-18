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
    
    // Sample meal data - in real app this would come from your service
    @State private var meals: [FeedMealItem] = FeedMealItem.sampleData
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Vertical scrolling feed
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
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
                
                // Top overlay with profile button
                VStack {
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
                        
                        Text("Feed")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            // Refresh feed
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
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
            // Background image/video
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
                    // Placeholder for meal image
                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.3))
                )
            
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
                                        Text(meal.userName.prefix(1))
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.userName)
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
                            Text(meal.mealName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if !meal.description.isEmpty {
                                Text(meal.description)
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
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < meal.rating ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundColor(.orange)
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
    let id = UUID().uuidString
    let userName: String
    let location: String
    let mealName: String
    let description: String
    let tags: [String]
    let rating: Int
    let timeAgo: String
    let likesCount: Int
    let commentsCount: Int
    let imageUrl: String?
    
    var shareText: String {
        "\(mealName) at \(location) - Check out this amazing meal on Tava!"
    }
    
    static let sampleData: [FeedMealItem] = [
        FeedMealItem(
            userName: "Sarah Chen",
            location: "Chez Laurent, Paris",
            mealName: "Duck Confit with Cherry Sauce",
            description: "Absolutely incredible French cuisine! The duck was perfectly crispy and the cherry sauce was divine. Worth every penny!",
            tags: ["french", "finedining", "duck", "romantic"],
            rating: 5,
            timeAgo: "2h ago",
            likesCount: 127,
            commentsCount: 23,
            imageUrl: nil
        ),
        FeedMealItem(
            userName: "Mike Rodriguez",
            location: "Joe's Pizza, NYC",
            mealName: "Classic Margherita Pizza",
            description: "Nothing beats a good old NYC pizza slice. This place has been my go-to for years!",
            tags: ["pizza", "nyc", "comfort", "classic"],
            rating: 4,
            timeAgo: "4h ago",
            likesCount: 89,
            commentsCount: 12,
            imageUrl: nil
        ),
        FeedMealItem(
            userName: "Aisha Patel",
            location: "Spice Garden, Mumbai",
            mealName: "Butter Chicken & Naan",
            description: "Homestyle butter chicken that reminded me of my grandmother's cooking. The naan was fresh and warm!",
            tags: ["indian", "homestyle", "comfort", "spicy"],
            rating: 5,
            timeAgo: "6h ago",
            likesCount: 156,
            commentsCount: 31,
            imageUrl: nil
        ),
        FeedMealItem(
            userName: "James Wilson",
            location: "Home Kitchen",
            mealName: "Homemade Ramen Bowl",
            description: "Spent 8 hours making this ramen from scratch. The broth was so rich and flavorful!",
            tags: ["homemade", "ramen", "japanese", "comfort"],
            rating: 4,
            timeAgo: "1d ago",
            likesCount: 203,
            commentsCount: 45,
            imageUrl: nil
        ),
        FeedMealItem(
            userName: "Emma Thompson",
            location: "Green Leaf Cafe",
            mealName: "Acai Bowl with Fresh Fruits",
            description: "Perfect post-workout meal! Love how fresh and colorful this bowl is. Great for a healthy start to the day.",
            tags: ["healthy", "acai", "breakfast", "fresh"],
            rating: 4,
            timeAgo: "1d ago",
            likesCount: 94,
            commentsCount: 18,
            imageUrl: nil
        )
    ]
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