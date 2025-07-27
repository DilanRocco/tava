import SwiftUI

struct SignedAsyncImage<Content: View, Placeholder: View>: View {
    let storagePath: String
    let bucket: String
    let contentBuilder: (Image) -> Content
    let placeholderBuilder: () -> Placeholder
    
    @State private var signedURL: String?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    private let supabase = SupabaseClient.shared
    
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
            if let signedURL = signedURL {
                AsyncImage(url: URL(string: signedURL)) { phase in
                    switch phase {
                    case .success(let image):
                        contentBuilder(image)
                    case .failure(let error):
                        placeholderBuilder()
                            .onAppear {
                                print("🖼️ SignedAsyncImage - Failed to load image: \(signedURL), error: \(error)")
                            }
                    case .empty:
                        placeholderBuilder()
                    @unknown default:
                        placeholderBuilder()
                    }
                }
            } else if let error = loadError {
                placeholderBuilder()
                    .onAppear {
                        print("🖼️ SignedAsyncImage - Failed to generate signed URL for: \(storagePath), error: \(error)")
                    }
            } else {
                placeholderBuilder()
            }
        }
        .task {
            await loadSignedURL()
        }
    }
    
    private func loadSignedURL() async {
        guard signedURL == nil else { return }
        
        do {
            isLoading = true
            let url = try await supabase.getSignedURLString(for: storagePath, bucket: bucket)
            await MainActor.run {
                self.signedURL = url
                self.isLoading = false
                print("🖼️ SignedAsyncImage - Generated signed URL for: \(storagePath)")
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
                print("🖼️ SignedAsyncImage - Failed to generate signed URL for: \(storagePath), error: \(error)")
            }
        }
    }
}

// Convenience initializer for simple cases
extension SignedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(storagePath: String, bucket: String = "meal-photos") {
        self.init(
            storagePath: storagePath,
            bucket: bucket,
            content: { $0 },
            placeholder: { ProgressView() }
        )
    }
}