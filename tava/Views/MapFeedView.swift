import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

// MARK: - Data Structures for Clustering
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

struct MapFeedView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    
    @State private var showFeed = false
    @State private var selectedMeal: MealWithDetails?
    @State private var selectedRestaurant: RestaurantWithDetails?
    @State private var showFilters = false
    @State private var showProfile = false
    @State private var showMealDetail = false
    @State private var showRestaurantDetail = false
    @State private var friendsFilter: FriendsFilterOption = .all
    @State private var mapClusters: [MapCluster] = []
    @State private var currentZoomLevel: Double = 15.0
    
    enum FriendsFilterOption: String, CaseIterable {
        case all = "All"
        case friends = "Friends"
        case nonFriends = "Discover"
    }
    
    var restaurantMeals: [MealWithDetails] {
        let allMeals = mealService.nearbyMeals.filter { $0.restaurant != nil }
        
        print("🗺️ MapFeedView - Total nearby meals: \(mealService.nearbyMeals.count)")
        print("🗺️ MapFeedView - Meals with restaurants: \(allMeals.count)")
        
        for meal in mealService.nearbyMeals {
            if let restaurant = meal.restaurant {
                print("✅ Meal '\(meal.meal.displayTitle)' at \(restaurant.name) - Location: \(restaurant.location?.latitude ?? 0), \(restaurant.location?.longitude ?? 0)")
            } else {
                print("❌ Meal '\(meal.meal.displayTitle)' has no restaurant")
            }
        }
        
        let filtered = switch friendsFilter {
        case .all:
            allMeals
        case .friends:
            allMeals.filter { $0.user.id != supabase.currentUser?.id }
        case .nonFriends:
            allMeals.filter { $0.user.id == supabase.currentUser?.id }
        }
        
        print("🗺️ MapFeedView - After filter (\(friendsFilter.rawValue)): \(filtered.count) meals")
        return filtered
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Citizen-Style Mapbox Map with Clustering
                CitizenStyleMapView(
                    meals: restaurantMeals,
                    userLocation: locationService.location,
                    clusters: $mapClusters,
                    currentZoom: $currentZoomLevel,
                    onMealTap: { meal in
                        selectedMeal = meal
                        showMealDetail = true
                    },
                    onClusterTap: { cluster in
                        // Handle cluster tap - could zoom to cluster bounds
                    }
                )
                .ignoresSafeArea()
                
                // Modern UI Overlay with Profile and Filter
                ModernMapOverlay(
                    mealCount: restaurantMeals.count,
                    showFeed: $showFeed,
                    showProfile: $showProfile,
                    showFilters: $showFilters,
                    friendsFilter: $friendsFilter
                )
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFeed) {
                MapFeedListView(meals: restaurantMeals)
            }
            .sheet(isPresented: $showMealDetail) {
                if let selectedMeal = selectedMeal {
                    MealDetailModal(
                        meal: selectedMeal,
                        onRestaurantTap: {
                            showMealDetail = false
                            selectedRestaurant = RestaurantWithDetails(
                                restaurant: selectedMeal.restaurant!,
                                meals: restaurantMeals.filter { $0.restaurant?.id == selectedMeal.restaurant?.id }
                            )
                            showRestaurantDetail = true
                        }
                    )
                }
            }
            .sheet(isPresented: $showRestaurantDetail) {
                if let selectedRestaurant = selectedRestaurant {
                    RestaurantDetailView(restaurantWithDetails: selectedRestaurant)
                }
            }
