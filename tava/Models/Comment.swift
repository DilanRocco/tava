//
//  Comment.swift
//  tava
//
//  Created by dilan on 7/19/25.
//
import Foundation
struct Comment: Identifiable {
    let id: UUID
    let mealId: UUID
    let parentCommentId: UUID?
    let userId: UUID
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let likesCount: Int
    let repliesCount: Int
    let userHasLiked: Bool
    var replies: [Comment]
    
    var isParentComment: Bool {
        return parentCommentId == nil
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    func withLikeStatus(isLiked: Bool, likesCount: Int) -> Comment {
        return Comment(
            id: id,
            mealId: mealId,
            parentCommentId: parentCommentId,
            userId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likesCount: likesCount,
            repliesCount: repliesCount,
            userHasLiked: isLiked,
            replies: replies
        )
    }
    
    func withReplies(_ newReplies: [Comment]) -> Comment {
        return Comment(
            id: id,
            mealId: mealId,
            parentCommentId: parentCommentId,
            userId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: avatarUrl,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likesCount: likesCount,
            repliesCount: repliesCount,
            userHasLiked: userHasLiked,
            replies: newReplies
        )
    }
}
