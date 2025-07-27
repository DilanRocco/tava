import SwiftUI

struct CacheManagementView: View {
    @State private var cacheInfo: CacheInfo?
    @State private var showingClearConfirmation = false
    
    private let imageCache = ImageCacheService.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Cache Statistics") {
                    if let info = cacheInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Memory Images:")
                                Spacer()
                                Text("\(info.memoryImageCount)")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Disk Cache Size:")
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: Int64(info.diskCacheSize), countStyle: .file))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Signed URLs Cached:")
                                Spacer()
                                Text("\(info.signedURLCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Loading cache information...")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Cache Management") {
                    Button("Refresh Statistics") {
                        refreshCacheInfo()
                    }
                    
                    Button("Clear Expired Items") {
                        imageCache.clearExpiredItems()
                        refreshCacheInfo()
                    }
                    
                    Button("Clear All Caches", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
                
                Section("Cache Strategy Info") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Our caching strategy:")
                            .font(.headline)
                        
                        Text("• **3-Layer Cache**: Memory → Disk → Download")
                        Text("• **Memory**: 50MB limit, fastest access")
                        Text("• **Disk**: 200MB limit, persistent storage")
                        Text("• **Signed URLs**: Cached for 50min, auto-refresh")
                        Text("• **Auto-Cleanup**: Expired items removed automatically")
                        Text("• **Preloading**: Images loaded ahead of time for smooth scrolling")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Image Cache")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        refreshCacheInfo()
                    }
                    .font(.caption)
                }
            }
        }
        .alert("Clear All Caches", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                ImageCacheManager.clearCache()
                refreshCacheInfo()
            }
        } message: {
            Text("This will clear all cached images and signed URLs. Images will need to be downloaded again.")
        }
        .onAppear {
            refreshCacheInfo()
        }
    }
    
    private func refreshCacheInfo() {
        cacheInfo = ImageCacheManager.getCacheInfo()
    }
}

#Preview {
    CacheManagementView()
}