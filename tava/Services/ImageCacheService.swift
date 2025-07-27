import Foundation
import UIKit
import Combine

@MainActor
class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    
    // MARK: - Cache Configuration
    private struct CacheConfig {
        static let memoryCapacity = 50 * 1024 * 1024 // 50MB memory cache
        static let diskCapacity = 200 * 1024 * 1024 // 200MB disk cache
        static let signedURLCacheLimit = 1000 // Max 1000 signed URLs
        static let signedURLExpiration: TimeInterval = 3000 // 50 minutes (signed URLs expire in 1 hour)
        static let diskCacheExpiration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    }
    
    // MARK: - Caches
    private let memoryCache = NSCache<NSString, UIImage>()
    private let urlCache: URLCache
    private var signedURLCache: [String: SignedURLCacheEntry] = [:]
    private let supabase = SupabaseClient.shared
    
    // MARK: - Cache Entry Models
    private struct SignedURLCacheEntry {
        let url: String
        let createdAt: Date
        let expiresAt: Date
        
        var isValid: Bool {
            Date() < expiresAt
        }
    }
    
    private init() {
        // Configure memory cache
        memoryCache.totalCostLimit = CacheConfig.memoryCapacity
        
        // Configure URL cache for disk storage
        urlCache = URLCache(
            memoryCapacity: CacheConfig.memoryCapacity / 4, // 12.5MB for URL cache memory
            diskCapacity: CacheConfig.diskCapacity,
            diskPath: "tava_image_cache"
        )
        
        // Set as default URL cache
        URLCache.shared = urlCache
        
        // Clean up expired entries periodically
        startPeriodicCleanup()
    }
    
    // MARK: - Public API
    
    /// Get image from cache or load it
    func getImage(for storagePath: String, bucket: String = "meal-photos") async -> UIImage? {
        // 1. Check memory cache first
        if let cachedImage = memoryCache.object(forKey: storagePath as NSString) {
            print("🖼️ ImageCache - Memory hit for: \(storagePath)")
            return cachedImage
        }
        
        // 2. Get signed URL (cached or generate new)
        guard let signedURL = await getSignedURL(for: storagePath, bucket: bucket) else {
            print("🖼️ ImageCache - Failed to get signed URL for: \(storagePath)")
            return nil
        }
        
        // 3. Check disk cache via URLCache
        guard let url = URL(string: signedURL) else { return nil }
        let request = URLRequest(url: url)
        
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            print("🖼️ ImageCache - Disk hit for: \(storagePath)")
            // Store in memory cache for faster access
            memoryCache.setObject(image, forKey: storagePath as NSString)
            return image
        }
        
        // 4. Download image
        return await downloadAndCacheImage(from: signedURL, storagePath: storagePath)
    }
    
    /// Preload images for better UX
    func preloadImages(storagePaths: [String], bucket: String = "meal-photos") {
        Task {
            for storagePath in storagePaths {
                _ = await getImage(for: storagePath, bucket: bucket)
            }
        }
    }
    
    /// Clear all caches
    func clearAllCaches() {
        memoryCache.removeAllObjects()
        urlCache.removeAllCachedResponses()
        signedURLCache.removeAll()
        print("🖼️ ImageCache - Cleared all caches")
    }
    
    /// Clear expired items only
    func clearExpiredItems() {
        cleanupExpiredSignedURLs()
        cleanupExpiredDiskCache()
        print("🖼️ ImageCache - Cleared expired items")
    }
    
    /// Get cache size info for debugging
    func getCacheInfo() -> CacheInfo {
        let memoryCount = memoryCache.description.components(separatedBy: " ").count // Rough estimate
        let diskSize = urlCache.currentDiskUsage
        let signedURLCount = signedURLCache.count
        
        return CacheInfo(
            memoryImageCount: memoryCount,
            diskCacheSize: diskSize,
            signedURLCount: signedURLCount
        )
    }
    
    // MARK: - Private Methods
    
    private func getSignedURL(for storagePath: String, bucket: String) async -> String? {
        // Check cache first
        if let cached = signedURLCache[storagePath], cached.isValid {
            print("🖼️ ImageCache - Signed URL cache hit for: \(storagePath)")
            return cached.url
        }
        
        // Generate new signed URL
        do {
            let signedURL = try await supabase.getSignedURLString(for: storagePath, bucket: bucket)
            
            // Cache it
            let expiresAt = Date().addingTimeInterval(CacheConfig.signedURLExpiration)
            signedURLCache[storagePath] = SignedURLCacheEntry(
                url: signedURL,
                createdAt: Date(),
                expiresAt: expiresAt
            )
            
            // Limit cache size
            if signedURLCache.count > CacheConfig.signedURLCacheLimit {
                cleanupOldSignedURLs()
            }
            
            print("🖼️ ImageCache - Generated new signed URL for: \(storagePath)")
            return signedURL
        } catch {
            print("🖼️ ImageCache - Failed to generate signed URL for: \(storagePath), error: \(error)")
            return nil
        }
    }
    
    private func downloadAndCacheImage(from urlString: String, storagePath: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let image = UIImage(data: data) else {
                print("🖼️ ImageCache - Invalid image data for: \(storagePath)")
                return nil
            }
            
            // Cache in memory
            memoryCache.setObject(image, forKey: storagePath as NSString)
            
            // Cache in disk via URLCache
            let request = URLRequest(url: url)
            let cachedResponse = CachedURLResponse(response: response, data: data)
            urlCache.storeCachedResponse(cachedResponse, for: request)
            
            print("🖼️ ImageCache - Downloaded and cached: \(storagePath)")
            return image
        } catch {
            print("🖼️ ImageCache - Download failed for: \(storagePath), error: \(error)")
            return nil
        }
    }
    
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in // Every 5 minutes
            Task { @MainActor in
                self.cleanupExpiredSignedURLs()
            }
        }
        
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in // Every hour
            Task { @MainActor in
                self.cleanupExpiredDiskCache()
            }
        }
    }
    
    private func cleanupExpiredSignedURLs() {
        let before = signedURLCache.count
        signedURLCache = signedURLCache.filter { $0.value.isValid }
        let after = signedURLCache.count
        
        if before != after {
            print("🖼️ ImageCache - Cleaned up \(before - after) expired signed URLs")
        }
    }
    
    private func cleanupOldSignedURLs() {
        // Remove oldest entries when cache is full
        let sortedEntries = signedURLCache.sorted { $0.value.createdAt < $1.value.createdAt }
        let toRemove = sortedEntries.prefix(signedURLCache.count - CacheConfig.signedURLCacheLimit + 100)
        
        for (key, _) in toRemove {
            signedURLCache.removeValue(forKey: key)
        }
        
        print("🖼️ ImageCache - Removed \(toRemove.count) old signed URLs")
    }
    
    private func cleanupExpiredDiskCache() {
        // URLCache doesn't provide easy way to clean by date, but it has its own cleanup mechanisms
        // We could implement custom disk cache if needed, but URLCache is efficient for our needs
        print("🖼️ ImageCache - Disk cache cleanup (managed by URLCache)")
    }
}

// MARK: - Supporting Types

struct CacheInfo {
    let memoryImageCount: Int
    let diskCacheSize: Int
    let signedURLCount: Int
    
    var description: String {
        """
        Cache Info:
        - Memory Images: \(memoryImageCount)
        - Disk Cache: \(ByteCountFormatter.string(fromByteCount: Int64(diskCacheSize), countStyle: .file))
        - Signed URLs: \(signedURLCount)
        """
    }
}