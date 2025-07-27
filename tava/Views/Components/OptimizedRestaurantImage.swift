import SwiftUI

/// Optimized image component specifically for restaurant images
/// Handles both Supabase storage paths and external URLs (like Google Places photos)
struct OptimizedRestaurantImage<Content: View, Placeholder: View>: View {
    let imageUrl: String?
    let storagePath: String?
    let bucket: String
    let contentBuilder: (Image) -> Content
    let placeholderBuilder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    private let imageCache = ImageCacheService.shared
    
    init(
        imageUrl: String? = nil,
        storagePath: String? = nil,
        bucket: String = "restaurant-photos",
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.imageUrl = imageUrl
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
                        print("🖼️ RestaurantImage - Failed to load, error: \(error)")
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
    }
    
    private func loadImage() async {
        guard loadedImage == nil else { return }
        
        isLoading = true
        loadError = nil
        
        // Priority 1: Use storage path (Supabase stored images)
        if let storagePath = storagePath, !storagePath.isEmpty {
            if let image = await imageCache.getImage(for: storagePath, bucket: bucket) {
                await MainActor.run {
                    self.loadedImage = image
                    self.isLoading = false
                }
                return
            }
        }
        
        // Priority 2: Use direct URL (external images like Google Places)
        if let imageUrl = imageUrl, !imageUrl.isEmpty {
            await loadFromDirectURL(imageUrl)
            return
        }
        
        // No valid image source
        await MainActor.run {
            self.loadError = NSError(domain: "ImageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No valid image source"])
            self.isLoading = false
        }
    }
    
    private func loadFromDirectURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                self.loadError = NSError(domain: "ImageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                await MainActor.run {
                    self.loadError = NSError(domain: "ImageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    self.isLoading = false
                }
                return
            }
            
            await MainActor.run {
                self.loadedImage = image
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
        }
    }
}

// MARK: - Convenience Initializers

extension OptimizedRestaurantImage where Content == Image {
    init(
        imageUrl: String? = nil,
        storagePath: String? = nil,
        bucket: String = "restaurant-photos",
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            imageUrl: imageUrl,
            storagePath: storagePath,
            bucket: bucket,
            content: { $0 },
            placeholder: placeholder
        )
    }
}

extension OptimizedRestaurantImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        imageUrl: String? = nil,
        storagePath: String? = nil,
        bucket: String = "restaurant-photos",
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            imageUrl: imageUrl,
            storagePath: storagePath,
            bucket: bucket,
            content: content,
            placeholder: { ProgressView() }
        )
    }
}

extension OptimizedRestaurantImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        imageUrl: String? = nil,
        storagePath: String? = nil,
        bucket: String = "restaurant-photos"
    ) {
        self.init(
            imageUrl: imageUrl,
            storagePath: storagePath,
            bucket: bucket,
            content: { $0 },
            placeholder: { ProgressView() }
        )
    }
}