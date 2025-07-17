import Foundation

struct Restaurant: Codable, Identifiable, Hashable {
    let id: UUID
    let googlePlaceId: String?
    let name: String
    let address: String?
    let city: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let phone: String?
    let location: LocationPoint?
    let rating: Double?
    let priceRange: Int?
    let categories: [GooglePlaceCategory]
    let hours: GoogleOpeningHours?
    let googleMapsUrl: String?
    let imageUrl: String?
    let createdAt: Date
    let updatedAt: Date
    
    var displayAddress: String {
        let addressParts = [address, city, state].compactMap { $0 }
        return addressParts.joined(separator: ", ")
    }
    
    var priceDisplay: String {
        guard let priceRange = priceRange else { return "" }
        return String(repeating: "$", count: min(priceRange, 4))
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case googlePlaceId = "google_place_id"
        case name
        case address
        case city
        case state
        case postalCode = "postal_code"
        case country
        case phone
        case location
        case rating
        case priceRange = "price_range"
        case categories
        case hours
        case googleMapsUrl = "google_maps_url"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Note: GooglePlaceCategory and GoogleOpeningHours are now defined in GooglePlacesService.swift
// They are imported here for use in the Restaurant model 