//
//  CommentView.swift
//  tava
//
//  Created by dilan on 7/20/25.
//
import SwiftUI
import Foundation

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
                        onLike: { commentId, isLiked in
                            // CHANGED: Pass the specific comment ID and like status
                            onLike(commentId, isLiked)
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
    let onLike: (String, Bool) -> Void  // CHANGED: Now accepts commentId and isLiked parameters
    let onLoadMoreReplies: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent comment
            CommentItemView(
                comment: comment,
                isReply: false,
                onReply: onReply,
                onLike: {
                    // CHANGED: Pass parent comment's ID and like status
                    onLike(comment.id.uuidString, comment.userHasLiked)
                }
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
                                onLike: {
                                    // CHANGED: Pass the REPLY's ID and like status, not the parent's
                                    onLike(reply.id.uuidString, reply.userHasLiked)
                                }
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
