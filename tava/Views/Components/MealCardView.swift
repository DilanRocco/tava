import SwiftUI

struct MealCardView: View {
    let meal: MealWithDetails
    @EnvironmentObject var mealService: MealService
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with user info
                HStack {
                    // User avatar
                    AsyncImage(url: URL(string: meal.user.avatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.user.displayName ?? meal.user.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(meal.meal.eatenAt.timeAgoDisplay)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Meal type indicator
                    Image(systemName: meal.meal.mealType == .homemade ? "house.fill" : "building.2.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Meal photo
                if let photo = meal.primaryPhoto {
                    AsyncImage(url: URL(string: photo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                ProgressView()
                            )
                    }
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Meal info
                VStack(alignment: .leading, spacing: 8) {
                    Text(meal.meal.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let description = meal.meal.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Restaurant info or location
                    if let restaurant = meal.restaurant {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text(restaurant.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            if let rating = restaurant.rating {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption2)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    
                    // Tags
                    if !meal.meal.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
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
                
                // Action buttons
                HStack {
                    // Reaction button
                    Button(action: {
                        Task {
                            try? await mealService.addReaction(mealId: meal.meal.id, reactionType: .like)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                                .foregroundColor(.orange)
                            Text("\(meal.reactionCount)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Rating display
                    if let rating = meal.meal.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            MealDetailView(meal: meal)
        }
    }
}

extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 