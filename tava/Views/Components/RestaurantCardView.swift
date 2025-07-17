import SwiftUI

struct RestaurantCardView: View {
    let restaurant: Restaurant
    let onRemove: (() -> Void)?
    
    init(restaurant: Restaurant, onRemove: (() -> Void)? = nil) {
        self.restaurant = restaurant
        self.onRemove = onRemove
    }
    
    var body: some View {
        HStack {
            // Restaurant image
            AsyncImage(url: URL(string: restaurant.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if !restaurant.displayAddress.isEmpty {
                    Text(restaurant.displayAddress)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                HStack {
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
                    
                    if !restaurant.priceDisplay.isEmpty {
                        Text(restaurant.priceDisplay)
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                            .padding(.leading, 4)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
} 