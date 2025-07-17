import SwiftUI

struct RestaurantSearchView: View {
    @Binding var selectedRestaurant: Restaurant?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var googlePlacesService = GooglePlacesService()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search restaurants...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                if googlePlacesService.isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if googlePlacesService.searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No restaurants found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else if searchText.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "building.2.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Search for restaurants")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Find restaurants to add to your meal")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List(googlePlacesService.searchResults) { place in
                        RestaurantSearchRow(place: place) {
                            selectedRestaurant = googlePlacesService.convertToRestaurant(place)
                            dismiss()
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
            }
            .navigationTitle("Find Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            await googlePlacesService.searchRestaurants(query: searchText)
        }
    }
}

struct RestaurantSearchRow: View {
    let place: GooglePlace
    let onSelect: () -> Void
    let apiKey = Bundle.main.infoDictionary?["GOOGLE_API_KEY"] as! String
    var body: some View {
        Button(action: onSelect) {
            HStack {
                AsyncImage(url: URL(string: place.photos?.first.map { 
                    "https://maps.googleapis.com/maps/api/place/photo?photo_reference=\($0.photoReference)&maxwidth=400&key=\(apiKey)" 
                } ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(place.formattedAddress ?? "Address not available")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if let rating = place.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption2)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if let priceLevel = place.priceLevel {
                            Text(String(repeating: "$", count: max(1, priceLevel + 1)))
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                                .padding(.leading, 4)
                        }
                        
                        Spacer()
                        
                        if place.businessStatus == "OPERATIONAL" {
                            Text("Open")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 
