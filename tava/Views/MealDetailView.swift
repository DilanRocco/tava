import SwiftUI

struct MealDetailView: View {
    let meal: MealWithDetails
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var mealService: MealService
    @State private var currentPhotoIndex = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Photo carousel
                    if !meal.photos.isEmpty {
                        photoCarousel
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // User info and meal header
                        userSection
                        
                        // Meal title and description
                        mealInfoSection
                        
                        // Restaurant info (if applicable)
                        if let restaurant = meal.restaurant {
                            restaurantSection(restaurant)
                        }
                        
                        // Ingredients (for homemade meals)
                        if meal.meal.mealType == .homemade, let ingredients = meal.meal.ingredients {
                            ingredientsSection(ingredients)
                        }
                        
                        // Tags
                        if !meal.meal.tags.isEmpty {
                            tagsSection
                        }
                        
                        // Rating and cost
                        detailsSection
                        
                        // Reactions
                        reactionsSection
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Share functionality
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    private var photoCarousel: some View {
        VStack {
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(meal.photos.enumerated()), id: \.offset) { index, photo in
                    AsyncImage(url: URL(string: photo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(ProgressView())
                    }
                    .frame(height: 300)
                    .clipped()
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 300)
            
            if meal.photos.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<meal.photos.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPhotoIndex ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var userSection: some View {
        HStack {
            AsyncImage(url: URL(string: meal.user.avatarUrl ?? "")) { image in
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.user.displayName ?? meal.user.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text(meal.meal.eatenAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Image(systemName: meal.meal.mealType == .homemade ? "house.fill" : "building.2.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.leading, 8)
                }
            }
            
            Spacer()
            
            // Privacy indicator
            if meal.meal.privacy != .public {
                Image(systemName: meal.meal.privacy == .friendsOnly ? "person.2.fill" : "lock.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }
    
    private var mealInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(meal.meal.displayTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            if let description = meal.meal.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func restaurantSection(_ restaurant: Restaurant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Restaurant", systemImage: "building.2.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !restaurant.displayAddress.isEmpty {
                    Text(restaurant.displayAddress)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    if let rating = restaurant.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                        }
                    }
                    
                    if !restaurant.priceDisplay.isEmpty {
                        Text(restaurant.priceDisplay)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.leading, 8)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func ingredientsSection(_ ingredients: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ingredients", systemImage: "list.bullet")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text(ingredients)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tags", systemImage: "tag.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(meal.meal.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                if let rating = meal.meal.rating {
                    HStack {
                        Text("Rating:")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                if let cost = meal.meal.cost {
                    HStack {
                        Text("Cost:")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("$\(cost.formatted())")
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    Text("Privacy:")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(meal.meal.privacy.displayName)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var reactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reactions", systemImage: "heart.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            HStack {
                ForEach(ReactionType.allCases, id: \.self) { reactionType in
                    Button(action: {
                        Task {
                            try? await mealService.addReaction(mealId: meal.meal.id, reactionType: reactionType)
                        }
                    }) {
                        VStack {
                            Text(reactionType.emoji)
                                .font(.title2)
                            
                            Text(reactionType.displayName)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
} 