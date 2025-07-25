import Foundation
import CoreLocation

class GooglePlacesService: ObservableObject {
    let apiKey = Bundle.main.infoDictionary?["GOOGLE_API_KEY"] as! String
    private let baseURL = "https://maps.googleapis.com/maps/api/place"
    
    @Published var searchResults: [GooglePlace] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Search Places
    
    func searchRestaurants(
        query: String,
        location: CLLocation? = nil,
        radius: Int = 5000,
        limit: Int = 20
    ) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        print("Searching for restaurants with query: \(query)")
        do {
            let places = try await performTextSearch(
                query: query,
                location: location,
                radius: radius
            )
            print("Search results: \(places)")
            await MainActor.run {
                self.searchResults = Array(places.prefix(limit))
            }
        } catch {
            print("Error searching for restaurants: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func searchNearbyRestaurants(
        location: CLLocation,
        radius: Int = 5000,
        limit: Int = 20
    ) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let places = try await performNearbySearch(
                location: location,
                radius: radius
            )
            
            await MainActor.run {
                self.searchResults = Array(places.prefix(limit))
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func getPlaceDetails(placeId: String) async throws -> GooglePlaceDetails {
        var components = URLComponents(string: "\(baseURL)/details/json")!
        components.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "fields", value: "place_id,name,formatted_address,geometry,rating,price_level,photos,formatted_phone_number,website,opening_hours,types"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw GooglePlacesError.invalidURL
        }
        
        print("🔍 Fetching place details for placeId: \(placeId)")
        print("🔍 URL: \(url)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ HTTP Error: \(response)")
            throw GooglePlacesError.apiError
        }
        
        // Print raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 Raw API Response: \(responseString)")
        }
        
