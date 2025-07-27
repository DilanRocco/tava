import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

// Map models are now in Models/MapModels.swift

struct IdentifiableString: Identifiable {
    let id: String
}

struct MapFeedView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    
    @State private var showFeed = false
    @State private var selectedRestaurant: RestaurantWithDetails?
    @State private var showFilters = false
    @State private var showProfile = false
    @State private var showRestaurantGrid = false
    @State private var friendsFilter: FriendsFilterOption = .all
    @State private var mapClusters: [MapCluster] = []
    @State private var currentZoomLevel: Double = 15.0
    @State private var mapView: MapView?
    
    // FriendsFilterOption is now in Models/MapModels.swift
    
    var restaurantMeals: [MealWithDetails] {
        let allMeals = mealService.nearbyMeals.filter { $0.restaurant != nil }
        
        let filtered = switch friendsFilter {
        case .all:
            allMeals
        case .friends:
            allMeals.filter { $0.user.id != supabase.currentUser?.id }
        case .nonFriends:
            allMeals.filter { $0.user.id == supabase.currentUser?.id }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Citizen-Style Mapbox Map with Clustering
                CitizenStyleMapView(
                    meals: restaurantMeals,
                    userLocation: locationService.location,
                    clusters: $mapClusters,
                    currentZoom: $currentZoomLevel,
                    mapView: $mapView,
                    onMealTap: { meal in
                        // Navigate to restaurant grid instead of meal detail
                        guard let restaurant = meal.restaurant else { return }
                        
                        let restaurantMeals = restaurantMeals.filter { $0.restaurant?.id == restaurant.id }
                        selectedRestaurant = RestaurantWithDetails(
                            restaurant: restaurant,
                            meals: restaurantMeals
                        )
                        showRestaurantGrid = true
                    },
                    onClusterTap: { cluster in
                        // Handle cluster tap - could zoom to cluster bounds
                    }
                )
                .ignoresSafeArea()
                
                // Modern UI Overlay with Profile and Filter
                ModernMapOverlay(
                    showFeed: $showFeed,
                    showProfile: $showProfile,
                    showFilters: $showFilters,
                    friendsFilter: $friendsFilter,
                    onRecenter: {
                        recenterMap()
                    }
                )
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showRestaurantGrid) {
                if let selectedRestaurant = selectedRestaurant {
                    RestaurantNavigationView(
                        restaurant: selectedRestaurant.restaurant,
                        meals: selectedRestaurant.meals
                    )
                }
            }
            .sheet(isPresented: $showFeed) {
                MapFeedListView(meals: restaurantMeals)
            }
            .sheet(isPresented: $showProfile) {
                NavigationView {
                    ProfileView()
                        .environmentObject(supabase)
                        .environmentObject(locationService)
                        .environmentObject(mealService)
                        .environmentObject(googlePlacesService)
                }
            }
            .task {
                await locationService.requestLocationPermission()
                
                // Fetch nearby meals for the map
                if let userLocation = locationService.location {
                    await mealService.fetchNearbyMeals(location: userLocation, radius: 10000) // 10km radius
                }
            }
            .onChange(of: restaurantMeals.count) {
                // Debounce clustering updates
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    mapClusters = generateClusters(from: restaurantMeals, zoomLevel: currentZoomLevel)
                }
            }
            .onChange(of: currentZoomLevel) {
                // Debounce clustering updates
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    mapClusters = generateClusters(from: restaurantMeals, zoomLevel: currentZoomLevel)
                }
            }
            .onChange(of: locationService.location) { _, newLocation in
                // Fetch meals when location changes
                if let location = newLocation {
                    Task {
                        await mealService.fetchNearbyMeals(location: location, radius: 10000)
                    }
                }
            }
        }
    }
    
    private func recenterMap() {
        guard let mapView = mapView, let userLocation = locationService.location else { return }
        
        mapView.camera.fly(
            to: CameraOptions(
                center: userLocation.coordinate,
                zoom: 15.0
            ),
            duration: 0.5
        )
    }
    
    // MARK: - Clustering Logic
    private func generateClusters(from meals: [MealWithDetails], zoomLevel: Double) -> [MapCluster] {
        guard !meals.isEmpty else { return [] }
        
        // Group meals by restaurant first
        let restaurantGroups = Dictionary(grouping: meals) { meal in
            meal.restaurant?.id ?? meal.id
        }
        
        var clusters: [MapCluster] = []
        
        // Convert restaurant groups to clusters
        for (_, restaurantMeals) in restaurantGroups {
            guard let firstMeal = restaurantMeals.first,
                  let restaurant = firstMeal.restaurant,
                  let location = restaurant.location else { continue }
            
            let coordinate = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            let cluster = MapCluster(
                coordinate: coordinate,
                meals: restaurantMeals,
                restaurant: restaurant
            )
            clusters.append(cluster)
        }
        
        // For high zoom levels, show individual clusters
        // For low zoom levels, merge nearby clusters
        let finalClusters: [MapCluster]
        if zoomLevel < 12 {
            finalClusters = mergeClusters(clusters, threshold: 0.01) // ~1km at equator
        } else if zoomLevel < 15 {
            finalClusters = mergeClusters(clusters, threshold: 0.005) // ~500m at equator
        } else {
            finalClusters = clusters // Show all individual restaurant clusters
        }
        
        return finalClusters
    }
    
    private func mergeClusters(_ clusters: [MapCluster], threshold: Double) -> [MapCluster] {
        var mergedClusters: [MapCluster] = []
        var processedIndices: Set<Int> = []
        
        for (index, cluster) in clusters.enumerated() {
            if processedIndices.contains(index) { continue }
            
            var nearbyMeals = cluster.meals
            var centroidLat = cluster.coordinate.latitude * Double(cluster.count)
            var centroidLng = cluster.coordinate.longitude * Double(cluster.count)
            var totalCount = cluster.count
            
            processedIndices.insert(index)
            
            // Find nearby clusters to merge
            for (otherIndex, otherCluster) in clusters.enumerated() {
                if processedIndices.contains(otherIndex) { continue }
                
                let distance = sqrt(
                    pow(cluster.coordinate.latitude - otherCluster.coordinate.latitude, 2) +
                    pow(cluster.coordinate.longitude - otherCluster.coordinate.longitude, 2)
                )
                
                if distance < threshold {
                    nearbyMeals.append(contentsOf: otherCluster.meals)
                    centroidLat += otherCluster.coordinate.latitude * Double(otherCluster.count)
                    centroidLng += otherCluster.coordinate.longitude * Double(otherCluster.count)
                    totalCount += otherCluster.count
                    processedIndices.insert(otherIndex)
                }
            }
            
            let finalCoordinate = CLLocationCoordinate2D(
                latitude: centroidLat / Double(totalCount),
                longitude: centroidLng / Double(totalCount)
            )
            
            let mergedCluster = MapCluster(
                coordinate: finalCoordinate,
                meals: nearbyMeals,
                restaurant: nearbyMeals.count == cluster.meals.count ? cluster.restaurant : nil
            )
            
            mergedClusters.append(mergedCluster)
        }
        
        return mergedClusters
    }
}

