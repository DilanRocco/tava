import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabase: SupabaseClient
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    NavigationLink("Edit Profile") {
                        EditProfileView()
                    }
                    
                    NavigationLink("Privacy Settings") {
                        Text("Privacy Settings - Coming Soon")
                    }
                    
                    NavigationLink("Notifications") {
                        Text("Notification Settings - Coming Soon")
                    }
                }
                
                Section("Preferences") {
                    NavigationLink("Location Settings") {
                        Text("Location Settings - Coming Soon")
                    }
                    
                    NavigationLink("Display Options") {
                        Text("Display Options - Coming Soon")
                    }
                }
                
                Section("Support") {
                    NavigationLink("Help & FAQ") {
                        Text("Help & FAQ - Coming Soon")
                    }
                    
                    NavigationLink("Contact Support") {
                        Text("Contact Support - Coming Soon")
                    }
                    
                    NavigationLink("About") {
                        Text("About Tava - Coming Soon")
                    }
                }
                
                Section {
                    Button("Sign Out") {
                        showingSignOutAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await supabase.signOut()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

 