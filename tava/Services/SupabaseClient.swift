import Foundation
import UIKit
import Supabase

class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()
    
    let client: Supabase.SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private init() {
        // Temporary: hardcoded credentials for debugging
        let supabaseURL = URL(string: "https://olqprtnexykoipqnigag.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9scXBydG5leHlrb2lwcW5pZ2FnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3NzkzNDQsImV4cCI6MjA2ODM1NTM0NH0.7gBPCNKpVhr6wYviC5IyqSp14xyrRVz2nqD0VK_2nhI"
        
        print("🔑 Using Supabase URL: \(supabaseURL)")
        print("🔑 Using API Key: \(String(supabaseKey.prefix(20)))...")
        
        self.client = Supabase.SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        Task {
            await checkAuthState()
        }
    }
    
    // MARK: - Authentication
    
    @MainActor
    func checkAuthState() async {
        do {

            
            let session = try await client.auth.session
            print("🔑 Session: \(session)")
            let user = session.user
            // Fetch user profile from our users table
            await fetchUserProfile(userId: user.id)
        } catch {
            print("Auth check failed: \(error)")
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    @MainActor
    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        await fetchUserProfile(userId: response.user.id)
    }
    
    @MainActor
    func signUp(email: String, password: String, username: String, displayName: String?) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        
        // Create user profile in our users table
        let newUser = User(
            id: response.user.id,
            username: username,
            displayName: displayName,
            bio: nil,
            avatarUrl: nil,
            phone: nil,
            email: email,
            locationEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await client
            .from("users")
            .insert([newUser])
            .execute()
        
        self.currentUser = newUser
        self.isAuthenticated = true
    }
    
    @MainActor
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // MARK: - User Profile
    
    @MainActor
    private func fetchUserProfile(userId: UUID) async {
        do {
            let response: User = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.currentUser = response
            self.isAuthenticated = true
        } catch {
            print("Failed to fetch user profile: \(error)")
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Storage
    
    func uploadPhoto(image: UIImage, path: String) async throws -> String {
        guard let imageData = compressImageToWebP(image: image) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        do {
            try await client.storage
                .from("meal-photos")
                .upload(path: path, file: imageData)
            
            let publicURL = try client.storage
                .from("meal-photos")
                .getPublicURL(path: path)
            
            return publicURL.absoluteString
        } catch {
            print("Storage upload error: \(error)")
            // Check if it's an RLS policy error
            if let storageError = error as? StorageError,
               storageError.message.contains("row-level security policy") {
                throw NSError(domain: "StorageError", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Photo upload not authorized - storage permissions need configuration",
                    NSLocalizedFailureReasonErrorKey: "Storage bucket RLS policies not set up properly"
                ])
            } else {
                throw NSError(domain: "StorageError", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to upload photo",
                    NSLocalizedFailureReasonErrorKey: error.localizedDescription
                ])
            }
        }
    }
    
    func deletePhoto(path: String) async throws {
        try await client.storage
            .from("meal-photos")
            .remove(paths: [path])
    }
    
    func getSignedURL(for storagePath: String, bucket: String = "meal-photos", expiresIn: Int = 3600) async throws -> URL {
        return try await client.storage
            .from(bucket)
            .createSignedURL(path: storagePath, expiresIn: expiresIn)
    }
    
    func getSignedURLString(for storagePath: String, bucket: String = "meal-photos", expiresIn: Int = 3600) async throws -> String {
        let url = try await getSignedURL(for: storagePath, bucket: bucket, expiresIn: expiresIn)
        return url.absoluteString
    }
    
    // MARK: - Image Compression
    
    func compressImage(image: UIImage, quality: Float = 0.7, maxDimension: CGFloat = 1920) -> Data? {
        return compressImageToWebP(image: image, quality: quality, maxDimension: maxDimension)
    }
    
    private func compressImageToWebP(image: UIImage, quality: Float = 0.7, maxDimension: CGFloat = 1920) -> Data? {
        // Resize image if needed
        let resizedImage = resizeImage(image: image, maxDimension: maxDimension)
        
        // Convert to WebP
        guard let cgImage = resizedImage.cgImage else { return nil }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.webp" as CFString, 1, nil) else {
            // Fallback to JPEG if WebP fails
            return resizedImage.jpegData(compressionQuality: CGFloat(quality))
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        } else {
            // Fallback to JPEG if WebP conversion fails
            return resizedImage.jpegData(compressionQuality: CGFloat(quality))
        }
    }
    
    private func resizeImage(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Check if resizing is needed
        if max(size.width, size.height) <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Resize the image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
} 
