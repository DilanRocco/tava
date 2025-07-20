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





struct CommentsView: View {
    let mealId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var mealService: MealService
    
    @State private var newCommentText = ""
    @State private var replyingToCommentId: String? = nil
    @State private var replyText = ""
    @State private var expandedComments: Set<String> = []
    @State private var isAddingComment = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments content
                commentsContentView
                
                Divider()
                
                // Comment input
                CommentInputView(
                    newCommentText: $newCommentText,
                    replyText: $replyText,
                    isAddingComment: $isAddingComment,
                    replyingToCommentId: replyingToCommentId,
                    parentComment: replyingToCommentId != nil ? 
                        mealService.comments.first(where: { $0.id.uuidString == replyingToCommentId! }) : nil,
                    onAddComment: {
                        Task { await addComment() }
                    },
                    onCancelReply: {
                        cancelReply()
                    }
                )
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
        .task {
            print(mealId)
            print("LMAO")
            await mealService.fetchComments(for: mealId)
        }
    }
    
    @ViewBuilder
    private var commentsContentView: some View {
        if mealService.isLoadingComments && mealService.comments.isEmpty {
            CommentsLoadingView()
        } else if mealService.comments.isEmpty {
            CommentsEmptyView()
        } else {
            CommentsListView(
                comments: mealService.comments,
                expandedComments: expandedComments,
                onToggleExpand: { commentId in
                    toggleExpanded(commentId: commentId)
                },
                onReply: { commentId in
                    startReply(to: commentId)
                },
                onLike: { commentId, isLiked in
                    Task {
                        await toggleCommentLike(commentId: commentId, isLiked: isLiked)
                    }
                },
                onLoadMoreReplies: { commentId in
                    Task {
                        await mealService.loadMoreReplies(for: getCommentIndex(commentId), mealId: mealId)
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleExpanded(commentId: String) {
        if expandedComments.contains(commentId) {
            expandedComments.remove(commentId)
        } else {
            expandedComments.insert(commentId)
            // Load replies if not already loaded
            if let comment = mealService.comments.first(where: { $0.id.uuidString == commentId }),
               comment.replies.isEmpty && comment.repliesCount > 0 {
                Task {
                    await mealService.loadMoreReplies(for: getCommentIndex(commentId), mealId: mealId)
                }
            }
        }
    }
    
    private func startReply(to commentId: String) {
        replyingToCommentId = commentId
        replyText = ""
    }
    
    private func cancelReply() {
        replyingToCommentId = nil
        replyText = ""
    }
    
    private func addComment() async {
        isAddingComment = true
        defer { isAddingComment = false }
        
        do {
            if let replyingToId = replyingToCommentId {
                // Adding a reply
                _ = try await mealService.addComment(
                    to: mealId,
                    content: replyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    parentCommentId: replyingToId
                )
                replyText = ""
                replyingToCommentId = nil
                
                // Make sure the parent comment is expanded to show the new reply
                expandedComments.insert(replyingToId)
            } else {
                // Adding a parent comment
                _ = try await mealService.addComment(
                    to: mealId,
                    content: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                newCommentText = ""
            }
        } catch {
            // Handle error - could show an alert
            print("Failed to add comment: \(error)")
        }
    }
    
    private func toggleCommentLike(commentId: String, isLiked: Bool) async {
        do {
            if isLiked {
                try await mealService.unlikeComment(commentId: commentId)
            } else {
                try await mealService.likeComment(commentId: commentId)
            }
        } catch {
            print("Failed to toggle comment like: \(error)")
        }
    }
    
    private func getCommentIndex(_ commentId: String) -> Int {
        return mealService.comments.firstIndex(where: { $0.id.uuidString == commentId }) ?? 0
    }
}

// MARK: - Supporting Views

struct CommentsLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .tint(.orange)
            Text("Loading comments...")
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CommentsEmptyView: View {
    var body: some View {
        VStack {
            Image(systemName: "message")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            Text("No comments yet")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.top, 8)
            Text("Be the first to comment!")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CommentsListView: View {
    let comments: [Comment]
    let expandedComments: Set<String>
    let onToggleExpand: (String) -> Void
    let onReply: (String) -> Void
    let onLike: (String, Bool) -> Void
    let onLoadMoreReplies: (String) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(comments) { comment in
                    CommentRowView(
                        comment: comment,
                        isExpanded: expandedComments.contains(comment.id.uuidString),
                        onToggleExpand: {
                            onToggleExpand(comment.id.uuidString)
                        },
                        onReply: {
                            onReply(comment.id.uuidString)
                        },
                        onLike: {
                            onLike(comment.id.uuidString, comment.userHasLiked)
                        },
                        onLoadMoreReplies: {
                            onLoadMoreReplies(comment.id.uuidString)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CommentInputView: View {
    @Binding var newCommentText: String
    @Binding var replyText: String
    @Binding var isAddingComment: Bool
    
    let replyingToCommentId: String?
    let parentComment: Comment?
    let onAddComment: () -> Void
    let onCancelReply: () -> Void
    
    private var currentText: Binding<String> {
        replyingToCommentId != nil ? $replyText : $newCommentText
    }
    
    private var placeholder: String {
        replyingToCommentId != nil ? "Write a reply..." : "Add a comment..."
    }
    
    private var isEmpty: Bool {
        currentText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reply indicator
            if let parentComment = parentComment {
                ReplyIndicatorView(
                    parentComment: parentComment,
                    onCancel: onCancelReply
                )
            }
            
            // Input field and send button
            HStack(alignment: .bottom, spacing: 12) {
                TextField(placeholder, text: currentText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button(action: onAddComment) {
                    if isAddingComment {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.orange)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.orange)
                    }
                }
                .frame(width: 32, height: 32)
                .disabled(isAddingComment || isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGray6))
    }
}

struct ReplyIndicatorView: View {
    let parentComment: Comment
    let onCancel: () -> Void
    
    var body: some View {
        HStack {
            Text("Replying to")
                .font(.caption)
                .foregroundColor(.gray)
            Text("@\(parentComment.displayName ?? parentComment.username)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            Spacer()
            Button("Cancel") {
                onCancel()
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
struct CommentRowView: View {
    let comment: Comment
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onReply: () -> Void
    let onLike: () -> Void
    let onLoadMoreReplies: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent comment
            CommentItemView(
                comment: comment,
                isReply: false,
                onReply: onReply,
                onLike: onLike
            )
            
            // Replies section
            if comment.repliesCount > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    // Toggle replies button
                    Button(action: onToggleExpand) {
                        HStack(spacing: 8) {
                            Rectangle()
                                .frame(width: 24, height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(isExpanded ? "Hide replies" : "\(comment.repliesCount) \(comment.repliesCount == 1 ? "reply" : "replies")")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                        }
                    }
                    .padding(.leading, 56)
                    .padding(.vertical, 8)
                    
                    // Replies list (when expanded)
                    if isExpanded {
                        ForEach(comment.replies) { reply in
                            CommentItemView(
                                comment: reply,
                                isReply: true,
                                onReply: {},
                                onLike: onLike
                            )
                        }
                        
                        // Load more replies button
                        if comment.replies.count < comment.repliesCount {
                            Button(action: onLoadMoreReplies) {
                                HStack {
                                    Text("Load more replies")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                            }
                            .padding(.leading, 56)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.top, 12)
        }
    }
}
struct CommentItemView: View {
    let comment: Comment
    let isReply: Bool
    let onReply: () -> Void
    let onLike: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Indent for replies
            if isReply {
                Rectangle()
                    .frame(width: 2, height: 20)
                    .foregroundColor(.gray.opacity(0.3))
                    .padding(.leading, 24)
            }
            
            // Avatar
            Circle()
                .fill(Color.orange)
                .frame(width: isReply ? 28 : 32, height: isReply ? 28 : 32)
                .overlay(
                    Text((comment.displayName ?? comment.username).prefix(1))
                        .font(isReply ? .caption : .footnote)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // User info and timestamp
                HStack {
                    Text(comment.displayName ?? comment.username)
                        .font(isReply ? .caption : .subheadline)
                        .fontWeight(.medium)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                
                // Comment content
                Text(comment.content)
                    .font(isReply ? .caption : .body)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Actions
                HStack(spacing: 16) {
                    // Like button
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: comment.userHasLiked ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(comment.userHasLiked ? .red : .gray)
                            
                            if comment.likesCount > 0 {
                                Text("\(comment.likesCount)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Reply button (only for parent comments)
                    if !isReply {
                        Button(action: onReply) {
                            Text("Reply")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
