//
//  tavaApp.swift
//  tava
//
//  Created by dilan on 7/17/25.
//

import SwiftUI

@main
struct tavaApp: App {
    @StateObject private var supabase = SupabaseClient.shared
    @StateObject private var draftMealService = DraftMealService()
    @StateObject private var mealService = MealService()
    @StateObject private var googlePlacesService = GooglePlacesService()
    @StateObject private var locationService = LocationService()


    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabase)
                .environmentObject(mealService)
                .environmentObject(draftMealService)
                .environmentObject(googlePlacesService)
                .environmentObject(locationService)

        }
    }
}
