//
//  Comment.swift
//  tava
//
//  Created by dilan on 7/19/25.
//
import Foundation

struct Comment: Identifiable, Codable {
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case mealId = "meal_id"
        case parentCommentId = "parent_comment_id"
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case likesCount = "likes_count"
        case repliesCount = "replies_count"
        case userHasLiked = "user_has_liked"
        case replies
    }
    
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
            repliesCount: repliesCount+1,
            userHasLiked: userHasLiked,
            replies: newReplies
        )
    }
}