//            .sheet(item: $selectedMeal) { meal in
//                MealDetailView(meal: meal)
//                    .environmentObject(mealService)
//                    .environmentObject(supabase)
//            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(supabase)
                    .environmentObject(locationService)
                    .environmentObject(mealService)
                    .environmentObject(googlePlacesService)
            }
            .task {
                await locationService.requestLocationPermission()
                
                // Fetch nearby meals for the map
                if let userLocation = locationService.location {
                    print("🌍 MapFeedView - Fetching nearby meals from user location")
                    await mealService.fetchNearbyMeals(location: userLocation, radius: 10000) // 10km radius
                } else {
                    print("❌ MapFeedView - No user location available")
                }
            }
            .onChange(of: restaurantMeals.count) { _ in
                // Update clusters when meals change
                mapClusters = generateClusters(from: restaurantMeals, zoomLevel: currentZoomLevel)
            }
            .onChange(of: currentZoomLevel) { _ in
                // Update clusters when zoom changes
                mapClusters = generateClusters(from: restaurantMeals, zoomLevel: currentZoomLevel)
            }
            .onChange(of: locationService.location) { newLocation in
                // Fetch meals when location changes
                if let location = newLocation {
                    print("📍 MapFeedView - Location changed, refetching meals")
                    Task {
                        await mealService.fetchNearbyMeals(location: location, radius: 10000)
                    }
                }
            }
        }
    }
    
    // MARK: - Clustering Logic
    private func generateClusters(from meals: [MealWithDetails], zoomLevel: Double) -> [MapCluster] {
        print("🎯 generateClusters - Input: \(meals.count) meals, zoom: \(zoomLevel)")
        
        guard !meals.isEmpty else { 
            print("❌ generateClusters - No meals to cluster")
            return [] 
        }
        
        // Group meals by restaurant first
        let restaurantGroups = Dictionary(grouping: meals) { meal in
            meal.restaurant?.id ?? meal.id
        }
        
        print("🏪 generateClusters - Grouped into \(restaurantGroups.count) restaurant groups")
        
        var clusters: [MapCluster] = []
        
        // Convert restaurant groups to clusters
        for (restaurantId, restaurantMeals) in restaurantGroups {
            guard let firstMeal = restaurantMeals.first,
                  let restaurant = firstMeal.restaurant,
                  let location = restaurant.location else { 
                print("⚠️ Skipping group \(restaurantId) - missing restaurant or location")
                continue 
            }
            
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
            
            print("📍 Created cluster for \(restaurant.name) at (\(location.latitude), \(location.longitude)) with \(restaurantMeals.count) meals")
        }
        
        print("🎯 generateClusters - Created \(clusters.count) base clusters")
        
        // For high zoom levels, show individual clusters
        // For low zoom levels, merge nearby clusters
        let finalClusters: [MapCluster]
        if zoomLevel < 12 {
            finalClusters = mergeClusters(clusters, threshold: 0.01) // ~1km at equator
            print("🔀 Merged to \(finalClusters.count) clusters (zoom < 12)")
        } else if zoomLevel < 15 {
            finalClusters = mergeClusters(clusters, threshold: 0.005) // ~500m at equator
            print("🔀 Merged to \(finalClusters.count) clusters (zoom < 15)")
        } else {
            finalClusters = clusters // Show all individual restaurant clusters
            print("📌 Using all \(finalClusters.count) individual clusters (zoom >= 15)")
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
    let mealCount: Int
    @Binding var showFeed: Bool
    @Binding var showProfile: Bool
    @Binding var showFilters: Bool
    @Binding var friendsFilter: MapFeedView.FriendsFilterOption
    
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
                RecenterButton()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Friends Filter Overlay
            if showFilters {
                friendsFilterView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
            
            // Stunning bottom info panel
            if mealCount > 0 {
                ModernBottomPanel(
                    mealCount: mealCount,
                    showFeed: $showFeed,
                    filterText: friendsFilter.rawValue
                )
            }
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
                ForEach(MapFeedView.FriendsFilterOption.allCases, id: \.self) { option in
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

// MARK: - Extensions
extension MapFeedView.FriendsFilterOption {
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
    var body: some View {
        Button(action: {
            // Recenter functionality can be added later
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
        }
        .buttonStyle(ModernGlowButtonStyle())
    }
}

// MARK: - Modern Bottom Panel
struct ModernBottomPanel: View {
    let mealCount: Int
    @Binding var showFeed: Bool
    let filterText: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern handle bar with glow
            HandleBar()
            
            // Enhanced content with modern styling
            BottomPanelContent(
                mealCount: mealCount,
                showFeed: $showFeed,
                filterText: filterText
            )
        }
        .background(ModernGlassBackground())
        .clipShape(
            .rect(
                topLeadingRadius: 24,
                topTrailingRadius: 24
            )
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -8)
    }
}

// MARK: - Handle Bar
struct HandleBar: View {
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 40, height: 5)
            .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 14)
    }
}

// MARK: - Bottom Panel Content
struct BottomPanelContent: View {
    let mealCount: Int
    @Binding var showFeed: Bool
    let filterText: String
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Animated count with glow
                    Text("\(mealCount)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // Modern pulse indicator
                    PulseIndicator()
                }
                
                Text("meals nearby")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(0.5)
            }
            
            Spacer()
            
            // Enhanced explore button
            ExploreButton(showFeed: $showFeed, mealCount: mealCount)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - Pulse Indicator
