import SwiftUI

struct MainTabView: View {
    @StateObject private var supabase = SupabaseClient.shared
    @StateObject private var locationService = LocationService()
    @StateObject private var mealService = MealService()
    @StateObject private var googlePlacesService = GooglePlacesService()
    
    var body: some View {
        TabView {
            MapFeedView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Discover")
                }
                .tag(0)
            
            AddMealView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                    Text("Add Meal")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(2)
        }
        .accentColor(.orange)
        .preferredColorScheme(.dark)
        .environmentObject(supabase)
        .environmentObject(locationService)
        .environmentObject(mealService)
        .environmentObject(googlePlacesService)
        .onAppear {
            // Request location permission on app start
            locationService.requestLocationPermission()
        }
    }
} 