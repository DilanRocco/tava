import SwiftUI
import MapboxMaps
import CoreLocation
import Combine

struct MapFeedView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var supabase: SupabaseClient
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    
    @State private var showFeed = false
    @State private var selectedMeal: MealWithDetails?
    @State private var showFilters = false
    @State private var showProfile = false
    @State private var friendsFilter: FriendsFilterOption = .all
    
    enum FriendsFilterOption: String, CaseIterable {
        case all = "All"
        case friends = "Friends"
        case nonFriends = "Discover"
    }
    
    var filteredMeals: [MealWithDetails] {
        switch friendsFilter {
        case .all:
            return mealService.nearbyMeals
        case .friends:
            return mealService.nearbyMeals.filter { $0.user.id != supabase.currentUser?.id }
        case .nonFriends:
            return mealService.nearbyMeals.filter { $0.user.id == supabase.currentUser?.id }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Citizen-Style Mapbox Map
                CitizenStyleMapView(
                    meals: filteredMeals,
                    userLocation: locationService.location
                )
                .ignoresSafeArea()
                
                // Modern UI Overlay with Profile and Filter
                ModernMapOverlay(
                    mealCount: filteredMeals.count,
                    showFeed: $showFeed,
                    showProfile: $showProfile,
                    showFilters: $showFilters,
                    friendsFilter: $friendsFilter
                )
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFeed) {
                MapFeedListView(meals: filteredMeals)
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
            }
        }
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
        
        // Note: Camera is only set once in makeUIView, allowing free scrolling
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
