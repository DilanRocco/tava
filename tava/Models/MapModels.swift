import Foundation
import CoreLocation

// MARK: - Map-specific Data Structures

struct MapCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let meals: [MealWithDetails]
    let restaurant: Restaurant?
    
    var count: Int { meals.count }
    var isCluster: Bool { meals.count > 1 }
}

struct RestaurantWithDetails {
    let restaurant: Restaurant
    let meals: [MealWithDetails]
}

// MARK: - Map Filter Options

enum FriendsFilterOption: String, CaseIterable {
    case all = "All"
    case friends = "Friends"
    case nonFriends = "Discover"
    
    var iconName: String {
        switch self {
        case .all:
            return "globe"
        case .friends:
            return "person.2.fill"
        case .nonFriends:
            return "eye.fill"
        }
    }
}