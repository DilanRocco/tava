import SwiftUI

struct MainTabView: View {
    @StateObject private var supabase = SupabaseClient.shared
    @StateObject private var locationService = LocationService()
    @StateObject private var mealService = MealService()
    @StateObject private var googlePlacesService = GooglePlacesService()
    @State private var selectedTab: Int = 0
    @State private var showAddMeal: Bool = false
    
    var body: some View {
        ZStack {
            // Main content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    MapFeedView()
                        .environmentObject(supabase)
                        .environmentObject(locationService)
                        .environmentObject(mealService)
                        .environmentObject(googlePlacesService)
                case 1:
                    ProfileView()
                        .environmentObject(supabase)
                        .environmentObject(locationService)
                        .environmentObject(mealService)
                        .environmentObject(googlePlacesService)
                default:
                    MapFeedView()
                        .environmentObject(supabase)
                        .environmentObject(locationService)
                        .environmentObject(mealService)
                        .environmentObject(googlePlacesService)
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Custom Tab Bar with Floating Plus Button
            ZStack {
                // Black Tab Bar Background (covers full bottom area)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 83)
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 34) // Safe area
                }
                
                // Tab Bar Content
                VStack(spacing: 0) {
                    
                    HStack(spacing: 0) {
                        // Discover Tab
                        TabButton(
                            icon: "map.fill",
                            title: "Discover",
                            isSelected: selectedTab == 0
                        ) {
                            selectedTab = 0
                        }
                        
                        Spacer()
                        
                        // Profile Tab  
                        TabButton(
                            icon: "person.fill",
                            title: "Profile",
                            isSelected: selectedTab == 1
                        ) {
                            selectedTab = 1
                        }
                        
                        // Space for floating button
                         HStack {
                        Spacer()
                        
                        FloatingPlusButton {
                            showAddMeal = true
                        }
                        .offset(y: -28)
                        
                    
                    }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 83)
                    
                    // Safe area padding
                    Spacer()
                        .frame(height: 34)
                }
                
                
            
                   
                    
                    Spacer()
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddMeal) {
            AddMealView()
                .environmentObject(supabase)
                .environmentObject(locationService)
                .environmentObject(mealService)
                .environmentObject(googlePlacesService)
        }
        .onAppear {
            locationService.requestLocationPermission()
        }
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .orange : .gray)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .orange : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Floating Plus Button
struct FloatingPlusButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(0.6),
                                Color.orange.opacity(0.3),
                                Color.orange.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 25,
                            endRadius: 45
                        )
                    )
                    .frame(width: 90, height: 90)
                
                // Main circular button
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
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: .orange.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                
                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .buttonStyle(PlainButtonStyle())
    }
} 