// MARK: - Modern Map Overlay
struct ModernMapOverlay: View {
    @Binding var showFeed: Bool
    @Binding var showProfile: Bool
    @Binding var showFilters: Bool
    @Binding var friendsFilter: FriendsFilterOption
    let onRecenter: () -> Void
    
    var body: some View {
        VStack {
            // Top bar with profile and controls
            HStack {
                // Profile button (top left)
                Button(action: {
                    showProfile = true
                }) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                }
                
                Spacer()
                
                // Filter button
                Button(action: {
                    showFilters.toggle()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16, weight: .medium))
                        Text(friendsFilter.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                
                // Recenter button
                RecenterButton(onRecenter: onRecenter)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Friends Filter Overlay
            if showFilters {
                friendsFilterView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: showFilters)
    }
    
    private var friendsFilterView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filter Meals")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showFilters = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            HStack(spacing: 12) {
                ForEach(FriendsFilterOption.allCases, id: \.self) { option in
                    FilterOptionButton(
                        title: option.rawValue,
                        isSelected: friendsFilter == option,
                        icon: option.iconName
                    ) {
                        friendsFilter = option
                        showFilters = false
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)
        .padding(.horizontal, 20)
    }
}

// MARK: - Filter Option Button
struct FilterOptionButton: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .orange : .white.opacity(0.7))
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .orange : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? Color.orange.opacity(0.2) : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.orange : Color.white.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// FriendsFilterOption extension is now in Models/MapModels.swift

// MARK: - Map Feed List View
struct MapFeedListView: View {
    let meals: [MealWithDetails]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(meals, id: \.id) { meal in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(meal.meal.displayTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(meal.meal.description ?? "No description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        if let restaurant = meal.restaurant {
                            Text(restaurant.name)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Nearby Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Recenter Button
struct RecenterButton: View {
    let onRecenter: () -> Void
    
    var body: some View {
        Button(action: onRecenter) {
            Image(systemName: "location.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
        }
        .buttonStyle(ModernGlowButtonStyle())
    }
}

// MARK: - Button Styles
struct ModernGlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(0.8),
                                    Color.orange.opacity(0.4),
                                    Color.orange.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 15,
                                endRadius: 30
                            )
                        )
                    
                    // Main button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange,
                                    Color.orange.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                }
            )
            .shadow(
                color: .orange.opacity(0.4),
                radius: 15,
                x: 0,
                y: 8
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Citizen-Style Map Implementation
struct CitizenStyleMapView: UIViewRepresentable {
    let meals: [MealWithDetails]
    let userLocation: CLLocation?
    @Binding var clusters: [MapCluster]
    @Binding var currentZoom: Double
    @Binding var mapView: MapView?
    let onMealTap: (MealWithDetails) -> Void
    let onClusterTap: (MapCluster) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MapView {
        // Get and verify API key
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "MAPBOX_API_KEY") as? String else {
            print("❌ MAPBOX_API_KEY not found in Info.plist")
            return MapView(frame: .zero)
        }
        
        // Use user location or default to San Francisco
        let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let initialLocation = userLocation?.coordinate ?? defaultLocation
        
        // Create camera options
        let cameraOptions = CameraOptions(
            center: initialLocation,
            zoom: 15.0
        )
        
        // Create map with resource options including access token
        let resourceOptions = ResourceOptions(accessToken: apiKey)
        let mapInitOptions = MapInitOptions(
            resourceOptions: resourceOptions,
            cameraOptions: cameraOptions
        )
        
        let mapView = MapView(frame: .zero, mapInitOptions: mapInitOptions)
        
        // Store reference for recentering
        DispatchQueue.main.async {
            self.mapView = mapView
        }
        
        // Hide all ornaments for ultra-clean look like Citizen
        mapView.ornaments.options.scaleBar.visibility = .hidden
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.attributionButton.margins = CGPoint(x: 8, y: 8)
        
        // Load custom Citizen-style JSON
        Task {
            await loadCitizenStyleJSON(to: mapView)
        }
        
        // Enable all gestures for smooth interaction
        mapView.gestures.options.rotateEnabled = true
        mapView.gestures.options.pinchEnabled = true
        mapView.gestures.options.pitchEnabled = true
        mapView.gestures.options.panEnabled = true
        mapView.gestures.options.doubleTouchToZoomOutEnabled = true
        mapView.gestures.options.doubleTapToZoomInEnabled = true
        
        // Add tap gesture for annotations
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Store coordinator
        context.coordinator.mapView = mapView
        
        return mapView
    }
    
    // MARK: - Load Custom Citizen Style JSON (Async)
    private func loadCitizenStyleJSON(to mapView: MapView) async {
        // Your custom Citizen style JSON
        do {
            guard let path = Bundle.main.path(forResource: "CitizenMapStyle", ofType: "json") else {
                print("❌ CitizenMapStyle.json not found in bundle, using dark style")
                mapView.mapboxMap.style.uri = StyleURI.dark
                return
            }
            
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
            let jsonString = String(data: jsonData, encoding: .utf8)
            
            guard let styleJSON = jsonString else {
                print("❌ Could not convert JSON data to string")
                mapView.mapboxMap.style.uri = StyleURI.dark
                return
            }
            
            mapView.mapboxMap.loadStyleJSON(styleJSON) { result in
                switch result {
                case .success(_):
                    print("✅ Citizen style loaded")
                case .failure(let error):
                    print("❌ Failed: \(error)")
                    mapView.mapboxMap.style.uri = StyleURI.dark
                }
            }
        }
        catch {
            print("❌ Error loading style from bundle: \(error)")
            mapView.mapboxMap.style.uri = StyleURI.dark
        }
    }
    
    func updateUIView(_ mapView: MapView, context: Context) {
        // Enable beautiful location puck (but don't reset camera)
        if userLocation != nil {
            mapView.location.options.puckType = .puck2D()
        }
        
        // Update annotations only if clusters have changed
        if context.coordinator.lastClusterCount != clusters.count {
            updateMapAnnotations(mapView, context: context)
            context.coordinator.lastClusterCount = clusters.count
        }
    }
    
    private func updateMapAnnotations(_ mapView: MapView, context: Context) {
        // Remove existing annotations
        if let manager = context.coordinator.annotationManager {
            manager.annotations = []
        }
        
        // Create annotation manager if needed
        if context.coordinator.annotationManager == nil {
            context.coordinator.annotationManager = mapView.annotations.makePointAnnotationManager()
        }
        
        guard let annotationManager = context.coordinator.annotationManager else { return }
        
        // Create point annotations with custom image
        var annotations: [PointAnnotation] = []
        
        for cluster in clusters {
            var annotation = PointAnnotation(coordinate: cluster.coordinate)
            
            // Create custom image for coffee marker
            let markerImage = createCoffeeMarkerImage(count: cluster.isCluster ? cluster.count : nil)
            
            // Convert UIImage to annotation image
            if let image = markerImage {
                annotation.image = .init(image: image, name: "coffee-\(cluster.id)")
            }
            
            // Set size and anchor
            annotation.iconSize = 1.0
            annotation.iconAnchor = .center
            
            annotations.append(annotation)
        }
        
        // Update all annotations at once
        annotationManager.annotations = annotations
    }
    
    private func createCoffeeMarkerImage(count: Int?) -> UIImage? {
        let size = CGSize(width: 60, height: 60)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            _ = CGRect(origin: .zero, size: size)
            
            // Draw white circle
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: CGRect(x: 5, y: 5, width: 50, height: 50))
            
            // Add shadow
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.2).cgColor)
            
