import SwiftUI
import PhotosUI

// MARK: - Main Add Meal View
struct AddMealView: View {
    @StateObject private var draftService = DraftMealService()
    @State private var currentFlow: MealFlow = .initial
    @State private var currentDraft: MealWithPhotos?
    @State private var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    enum MealFlow {
        case initial           // Shows camera/library + collaborative meals
        case courseSelection   // After taking photo, select course
        case nextAction       // Take another photo, continue later, or finalize
        case mealDetails      // Final details for publishing
    }
    
    var body: some View {
        NavigationView {
            Group {
                switch currentFlow {
                case .initial:
                    InitialView(
                        draftService: draftService,
                        onTakePhoto: { image in
                            capturedImage = image
                            currentFlow = .courseSelection
                        },
                        onSelectDraft: { draft in
                            currentDraft = draft
                            currentFlow = .nextAction
                        }
                    )
                    
                case .courseSelection:
                    CourseSelectionView(
                        capturedImage: capturedImage!,
                        onCourseSelected: { course in
                            Task {
                                await handlePhotoWithCourse(course)
                            }
                        }
                    )
                    
                case .nextAction:
                    NextActionView(
                        currentDraft: currentDraft!,
                        onTakeAnother: {
                            currentFlow = .initial
                        },
                        onContinueLater: {
                            draftService.saveDraftMealsToLocal(draftService.draftMeals)
                            dismiss()
                        },
                        onFinalize: {
                            currentFlow = .mealDetails
                        }
                    )
                    
                case .mealDetails:
                    MealDetailsView(
                        currentDraft: currentDraft!,
                        onPublish: { title, description, privacy in
                            Task {
                                await publishMeal(title: title, description: description, privacy: privacy)
                            }
                        }
                    )
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func handlePhotoWithCourse(_ course: Course?) async {
        do {
            if let draft = currentDraft {
                // Add to existing draft
                if let imageData = capturedImage?.jpegData(compressionQuality: 0.8) {
                    let _ = try await draftService.addPhoto(
                        to: draft.meal.id,
                        imageData: imageData,
                        course: course
                    )
                    // **ADD THIS**: Refresh the current draft with updated data
                    currentDraft = draftService.draftMeals.first { $0.meal.id == draft.meal.id }
                }
            } else {
                // Create new draft
                let newDraft = try await draftService.createDraftMeal()
                if let imageData = capturedImage?.jpegData(compressionQuality: 0.8) {
                    let _ = try await draftService.addPhoto(
                        to: newDraft.meal.id,
                        imageData: imageData,
                        course: course
                    )
                    // **ADD THIS**: Refresh the current draft with updated data
                    currentDraft = draftService.draftMeals.first { $0.meal.id == newDraft.meal.id }
                }
            }
            
            // Move to next action
            currentFlow = .nextAction
            capturedImage = nil
            
        } catch {
            print("Error adding photo: \(error)")
        }
    }
    
    private func publishMeal(title: String?, description: String?, privacy: MealPrivacy) async {
        guard let draft = currentDraft else { return }
        
        do {
            try await draftService.publishEntireMeal(
                mealId: draft.meal.id,
                title: title,
                description: description,
                privacy: privacy
            )
            // dismiss()
        } catch {
            print("Error publishing meal: \(error)")
        }
    }
}

// MARK: - Initial View (Camera + Collaborative Meals)
struct InitialView: View {
    let draftService: DraftMealService
    let onTakePhoto: (UIImage) -> Void
    let onSelectDraft: (MealWithPhotos) -> Void
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isEditingDrafts = false
    @State private var deletingMealIds: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 30) {
            // Camera Section
            VStack(spacing: 20) {
                Text("📸")
                    .font(.system(size: 60))
                Text("Capture Your Meal")
                    .font(.title2)
                    .fontWeight(.semibold)
                VStack(spacing: 12) {
                    Button("Take Photo") {
                        showingCamera = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        Text("Choose from Library")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            
            // Collaborative Meals Section
            if !draftService.draftMeals.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Continue Previous Meals")
                            .font(.headline)
                        Spacer()
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isEditingDrafts.toggle()
                                if !isEditingDrafts {
                                    deletingMealIds.removeAll()
                                }
                            }
                        }) {
                            Text(isEditingDrafts ? "Done" : "Edit")
                                .font(.subheadline)
                                .foregroundColor(isEditingDrafts ? .red : .blue)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(draftService.draftMeals) { draft in
                                ZStack(alignment: .topTrailing) {
                                    DraftMealThumbnail(draft: draft) {
                                        if !isEditingDrafts {
                                            onSelectDraft(draft)
                                        }
                                    }
                                    .opacity(isEditingDrafts ? 0.5 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isEditingDrafts)
                                    
                                    // Delete overlay - positioned properly inside bounds
                                    if isEditingDrafts {
                                        Button(action: {
                                            deleteMeal(draft)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.red)
                                                .background(
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 20, height: 20)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 8, y: -8) // Reduced offset to keep it visible
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .scaleEffect(deletingMealIds.contains(draft.meal.id) ? 0.8 : 1.0)
                                .opacity(deletingMealIds.contains(draft.meal.id) ? 0.0 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: deletingMealIds.contains(draft.meal.id))
                                .padding(.top, 8) // Add padding to accommodate the button
                                .padding(.trailing, 8) // Add trailing padding for the button
                            }
                        }
                        .padding(.horizontal, 12) // Increased horizontal padding
                        .padding(.vertical, 4) // Add vertical padding
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingCamera) {
            CameraView { imageData in
                if let image = UIImage(data: imageData) {
                    onTakePhoto(image)
                }
            }
        }
        .onChange(of: selectedPhoto) { photo in
            if let photo = photo {
                Task {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onTakePhoto(image)
                    }
                }
            }
        }
    }
    
    private func deleteMeal(_ draft: MealWithPhotos) {
        withAnimation(.easeInOut(duration: 0.3)) {
            deletingMealIds.insert(draft.meal.id)
        }
        
        // Delay the actual deletion to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task {
                do {
                    try await draftService.deleteDraftMeal(mealId: draft.meal.id)
                    deletingMealIds.remove(draft.meal.id)
                } catch {
                    // Handle error and reset state
                    deletingMealIds.remove(draft.meal.id)
                }
            }
        }
    }
}

// MARK: - Course Selection View
struct CourseSelectionView: View {
    let capturedImage: UIImage
    let onCourseSelected: (Course?) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Photo Preview
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                .padding(.horizontal)
            