        // First try to decode as error response to check status
        do {
            let errorResponse = try JSONDecoder().decode(GooglePlaceErrorResponse.self, from: data)
            print("❌ Google Places API Error: \(errorResponse.status) - \(errorResponse.errorMessage ?? "Unknown error")")
            throw GooglePlacesError.apiError
        } catch {
            // If it's not an error response, try to decode as success response
            do {
                let detailsResponse = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
                
                guard detailsResponse.status == "OK" else {
                    print("❌ Google Places API returned status: \(detailsResponse.status)")
                    throw GooglePlacesError.apiError
                }
                
                print("✅ Successfully fetched place details for: \(detailsResponse.result.name)")
                return detailsResponse.result
            } catch {
                print("❌ Failed to decode response: \(error)")
                throw GooglePlacesError.decodingError
            }
        }
    }
    

    
    // MARK: - Private Methods
    
    private func performTextSearch(
        query: String,
        location: CLLocation?,
        radius: Int
    ) async throws -> [GooglePlace] {
        var components = URLComponents(string: "\(baseURL)/textsearch/json")!
        print("Performing text search with query: \(query)")
        var queryItems = [
            URLQueryItem(name: "query", value: "\(query) restaurant"),
            URLQueryItem(name: "type", value: "restaurant"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        if let location = location {
            let locationString = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            queryItems.append(URLQueryItem(name: "location", value: locationString))
            queryItems.append(URLQueryItem(name: "radius", value: String(radius)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw GooglePlacesError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("Error performing text search: \(response)")
            throw GooglePlacesError.apiError
        }
        
        let searchResponse = try JSONDecoder().decode(GooglePlaceSearchResponse.self, from: data)
        print("Search response: \(searchResponse)")
        guard searchResponse.status == "OK" else {
            throw GooglePlacesError.apiError
        }
        
        var results = searchResponse.results
        
        // Sort results by distance from user location (closest first)
        if let userLocation = location {
            results.sort { place1, place2 in
                let location1 = CLLocation(
                    latitude: place1.geometry.location.lat,
                    longitude: place1.geometry.location.lng
                )
                let location2 = CLLocation(
                    latitude: place2.geometry.location.lat,
                    longitude: place2.geometry.location.lng
                )
                
                let distance1 = userLocation.distance(from: location1)
                let distance2 = userLocation.distance(from: location2)
                
                return distance1 < distance2
            }
        }
        
        return results
    }
    
    private func performNearbySearch(
        location: CLLocation,
        radius: Int
    ) async throws -> [GooglePlace] {
        var components = URLComponents(string: "\(baseURL)/nearbysearch/json")!
        
        let locationString = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        components.queryItems = [
            URLQueryItem(name: "location", value: locationString),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "type", value: "restaurant"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw GooglePlacesError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GooglePlacesError.apiError
        }
        
        let searchResponse = try JSONDecoder().decode(GooglePlaceSearchResponse.self, from: data)
        
        guard searchResponse.status == "OK" else {
            throw GooglePlacesError.apiError
        }
        
        return searchResponse.results
    }
    
    // MARK: - Convert to App Models
    
    /// Converts a Google Place to a Restaurant object for use in drafts
    /// Note: This doesn't save to database - restaurants are created when meals are published
    func convertToRestaurant(_ googlePlace: GooglePlace) -> Restaurant {
        let location = LocationPoint(
            latitude: googlePlace.geometry.location.lat,
            longitude: googlePlace.geometry.location.lng
        )
        
        // Convert Google price_level (0-4) to our price range (1-4)
        let priceRange = googlePlace.priceLevel.map { max(1, $0 + 1) }
        
        return Restaurant(
            id: UUID(),
            googlePlaceId: googlePlace.placeId,
            name: googlePlace.name,
            address: googlePlace.formattedAddress,
            city: extractCity(from: googlePlace.formattedAddress),
            state: extractState(from: googlePlace.formattedAddress),
            postalCode: extractPostalCode(from: googlePlace.formattedAddress),
            country: extractCountry(from: googlePlace.formattedAddress),
            phone: nil, // Would need details call to get phone
            location: location,
            rating: googlePlace.rating,
            priceRange: priceRange,
            categories: googlePlace.types.map { GooglePlaceCategory(alias: $0, title: $0.replacingOccurrences(of: "_", with: " ").capitalized) },
            hours: nil, // Would need details call to get hours
            googleMapsUrl: "https://maps.google.com/?place_id=\(googlePlace.placeId)",
            imageUrl: googlePlace.photos?.first.map { getPhotoURL(photoReference: $0.photoReference) },
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func getPhotoURL(photoReference: String, maxWidth: Int = 400) -> String {
        return "\(baseURL)/photo?photo_reference=\(photoReference)&maxwidth=\(maxWidth)&key=\(apiKey)"
    }
    
    // Helper methods to extract address components
    private func extractCity(from address: String?) -> String? {
        // Simple extraction - in production you'd want more sophisticated parsing
        guard let address = address else { return nil }
        let components = address.components(separatedBy: ", ")
        return components.count > 1 ? components[components.count - 2] : nil
    }
    
    private func extractState(from address: String?) -> String? {
        guard let address = address else { return nil }
        let components = address.components(separatedBy: ", ")
        if let lastComponent = components.last {
            let stateZip = lastComponent.components(separatedBy: " ")
            return stateZip.first
        }
        return nil
    }
    
    private func extractPostalCode(from address: String?) -> String? {
        guard let address = address else { return nil }
        let components = address.components(separatedBy: ", ")
        if let lastComponent = components.last {
            let stateZip = lastComponent.components(separatedBy: " ")
            return stateZip.count > 1 ? stateZip.last : nil
        }
        return nil
    }
    
    private func extractCountry(from address: String?) -> String? {
        // For US addresses, country is typically not in the formatted address
        // You might need to use the address components from details API for accurate country info
        return "US"
    }
}

// MARK: - Google Places API Models

struct GooglePlaceSearchResponse: Codable {
    let results: [GooglePlace]
    let status: String
    let nextPageToken: String?
    
    enum CodingKeys: String, CodingKey {
        case results, status
        case nextPageToken = "next_page_token"
    }
}

struct GooglePlaceDetailsResponse: Codable {
    let result: GooglePlaceDetails
    let status: String
}

struct GooglePlaceErrorResponse: Codable {
    let status: String
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case errorMessage = "error_message"
    }
}

struct GooglePlace: Codable, Identifiable {
    let placeId: String
    let name: String
    let formattedAddress: String?
    let geometry: GoogleGeometry
    let rating: Double?
    let priceLevel: Int?
    let photos: [GooglePhoto]?
    let types: [String]
    let businessStatus: String?
    
    var id: String { placeId }
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case geometry, rating, photos, types
        case priceLevel = "price_level"
        case businessStatus = "business_status"
    }
}

struct GooglePlaceDetails: Codable {
    let placeId: String
    let name: String
    let formattedAddress: String?
    let geometry: GoogleGeometry
    let rating: Double?
    let priceLevel: Int?
    let photos: [GooglePhoto]?
    let formattedPhoneNumber: String?
    let website: String?
    let openingHours: GoogleOpeningHours?
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case formattedAddress = "formatted_address"
        case geometry, rating, photos, types, website
        case priceLevel = "price_level"
        case formattedPhoneNumber = "formatted_phone_number"
        case openingHours = "opening_hours"
    }
}

struct GoogleGeometry: Codable {
    let location: GoogleLocation
}

struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}

struct GooglePhoto: Codable {
    let photoReference: String
    let height: Int
    let width: Int
    
    enum CodingKeys: String, CodingKey {
        case photoReference = "photo_reference"
        case height, width
    }
}

struct GoogleOpeningHours: Codable, Hashable, Equatable {
    let openNow: Bool?
    let periods: [GooglePeriod]?
    let weekdayText: [String]?
    
    enum CodingKeys: String, CodingKey {
        case openNow = "open_now"
        case periods
        case weekdayText = "weekday_text"
    }
}

struct GooglePeriod: Codable, Hashable, Equatable {
    let open: GoogleDayTime
    let close: GoogleDayTime?
}

struct GoogleDayTime: Codable, Hashable, Equatable {
    let day: Int
    let time: String
}

struct GooglePlaceCategory: Codable, Hashable {
    let alias: String
    let title: String
}

enum GooglePlacesError: Error, LocalizedError {
    case invalidURL
    case apiError
    case decodingError
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .apiError:
            return "Google Places API error"
        case .decodingError:
            return "Failed to decode response"
        case .noResults:
            return "No results found"
        }
    }
} 
