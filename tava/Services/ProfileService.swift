import Foundation
import UIKit
import PhotosUI
import Helpers

@MainActor
class ProfileService: ObservableObject {
    private let supabase = SupabaseClient.shared
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Profile Updates
    
    func updateProfile(displayName: String?, bio: String?, username: String?) async throws {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Handle updates one by one to avoid encoding issues
            var hasUpdates = false
            
            if let displayName = displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                try await supabase.client
                    .from("users")
                    .update(["display_name": trimmedDisplayName, "updated_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: currentUserId.uuidString)
                    .execute()
                hasUpdates = true
            }
            
            if let bio = bio {
                let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
                let bioValue = trimmedBio.isEmpty ? "" : trimmedBio
                try await supabase.client
                    .from("users")
                    .update(["bio": bioValue, "updated_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: currentUserId.uuidString)
                    .execute()
                hasUpdates = true
            }
            
            if let username = username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                // Validate username format
                if !isValidUsername(cleanUsername) {
                    throw NSError(domain: "ValidationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Username must be 3-30 characters and contain only letters, numbers, and underscores"])
                }
                
                // Check if username is already taken
                let existingUsers: [ProfileUserData] = try await supabase.client
                    .from("users")
                    .select("id")
                    .eq("username", value: cleanUsername)
                    .neq("id", value: currentUserId.uuidString)
                    .execute()
                    .value
                
                if !existingUsers.isEmpty {
                    throw NSError(domain: "ValidationError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
                }
                
                try await supabase.client
                    .from("users")
                    .update(["username": cleanUsername, "updated_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: currentUserId.uuidString)
                    .execute()
                hasUpdates = true
            }
            
            if hasUpdates {
                print("✅ Profile updated successfully")
            }
            
        } catch {
            self.error = error
            print("❌ Failed to update profile: \(error)")
            throw error
        }
    }
    
    func uploadAvatar(imageData: Data) async throws -> String {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Generate unique filename
            let filename = "avatar_\(currentUserId.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
            let path = "avatars/\(filename)"
            
            // Upload to Supabase Storage
            try await supabase.client.storage
                .from("user-content")
                .upload(path, data: imageData, options: .init(
                    contentType: "image/jpeg",
                    upsert: true
                ))
            
            // Get public URL
            let publicURL = try supabase.client.storage
                .from("user-content")
                .getPublicURL(path: path)
            
            // Update user profile with new avatar URL
            try await supabase.client
                .from("users")
                .update(["avatar_url": publicURL.absoluteString, "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: currentUserId.uuidString)
                .execute()
            
            print("✅ Avatar uploaded successfully: \(publicURL.absoluteString)")
            return publicURL.absoluteString
            
        } catch {
            self.error = error
            print("❌ Failed to upload avatar: \(error)")
            throw error
        }
    }
    
    func removeAvatar() async throws {
        guard let currentUserId = supabase.currentUser?.id else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update user profile to remove avatar URL
            try await supabase.client
                .from("users")
                .update(["avatar_url": "", "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: currentUserId.uuidString)
                .execute()
            
            print("✅ Avatar removed successfully")
            
        } catch {
            self.error = error
            print("❌ Failed to remove avatar: \(error)")
            throw error
        }
    }
    
    // MARK: - Validation Helpers
    
    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-z0-9_]{3,30}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return predicate.evaluate(with: username)
    }
}

// MARK: - Supporting Models

struct ProfileUserData: Codable {
    let id: String
    let username: String?
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarUrl = "avatar_url"
    }
}