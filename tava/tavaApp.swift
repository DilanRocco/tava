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


    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabase)
                .environmentObject(LocationService())
                .environmentObject(MealService())
        }
    }
}
