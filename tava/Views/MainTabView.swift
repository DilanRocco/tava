import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showAddMeal = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content based on selected tab
            TabView(selection: $selectedTab) {
                FeedView()
                    .tag(0)
                DiscoveryView()
                    .tag(1)
                MapFeedView()
                    .tag(2)
                
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab, showAddMeal: $showAddMeal)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $showAddMeal) {
            AddMealView()
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showAddMeal: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Home Tab
            TabBarButton(
                icon: "house",
                selectedIcon: "house.fill",
                title: "Discover",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            .frame(maxWidth: .infinity)
            
            // Search Tab
            TabBarButton(
                icon: "magnifyingglass",
                selectedIcon: "magnifyingglass",
                title: "Search",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            .frame(maxWidth: .infinity)

            TabBarButton(
                icon: "magnifyingglass",
                selectedIcon: "magnifyingglass",
                title: "Search",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            .frame(maxWidth: .infinity)
            

            
            // Profile Tab
            TabBarButton(
                icon: "person",
                selectedIcon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
            .frame(maxWidth: .infinity)

                        // Plus Tab (Floating)
            Button(action: {
                showAddMeal = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -20) // Extends above the tab bar
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24) // Extends into safe area
        .background(
            Color.white
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .black : .gray)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .black : .gray)
            }
        }
    }
}


struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