struct PulseIndicator: View {
    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 8, height: 8)
            .shadow(color: .orange.opacity(0.6), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Explore Button
struct ExploreButton: View {
    @Binding var showFeed: Bool
    let mealCount: Int
    
    var body: some View {
        Button("Explore") {
            showFeed = true
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundColor(.black)
        .frame(width: 90, height: 42)
        .background(
            ZStack {
                // Glow effect
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .white.opacity(0.4), radius: 8, x: 0, y: 4)
                
                // Main button
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .scaleEffect(1.0)
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

// MARK: - Glass Background
struct ModernGlassBackground: View {
    var body: some View {
        ZStack {
            // Dark glass effect
            Rectangle()
                .fill(Material.ultraThinMaterial)
                .opacity(0.85)
            
            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Citizen-Style Map Implementation
struct CitizenStyleMapView: UIViewRepresentable {
    let meals: [MealWithDetails]
    let userLocation: CLLocation?
    @Binding var clusters: [MapCluster]
    @Binding var currentZoom: Double
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
        
        print("✅ Mapbox API Key found: \(String(apiKey.prefix(10)))...")
        
        // Use user location or default to San Francisco
        let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let initialLocation = userLocation?.coordinate ?? defaultLocation
        
        print("📍 Using location: \(initialLocation.latitude), \(initialLocation.longitude)")
        
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
        
        print("🗺️ MapView created with Citizen-style configuration")
        
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
        
        print("🎮 All gestures enabled for smooth interaction")
        
        // Add tap gesture for annotations
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Note: Zoom-based clustering updates will happen via SwiftUI state changes
        
        return mapView
    }
    
    // MARK: - Load Custom Citizen Style JSON (Async)
    private func loadCitizenStyleJSON(to mapView: MapView) async {
        // Your custom Citizen style JSON
        do {
        guard let path = Bundle.main.path(forResource: "CitizenMapStyle", ofType: "json") else {
                print("❌ CitizenMapStyle.json not found in bundle")
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
                case .success(let style):
                    print("✅ Citizen style loaded: \(style)")
                    // Set camera...
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
            print("📍 Location puck enabled")
        }
        
        // Add clustering annotations
        updateMapAnnotations(mapView)
        
        // Note: Camera is only set once in makeUIView, allowing free scrolling
    }
    
    private func updateMapAnnotations(_ mapView: MapView) {
        print("🗺️ updateMapAnnotations - Updating with \(clusters.count) clusters")
        
        // Remove existing point annotations
        let pointAnnotationManager = mapView.annotations.makePointAnnotationManager()
        pointAnnotationManager.annotations = []
        
        // Create new annotations for clusters
        var annotations: [PointAnnotation] = []
        for cluster in clusters {
            let annotation = createClusterAnnotation(for: cluster)
            annotations.append(annotation)
            
            if let restaurant = cluster.restaurant {
                print("📌 Adding annotation for \(restaurant.name) at (\(cluster.coordinate.latitude), \(cluster.coordinate.longitude))")
            }
        }
        
        // Add all annotations at once
        pointAnnotationManager.annotations = annotations
        print("✅ Added \(annotations.count) annotations to map")
    }
    
    private func createClusterAnnotation(for cluster: MapCluster) -> PointAnnotation {
        var annotation = PointAnnotation(coordinate: cluster.coordinate)
        
        // Modern clustering design with custom styling
        if cluster.isCluster {
            // Multiple meals - modern cluster pin with count
            annotation.textField = "\\(cluster.count)"
            annotation.textSize = 14
            annotation.textColor = StyleColor(.white)
            annotation.iconColor = StyleColor(.systemOrange)
            annotation.iconSize = 1.2
        } else {
            // Single restaurant meal - sleek pin with restaurant initial
            if let restaurant = cluster.restaurant {
                let initial = String(restaurant.name.prefix(1)).uppercased()
                annotation.textField = initial
                annotation.textSize = 12
                annotation.textColor = StyleColor(.white)
                annotation.iconColor = StyleColor(.systemBlue)
                annotation.iconSize = 1.0
            }
        }
        
        // Enhanced visual styling
        annotation.iconOpacity = 0.9
        annotation.textOpacity = 1.0
        
        return annotation
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject {
        var parent: CitizenStyleMapView
        
        init(_ parent: CitizenStyleMapView) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            let mapView = gesture.view as! MapView
            let point = gesture.location(in: mapView)
            
            // Find the closest cluster to the tap point
            var closestCluster: MapCluster?
            var closestDistance: Double = Double.infinity
            
            for cluster in parent.clusters {
                let clusterPoint = mapView.mapboxMap.point(for: cluster.coordinate)
                let distance = sqrt(pow(point.x - clusterPoint.x, 2) + pow(point.y - clusterPoint.y, 2))
                
                if distance < 30 && distance < closestDistance {
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
                                Text("$\\(meal.meal.cost!, specifier: \"%.2f\")")
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

// MARK: - Restaurant Detail View
struct RestaurantDetailView: View {
    let restaurantWithDetails: RestaurantWithDetails
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Restaurant Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(restaurantWithDetails.restaurant.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if let address = restaurantWithDetails.restaurant.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            if let rating = restaurantWithDetails.restaurant.rating {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.orange)
                                    Text(String(format: "%.1f", rating))
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if let priceRange = restaurantWithDetails.restaurant.priceRange {
                                Text(String(repeating: "$", count: priceRange))
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Meals at this restaurant
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meals (\\(restaurantWithDetails.meals.count))")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        ForEach(restaurantWithDetails.meals, id: \.id) { meal in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(meal.meal.displayTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let description = meal.meal.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                HStack {
                                    Text("By \\(meal.user.display_name ?? meal.user.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let rating = meal.meal.rating {
                                        HStack {
                                            ForEach(1...5, id: \.self) { star in
                                                Image(systemName: star <= rating ? "star.fill" : "star")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 10))
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Restaurant")
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
