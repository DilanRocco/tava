import SwiftUI
import CoreLocation

struct RestaurantSearchView: View {
    @Binding var selectedRestaurant: Restaurant?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var googlePlacesService = GooglePlacesService()
    @EnvironmentObject var locationService: LocationService
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var hasSearched = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search restaurants...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                hasSearched = false
                                googlePlacesService.searchResults = []
                            } else if newValue.count >= 2 {
                                // Cancel previous search
                                searchTask?.cancel()
                                
                                // Start new search immediately
                                searchTask = Task {
                                    await performSearch(query: newValue)
                                }
                            } else {
                                // Less than 2 characters, clear results
                                hasSearched = false
                                googlePlacesService.searchResults = []
                            }
                        }
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            hasSearched = false
                            googlePlacesService.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                if googlePlacesService.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Searching nearby...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else if googlePlacesService.searchResults.isEmpty && !searchText.isEmpty && hasSearched {
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
                        Text("Start typing to find nearby restaurants")
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
                        searchTask?.cancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Request location permission if needed
                if locationService.authorizationStatus == .notDetermined {
                    locationService.requestLocationPermission()
                }
            }
        }
    }
    

    
    private func performSearch(query: String? = nil) {
        let searchQuery = query ?? searchText
        guard !searchQuery.isEmpty else { return }
        
        Task {
            // Use user location for proximity-based results
            await googlePlacesService.searchRestaurants(
                query: searchQuery,
                location: locationService.location,
                radius: 5000, // 5km radius
                limit: 20
            )
            
            // Mark that we've completed a search
            await MainActor.run {
                hasSearched = true
            }
        }
    }
}

struct RestaurantSearchRow: View {
    let place: GooglePlace
    let onSelect: () -> Void
    let apiKey = Bundle.main.infoDictionary?["GOOGLE_API_KEY"] as! String
    @EnvironmentObject var locationService: LocationService
    
    private var distanceText: String? {
        guard let userLocation = locationService.location else { return nil }
        
        let restaurantLocation = CLLocation(
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        )
        
        let distance = userLocation.distance(from: restaurantLocation)
        
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(place.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()

                    }
                    
                    HStack {
                        Text(place.formattedAddress ?? "Address not available")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 
