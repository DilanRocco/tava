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
        
        do {
            let places = try await performTextSearch(
                query: query,
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
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GooglePlacesError.apiError
        }
        
        let detailsResponse = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
        
        guard detailsResponse.status == "OK" else {
            throw GooglePlacesError.apiError
        }
        
        return detailsResponse.result
    }
    
    // MARK: - Private Methods
    
    private func performTextSearch(
        query: String,
        location: CLLocation?,
        radius: Int
    ) async throws -> [GooglePlace] {
        var components = URLComponents(string: "\(baseURL)/textsearch/json")!
        
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
            throw GooglePlacesError.apiError
        }
        
        let searchResponse = try JSONDecoder().decode(GooglePlaceSearchResponse.self, from: data)
        
        guard searchResponse.status == "OK" else {
            throw GooglePlacesError.apiError
        }
        
        return searchResponse.results
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
