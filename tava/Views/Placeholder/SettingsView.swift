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

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabase: SupabaseClient
    @State private var displayName = ""
    @State private var bio = ""
    @State private var username = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    TextField("Display Name", text: $displayName)
                    TextField("Username", text: $username)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Avatar") {
                    HStack {
                        AsyncImage(url: URL(string: supabase.currentUser?.avatarUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        
                        Spacer()
                        
                        Button("Change Photo") {
                            // TODO: Implement photo picker
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Implement save functionality
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let user = supabase.currentUser {
                displayName = user.displayName ?? ""
                bio = user.bio ?? ""
                username = user.username
            }
        }
    }
} 