            // Draw coffee emoji
            let coffeeEmoji = "☕"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28),
            ]
            
            let textSize = coffeeEmoji.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2 - 2,
                width: textSize.width,
                height: textSize.height
            )
            
            coffeeEmoji.draw(in: textRect, withAttributes: attributes)
            
            // Draw count badge if needed
            if let count = count, count > 1 {
                // Badge background
                context.cgContext.setFillColor(UIColor.systemOrange.cgColor)
                let badgeRect = CGRect(x: 35, y: 5, width: 20, height: 20)
                context.cgContext.fillEllipse(in: badgeRect)
                
                // Badge text
                let countText = "\(count)"
                let countAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.white
                ]
                
                let countSize = countText.size(withAttributes: countAttributes)
                let countRect = CGRect(
                    x: badgeRect.midX - countSize.width / 2,
                    y: badgeRect.midY - countSize.height / 2,
                    width: countSize.width,
                    height: countSize.height
                )
                
                countText.draw(in: countRect, withAttributes: countAttributes)
            }
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject {
        var parent: CitizenStyleMapView
        var mapView: MapView?
        var annotationManager: PointAnnotationManager?
        var lastClusterCount: Int = 0
        var clusterMapping: [String: MapCluster] = [:]
        
        init(_ parent: CitizenStyleMapView) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }
            let point = gesture.location(in: mapView)
            
            // Find the closest cluster to the tap point
            var closestCluster: MapCluster?
            var closestDistance: Double = Double.infinity
            
            for cluster in parent.clusters {
                let clusterPoint = mapView.mapboxMap.point(for: cluster.coordinate)
                let distance = sqrt(pow(point.x - clusterPoint.x, 2) + pow(point.y - clusterPoint.y, 2))
                
                if distance < 40 && distance < closestDistance { // Increased tap area
                    closestDistance = distance
                    closestCluster = cluster
                }
            }
            
            if let cluster = closestCluster {
                if cluster.isCluster {
                    parent.onClusterTap(cluster)
                } else if let meal = cluster.meals.first {
                    parent.onMealTap(meal)
                }
            }
        }
    }
}