            // Course Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("What course is this?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(Course.allCases.prefix(8), id: \.self) { course in
                        Button(action: {
                            onCourseSelected(course)
                        }) {
                            VStack(spacing: 8) {
                                Text(course.emoji)
                                    .font(.title)
                                Text(course.displayName)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Skip button
                Button("Skip for now") {
                    onCourseSelected(nil)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Next Action View
struct NextActionView: View {
    let currentDraft: MealWithPhotos
    let onTakeAnother: () -> Void
    let onContinueLater: () -> Void
    let onFinalize: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Success indicator
            VStack(spacing: 16) {
                Text("✅")
                    .font(.system(size: 60))
                
                Text("Photo Added!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("You now have \(currentDraft.photos.count) photo\(currentDraft.photos.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
            }
            
            // Photo Grid Preview
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(currentDraft.photos.prefix(6)) { photo in
                    if let localImageData = loadLocalImageData(fileName: photo.url),
                    let uiImage = UIImage(data: localImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 80)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 80)
                    }
                }

                
                if currentDraft.photos.count > 6 {
                    Text("+\(currentDraft.photos.count - 6)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // Action Buttons
            VStack(spacing: 16) {
                Button("Take Another Photo") {
                    onTakeAnother()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Continue Later") {
                    onContinueLater()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Finalize & Publish") {
                    onFinalize()
                }
                .buttonStyle(AccentButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    private func loadLocalImageData(fileName: String) -> Data? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        return try? Data(contentsOf: filePath)
}
}

// MARK: - Meal Details View (Publishing)
struct MealDetailsView: View {
    let currentDraft: MealWithPhotos
    let onPublish: (String?, String?, MealPrivacy) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var privacy: MealPrivacy = .public
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Photos Preview
                Text("Ready to share \(currentDraft.photos.count) photos")
                    .font(.headline)
                
                // Form Fields
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("What did you eat?", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Tell us about it...", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        // Picker("Privacy", selection: $privacy) {
                        //     ForEach(MealPrivacy.allCases, id: \.self) { privacy in
                        //         Text(privacy.displayName).tag(privacy)
                        //     }
                        // }
                        // .pickerStyle(.segmented)
                    }
                }
                
                // Publish Button
                Button("Publish Meal") {
                    onPublish(
                        title.isEmpty ? nil : title,
                        description.isEmpty ? nil : description,
                        privacy
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views
struct DraftMealThumbnail: View {
    let draft: MealWithPhotos
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if let primaryPhoto = draft.primaryPhoto {
                    if let localImageData = loadLocalImageData(fileName: primaryPhoto.url),
                       let uiImage = UIImage(data: localImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 80, height: 80)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
                
                Text("\(draft.photos.count) photos")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    // **ADD THIS helper method**
    private func loadLocalImageData(fileName: String) -> Data? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        return try? Data(contentsOf: filePath)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}