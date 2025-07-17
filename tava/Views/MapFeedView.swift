import SwiftUI
import MapKit

struct MapFeedView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @State private var showFeed = false
    @State private var selectedMeal: MealWithDetails?
    @State private var showFilters = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to SF
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var hasInitialized = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map View - completely independent
                Map(coordinateRegion: $mapRegion, 
                    showsUserLocation: true,
                    annotationItems: mealService.nearbyMeals) { meal in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(
                        latitude: meal.meal.location?.latitude ?? 0,
                        longitude: meal.meal.location?.longitude ?? 0
                    )) {
                        MealMapPin(meal: meal) {
                            selectedMeal = meal
                        }
                    }
                }
                .ignoresSafeArea()
                
                // Recenter button - always show it
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            if let location = locationService.location {
                                withAnimation {
                                    mapRegion = MKCoordinateRegion(
                                        center: location.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showFeed = true
                    }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showFilters = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailView(meal: meal)
        }
        .sheet(isPresented: $showFeed) {
            FeedView()
        }
        .sheet(isPresented: $showFilters) {
            FilterView()
        }
        .onAppear {
            // Only set initial location once
            if !hasInitialized, let location = locationService.location {
                mapRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                hasInitialized = true
            }
        }
        .task {
            if let location = locationService.location {
                await mealService.fetchNearbyMeals(location: location)
            }
        }
    }
}

struct MealMapPin: View {
    let meal: MealWithDetails
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 40, height: 40)
                
                if let photo = meal.primaryPhoto {
                    AsyncImage(url: URL(string: photo.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
}

struct FeedView: View {
    @EnvironmentObject var mealService: MealService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(mealService.meals) { meal in
                        MealCardView(meal: meal)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await mealService.fetchUserFeed()
        }
    }
} 