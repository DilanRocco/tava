import SwiftUI

struct MealDetailView: View {
    let meal: MealWithDetails
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with user info
                    headerSection
                    
                    // Main meal photo
                    mainPhotoSection
                    
                    // Meal details
                    mealDetailsSection
                    
                    // All photos
                    if meal.photos.count > 1 {
                        allPhotosSection
                    }
                }
                .padding()
            }
            .navigationTitle("Meal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            if let avatarUrl = meal.user.avatarUrl, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.user.displayName ?? meal.user.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(meal.meal.eatenAt.timeAgoDisplay)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
    
    private var mainPhotoSection: some View {
        Group {
            if let photo = meal.primaryPhoto, !photo.storagePath.isEmpty {
                CachedAsyncImage(storagePath: photo.storagePath) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(maxHeight: 400)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var mealDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(meal.meal.displayTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            if let description = meal.meal.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if let restaurant = meal.restaurant {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.orange)
                    Text(restaurant.name)
                        .font(.subheadline)
                }
            }
            
            if let rating = meal.meal.rating {
                HStack {
                    Text("Rating:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(star <= rating ? .yellow : .gray)
                                .font(.caption)
                        }
                    }
                }
            }
            
            if !meal.meal.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(meal.meal.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var allPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Photos")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(meal.photos) { photo in
                    if !photo.storagePath.isEmpty {
                        CachedAsyncImage(storagePath: photo.storagePath) { image in
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.5)
                                )
                        }
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
            }
        }
    }
}
