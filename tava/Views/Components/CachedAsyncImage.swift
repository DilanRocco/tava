import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let storagePath: String
    let bucket: String
    let contentBuilder: (Image) -> Content
    let placeholderBuilder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    private let imageCache = ImageCacheService.shared
    
    init(
        storagePath: String,
        bucket: String = "meal-photos",
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.storagePath = storagePath
        self.bucket = bucket
        self.contentBuilder = content
        self.placeholderBuilder = placeholder
    }
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                contentBuilder(Image(uiImage: loadedImage))
            } else if let error = loadError {
                placeholderBuilder()
                    .onAppear {
                        print("🖼️ CachedAsyncImage - Failed to load: \(storagePath), error: \(error)")
                    }
            } else if isLoading {
                placeholderBuilder()
            } else {
                placeholderBuilder()
            }
        }
        .task {
            await loadImage()
        }
        .onChange(of: storagePath) { _, newPath in
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        guard loadedImage == nil else { return }
        
        isLoading = true
        loadError = nil
        
        do {
            if let image = await imageCache.getImage(for: storagePath, bucket: bucket) {
                await MainActor.run {
                    self.loadedImage = image
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.loadError = NSError(domain: "ImageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == Image {
    init(
        storagePath: String,
        bucket: String = "meal-photos",
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            storagePath: storagePath,
            bucket: bucket,
            content: { $0 },
            placeholder: placeholder
        )
    }
}

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        storagePath: String,
        bucket: String = "meal-photos",
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            storagePath: storagePath,
            bucket: bucket,
            content: content,
            placeholder: { ProgressView() }
        )
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(storagePath: String, bucket: String = "meal-photos") {
        self.init(
            storagePath: storagePath,
            bucket: bucket,
            content: { $0 },
            placeholder: { ProgressView() }
        )
    }
}

// MARK: - Static Cache Management

@MainActor
struct ImageCacheManager {
    /// Preload images for better performance
    static func preloadImages(_ storagePaths: [String], bucket: String = "meal-photos") {
        ImageCacheService.shared.preloadImages(storagePaths: storagePaths, bucket: bucket)
    }
    
    /// Clear all cached images
    static func clearCache() {
        ImageCacheService.shared.clearAllCaches()
    }
    
    /// Get cache information
    static func getCacheInfo() -> CacheInfo {
        ImageCacheService.shared.getCacheInfo()
    }
}