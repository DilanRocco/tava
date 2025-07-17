import SwiftUI

struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFriendsOnly = false
    @State private var showTodayOnly = false
    @State private var showHomemadeOnly = false
    @State private var showRestaurantOnly = false
    @State private var selectedMealTypes: Set<MealType> = Set(MealType.allCases)
    
    var body: some View {
        NavigationView {
            List {
                Section("Feed Filters") {
                    Toggle("Friends Only", isOn: $showFriendsOnly)
                    Toggle("Today Only", isOn: $showTodayOnly)
                }
                
                Section("Meal Types") {
                    Toggle("Homemade Meals", isOn: $showHomemadeOnly)
                    Toggle("Restaurant Meals", isOn: $showRestaurantOnly)
                }
                
                Section("Distance") {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("5 km")
                            .foregroundColor(.gray)
                    }
                    // TODO: Add distance slider
                }
                
                Section {
                    Button("Reset Filters") {
                        resetFilters()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func resetFilters() {
        showFriendsOnly = false
        showTodayOnly = false
        showHomemadeOnly = false
        showRestaurantOnly = false
        selectedMealTypes = Set(MealType.allCases)
    }
    
    private func applyFilters() {
        // TODO: Implement filter application logic
        // This would update the meal service with the selected filters
    }
} 