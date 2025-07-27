import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabase: SupabaseClient
    @StateObject private var profileService = ProfileService()
    
    @State private var displayName = ""
    @State private var bio = ""
    @State private var username = ""
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var showingRemoveAlert = false
    
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar Section
                    avatarSection
                    
                    // Profile Form
                    profileForm
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges || isSaving)
                }
            }
            .disabled(profileService.isLoading)
            .overlay {
                if profileService.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("Updating...")
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .onAppear {
            loadCurrentUserData()
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            Task {
                if let newPhoto {
                    await loadSelectedPhoto(newPhoto)
                }
            }
        }
        .onChange(of: [displayName, bio, username]) { _, _ in
            checkForChanges()
        }
        .onChange(of: avatarImage) { _, _ in
            checkForChanges()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Remove Avatar", isPresented: $showingRemoveAlert) {
            Button("Remove", role: .destructive) {
                Task {
                    await removeAvatar()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove your avatar?")
        }
    }
    
    private var avatarSection: some View {
        VStack(spacing: 16) {
            // Avatar Display
            Button(action: {
                showingActionSheet = true
            }) {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let avatarUrl = supabase.currentUser?.avatarUrl, !avatarUrl.isEmpty {
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                                .frame(width: 120, height: 120)
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.orange, lineWidth: 3)
                )
                .overlay(
                    // Camera icon overlay
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .offset(x: 40, y: 40),
                    alignment: .center
                )
            }
            .buttonStyle(PlainButtonStyle())
            .confirmationDialog("Change Avatar", isPresented: $showingActionSheet) {
                Button("Choose from Library") {
                    showingImagePicker = true
                }
                
                if supabase.currentUser?.avatarUrl != nil || avatarImage != nil {
                    Button("Remove Avatar", role: .destructive) {
                        showingRemoveAlert = true
                    }
                }
                
                Button("Cancel", role: .cancel) { }
            }
            
            Text("Tap to change your profile picture")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhoto, matching: .images)
    }
    
    private var profileForm: some View {
        VStack(spacing: 20) {
            // Display Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                TextField("Enter your display name", text: $displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                
                Text("This is how your name will appear to other users")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Username
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                TextField("Enter your username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .onChange(of: username) { _, newValue in
                        // Auto-format username as user types
                        let filtered = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        if filtered != newValue {
                            username = filtered
                        }
                    }
                
                Text("3-30 characters, letters, numbers, and underscores only")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Bio
            VStack(alignment: .leading, spacing: 8) {
                Text("Bio")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                TextField("Tell others about yourself", text: $bio, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                HStack {
                    Text("Optional")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(bio.count)/150")
                        .font(.caption)
                        .foregroundColor(bio.count > 150 ? .red : .gray)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentUserData() {
        if let user = supabase.currentUser {
            displayName = user.displayName ?? ""
            bio = user.bio ?? ""
            username = user.username
        }
    }
    
    private func checkForChanges() {
        guard let user = supabase.currentUser else {
            hasChanges = false
            return
        }
        
        let originalDisplayName = user.displayName ?? ""
        let originalBio = user.bio ?? ""
        let originalUsername = user.username
        
        hasChanges = displayName != originalDisplayName ||
                    bio != originalBio ||
                    username != originalUsername ||
                    avatarImage != nil
    }
    
    private func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                avatarImage = image
            }
        } catch {
            errorMessage = "Failed to load selected image"
            showingError = true
        }
    }
    
    private func saveProfile() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        
        do {
            // Upload new avatar if selected
            if let avatarImage {
                _ = try await profileService.uploadAvatar(image: avatarImage)
            }
            
            // Update profile information
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate bio length
            if trimmedBio.count > 150 {
                throw NSError(domain: "ValidationError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Bio must be 150 characters or less"])
            }
            
            try await profileService.updateProfile(
                displayName: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                username: trimmedUsername.isEmpty ? nil : trimmedUsername
            )
            
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func removeAvatar() async {
        do {
            try await profileService.removeAvatar()
            avatarImage = nil
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(SupabaseClient.shared)
}