// MARK: - Async Location Service Extension
extension LocationService {
    func requestLocationPermission() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Your existing location permission request code
                continuation.resume()
            }
        }
    }
}

// MARK: - Meal Detail Modal
struct MealDetailModal: View {
    let meal: MealWithDetails
    let onRestaurantTap: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Hero image or placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Meal Photo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
                
                // Meal Info
                VStack(alignment: .leading, spacing: 16) {
                    Text(meal.meal.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = meal.meal.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Restaurant Info
                    if let restaurant = meal.restaurant {
                        Button(action: onRestaurantTap) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Eaten at")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(restaurant.name)
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Meal Stats
                    HStack(spacing: 20) {
                        if let rating = meal.meal.rating {
                            VStack {
                                Text("Rating")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        
                        if meal.meal.cost != nil {
                            VStack {
                                Text("Cost")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: meal.meal.cost!).doubleValue))")
                                    .font(.headline)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Meal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Restaurant Navigation View (for NavigationStack)
struct RestaurantNavigationView: View {
    let restaurant: Restaurant
    let meals: [MealWithDetails]
    @State private var selectedMeal: MealWithDetails?
    @State private var showRestaurantDetail = false
    @State private var showRestaurantFeed = false
    
    var body: some View {
        RestaurantMealsGridView(
            restaurant: restaurant,
            meals: meals,
            onRestaurantDetailsTap: {
                showRestaurantDetail = true
            },
            onMealTap: { meal in
                selectedMeal = meal
                showRestaurantFeed = true
            }
        )
        .navigationDestination(isPresented: $showRestaurantDetail) {
            RestaurantDetailView(restaurantWithDetails: RestaurantWithDetails(restaurant: restaurant, meals: meals))
        }
        .navigationDestination(isPresented: $showRestaurantFeed) {
            if let selectedMeal = selectedMeal {
                RestaurantFeedView(
                    meals: meals,
                    startingMeal: selectedMeal
                )
            }
        }
    }
}

// MARK: - Restaurant Meals Grid View
struct RestaurantMealsGridView: View {
    let restaurant: Restaurant
    let meals: [MealWithDetails]
    let onRestaurantDetailsTap: () -> Void
    let onMealTap: (MealWithDetails) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Restaurant Header with Details Button
                restaurantHeaderSection
                
                // Meals Grid
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(meals, id: \.id) { meal in
                        MealGridItemView(meal: meal) {
                            onMealTap(meal)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var restaurantHeaderSection: some View {
        VStack(spacing: 16) {
            // Restaurant basic info
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurant.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let address = restaurant.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        if let rating = restaurant.rating {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12))
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if let priceRange = restaurant.priceRange {
                            Text(String(repeating: "$", count: priceRange))
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
                
                // Restaurant image
                OptimizedRestaurantImage(
                    imageUrl: restaurant.imageUrl,
                    bucket: "restaurant-photos"
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // View Restaurant Details Button
            Button(action: onRestaurantDetailsTap) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("View Restaurant Details")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.orange)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Meals count
            HStack {
                Text("\(meals.count) meals from this restaurant")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Meal Grid Item View
struct MealGridItemView: View {
    let meal: MealWithDetails
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Meal image or placeholder
                ZStack {
                    if let photo = meal.primaryPhoto {
                        CachedAsyncImage(
                            storagePath: photo.storagePath,
                            bucket: "meal-photos"
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 140)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 140)
                                .overlay(
                                    ProgressView()
                                        .tint(.orange)
                                )
                        }
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.orange.opacity(0.3),
                                        Color.orange.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 140)
                            .overlay(
                                Image(systemName: "photo.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                    
                    // User avatar overlay
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text((meal.user.displayName ?? meal.user.username).prefix(1))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(radius: 2)
                                )
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .cornerRadius(12)
                
                // Meal info
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.meal.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if let rating = meal.meal.rating {
                            HStack(spacing: 2) {
                                ForEach(0..<rating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Text(meal.user.displayName ?? meal.user.username)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Restaurant Feed View
struct RestaurantFeedView: View {
    let meals: [MealWithDetails]
    let startingMeal: MealWithDetails
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var supabase: SupabaseClient
    
    @State private var currentIndex = 0
    @State private var selectedMealId: IdentifiableString? = nil
    
    // Convert MealWithDetails to FeedMealItem format for consistency with existing FeedView
    private var feedItems: [FeedMealItem] {
        return meals.compactMap { mealWithDetails in
            // Convert MealWithDetails to FeedMealItem
            FeedMealItem(
                id: mealWithDetails.meal.id.uuidString,
                userId: mealWithDetails.user.id.uuidString,
                username: mealWithDetails.user.username,
                displayName: mealWithDetails.user.displayName,
                avatarUrl: nil, // No avatar URL in MealWithDetails
                mealTitle: mealWithDetails.meal.displayTitle,
                description: mealWithDetails.meal.description,
                mealType: mealWithDetails.meal.mealType.rawValue,
                location: mealWithDetails.restaurant?.name ?? "Unknown Location",
                tags: mealWithDetails.meal.tags,
                rating: mealWithDetails.meal.rating,
                eatenAt: mealWithDetails.meal.eatenAt,
                likesCount: mealWithDetails.reactions.filter { $0.reactionType == .like }.count,
                commentsCount: 0, // You'll need to get this from comments
                bookmarksCount: 0, // You'll need to get this from bookmarks
                photoUrl: mealWithDetails.primaryPhoto?.url,
                photoStoragePath: mealWithDetails.primaryPhoto?.storagePath,
                userHasLiked: false, // You'll need to populate this from reactions
                userHasBookmarked: false // You'll need to populate this
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if feedItems.isEmpty {
                    emptyStateView
                } else {
                    mainContentView(geometry: geometry)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedMealId) { wrapped in
            CommentsView(mealId: wrapped.id)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "fork.knife")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("No meals available")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top)
        }
    }
    
    private func mainContentView(geometry: GeometryProxy) -> some View {
        VStack {
            headerView
            feedScrollView(geometry: geometry)
        }
    }
    
    private var headerView: some View {
        HStack {
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private func feedScrollView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(feedItems.enumerated()), id: \.element.id) { index, meal in
                        feedItemView(meal: meal, geometry: geometry)
                            .frame(width: geometry.size.width, height: geometry.size.height - 100)
                            .id(index)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .onAppear {
                if let startIndex = feedItems.firstIndex(where: { $0.id == startingMeal.meal.id.uuidString }) {
                    proxy.scrollTo(startIndex)
                }
            }
        } 
    }
    
    private func feedItemView(meal: FeedMealItem, geometry: GeometryProxy) -> some View {
        FeedItemView(
            meal: meal,
            geometry: geometry,
            onProfileTap: {
                // Could navigate to user profile
            },
            onCommentTap: {
                handleComment(for: meal)
            },
            onLikeTap: { isLiked in
                Task {
                    try await handleLike(for: meal, isLiked: isLiked)
                }
            },
            onBookmarkTap: {
                Task {
                    try await mealService.addBookmark(mealId: meal.id)
                }
            }
        )
    }
    
    
    private func handleComment(for meal: FeedMealItem) {
        selectedMealId = IdentifiableString(id: meal.id)
    }
    
    private func handleLike(for meal: FeedMealItem, isLiked: Bool) async throws {
        try await mealService.toggleReaction(mealId: meal.id, reactionType: .like, isLiked: isLiked)
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


// MARK: - Restaurant Detail View
struct RestaurantDetailView: View {
    let restaurantWithDetails: RestaurantWithDetails
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var supabase: SupabaseClient
    
    @State private var allRestaurantMeals: [MealWithDetails] = []
    @State private var isLoadingMore = false
    @State private var selectedTimeFilter: TimeFilter = .all
    
    enum TimeFilter: String, CaseIterable {
        case all = "All Time"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case older = "Older"
        
        var dateRange: (start: Date?, end: Date?) {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return (nil, nil)
            case .thisWeek:
                let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)
                return (weekAgo, now)
            case .thisMonth:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)
                return (monthAgo, now)
            case .older:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)
                return (nil, monthAgo)
            }
        }
    }
    
    var filteredMeals: [MealWithDetails] {
        let allMeals = allRestaurantMeals.isEmpty ? restaurantWithDetails.meals : allRestaurantMeals
        
        guard selectedTimeFilter != .all else { return allMeals }
        
        let (start, end) = selectedTimeFilter.dateRange
        
        return allMeals.filter { meal in
            let mealDate = meal.meal.createdAt
            
            if let start = start, let end = end {
                return mealDate >= start && mealDate <= end
            } else if let end = end {
                return mealDate < end
            } else if let start = start {
                return mealDate >= start
            }
            return true
        }
    }
    
    var groupedMeals: [(date: Date, meals: [MealWithDetails])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredMeals) { meal in
            calendar.startOfDay(for: meal.meal.createdAt)
        }
        
        return grouped
            .map { (date: $0.key, meals: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Restaurant Header
                restaurantHeader
                
                // Stats Summary
                statsSection
                
                Divider()
                
                // Time Filter
                timeFilterSection
                
                // Meals grouped by date
                if groupedMeals.isEmpty {
                    emptyStateView
                } else {
                    mealsSection
                }
                
                if isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Restaurant Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAllRestaurantMeals()
        }
    }
    
    private var restaurantHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(restaurantWithDetails.restaurant.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let address = restaurantWithDetails.restaurant.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Restaurant image
                OptimizedRestaurantImage(
                    imageUrl: restaurantWithDetails.restaurant.imageUrl,
                    bucket: "restaurant-photos"
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
                .cornerRadius(12)
            }
            
            HStack(spacing: 16) {
                if let rating = restaurantWithDetails.restaurant.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        Text(String(format: "%.1f", rating))
                            .fontWeight(.medium)
                    }
                }
                
                if let priceRange = restaurantWithDetails.restaurant.priceRange {
                    Text(String(repeating: "$", count: priceRange))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                
                if let cuisine = restaurantWithDetails.restaurant.categories.first?.title {
                    Text(cuisine)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "Total Visits",
                value: "\(allRestaurantMeals.isEmpty ? restaurantWithDetails.meals.count : allRestaurantMeals.count)",
                icon: "fork.knife.circle.fill",
                color: .orange
            )
            
            StatCard(
                title: "Unique Dishes",
                value: "\(uniqueDishesCount)",
                icon: "list.bullet.rectangle",
                color: .blue
            )
            
            StatCard(
                title: "Avg Rating",
                value: String(format: "%.1f", averageRating),
                icon: "star.fill",
                color: .yellow
            )
        }
    }
    
    private var timeFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedTimeFilter == filter ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedTimeFilter == filter ? Color.orange : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(20)
                    }
                }
            }
        }
    }
    
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(groupedMeals, id: \.date) { group in
                VStack(alignment: .leading, spacing: 12) {
                    // Date header
                    Text(formatDateHeader(group.date))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    // Meals for this date
                    ForEach(group.meals, id: \.id) { meal in
                        MealCard(meal: meal)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No meals found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your time filter")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Properties
    private var uniqueDishesCount: Int {
        let allMeals = allRestaurantMeals.isEmpty ? restaurantWithDetails.meals : allRestaurantMeals
        let uniqueTitles = Set(allMeals.map { $0.meal.displayTitle.lowercased() })
        return uniqueTitles.count
    }
    
    private var averageRating: Double {
        let allMeals = allRestaurantMeals.isEmpty ? restaurantWithDetails.meals : allRestaurantMeals
        let ratingsSum = allMeals.compactMap { $0.meal.rating }.reduce(0, +)
        let ratingsCount = allMeals.compactMap { $0.meal.rating }.count
        return ratingsCount > 0 ? Double(ratingsSum) / Double(ratingsCount) : 0.0
    }
    
    // MARK: - Helper Methods
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day of week
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func loadAllRestaurantMeals() async {
        isLoadingMore = true
        
        // Fetch all meals for this restaurant from the API
        // This assumes you have a method in MealService to fetch by restaurant ID
        let restaurantId = restaurantWithDetails.restaurant.id.uuidString
        await mealService.fetchMealsForRestaurant(restaurantId: restaurantId)
        
        // Update allRestaurantMeals with the fetched data
        allRestaurantMeals = mealService.getMealsForRestaurant(restaurantId: restaurantId)
        
        isLoadingMore = false
    }
}

// MARK: - Meal Card Component
struct MealCard: View {
    let meal: MealWithDetails
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // User avatar
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(meal.user.displayName?.prefix(1).uppercased() ?? meal.user.username.prefix(1).uppercased())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(meal.user.displayName ?? meal.user.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(formatTime(meal.meal.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(meal.meal.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = meal.meal.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        
                        if description.count > 100 {
                            Button(action: {
                                isExpanded.toggle()
                            }) {
                                Text(isExpanded ? "Show less" : "Show more")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        if let rating = meal.meal.rating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        
                        if let cost = meal.meal.cost {
                            Text("$\(String(format: "%.2f", NSDecimalNumber(decimal: cost).doubleValue))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        if !meal.meal.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(meal.meal.tags.prefix(3), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            
            // Meal image if available
            if let photo = meal.photos.first {
                CachedAsyncImage(
                    storagePath: photo.storagePath,
                    bucket: "meal-photos"
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .tint(.orange)
                        )
                }
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}


