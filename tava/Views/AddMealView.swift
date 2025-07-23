import SwiftUI
import PhotosUI

// MARK: - Main Add Meal View
struct AddMealView: View {
    
    @State private var currentFlow: MealFlow = .initial
    @State private var currentDraft: MealWithPhotos?
    @State private var capturedImage: UIImage?

    @State private var multipleImages: [UIImage] = []
    @State private var currentImageIndex = 0
    @EnvironmentObject private var draftService: DraftMealService
    @Environment(\.dismiss) private var dismiss
    let onDismiss: (() -> Void)?

init(startingImages: [UIImage], onDismiss: (() -> Void)? = nil, stage: MealFlow? = .initial) {
    self.onDismiss = onDismiss
    print("startingImages: \(startingImages)")
    
    if startingImages.count == 0 {
        // Initialize with default values
        _currentFlow = State(initialValue: .initial)
        _capturedImage = State(initialValue: nil)
        _multipleImages = State(initialValue: [])
        _currentImageIndex = State(initialValue: 0)
        return
    }
    
    if startingImages.count == 1 {
        print("startingImages: \(startingImages)")
        print("Setting up single image flow")
        // Use the State wrapper initializer
        _capturedImage = State(initialValue: startingImages[0])
        _currentFlow = State(initialValue: .courseSelection)
        _multipleImages = State(initialValue: [])
        _currentImageIndex = State(initialValue: 0)
    } else {
        // Use the State wrapper initializer for multiple images
        _multipleImages = State(initialValue: startingImages)
        _currentImageIndex = State(initialValue: 0)
        _currentFlow = State(initialValue: .multiImageCourseSelection(images: startingImages, currentIndex: 0))
        _capturedImage = State(initialValue: nil)
    }
}

    
    
    enum MealFlow {
        case initial           // Shows camera/library + collaborative meals
        case courseSelection   // After taking photo, select course
        case multiImageCourseSelection(images: [UIImage], currentIndex: Int) // For multiple images
        case nextAction       // Take another photo, continue later, or finalize
        case mealDetails      // Final details for publishing
        case showCamera // <-- Add this
    }
        
    var body: some View {
        if currentFlow == .showCamera {
            CameraView(
                onImageCaptured: { imageData in
                    if let image = UIImage(data: imageData) {
                        capturedImage = image
                        currentFlow = .courseSelection
                    }
                },
                onMultipleImagesCaptured: { images in
                    multipleImages = images
                    currentImageIndex = 0
                    currentFlow = .multiImageCourseSelection(images: images, currentIndex: 0)
                }
            )
        } else {
            NavigationView {
                Group {
                    switch currentFlow {
                    case .initial:
                        InitialView(
                            draftService: draftService,
                            onTakePhoto: { image in
                                print("onTakePhoto")
                                capturedImage = image
                                currentFlow = .courseSelection
                            },
                            onSelectDraft: { draft in
                                currentDraft = draft
                                currentFlow = .nextAction
                            },
                            onMultiplePhotos: { images in // Add this closure
                                multipleImages = images
                                currentImageIndex = 0
                                currentFlow = .multiImageCourseSelection(images: images, currentIndex: 0)
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
                                currentFlow = .showCamera
                            },
                            onContinueLater: {
                                draftService.saveDraftMealsToLocal(draftService.draftMeals)
                                dismiss()
                            },
                            onFinalize: {
                                currentFlow = .mealDetails
                            }
                        )

                    case .multiImageCourseSelection(let images, let currentIndex):
                        MultiImageCourseSelectionView(
                            images: images,
                            currentIndex: currentIndex,
                            onCourseSelected: { course in
                                Task {
                                    await handleMultiImageWithCourse(course, at: currentIndex)
                                }
                            }
                        )
                        
                    case .mealDetails:
                        MealDetailsView(
                            currentDraft: currentDraft!,
                            onPublish: { meal in
                                Task {
                                    await publishMeal(meal: meal)
                                }
                            },
                            onBack: {
                                currentFlow = .nextAction
                            }
                        )
                    case .showCamera:
                        // This case should ideally not be reached if the condition is correct
                        // but as a fallback, we can return an empty view or a placeholder
                        EmptyView()
                    }
                }
                .navigationTitle("Add Meal")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private func handleMultiImageWithCourse(_ course: Course?, at index: Int) async {
        guard index < multipleImages.count else { return }
        
        do {
            let image = multipleImages[index]
            
            if currentDraft == nil {
                // Create new draft for first image
                currentDraft = try await draftService.createDraftMeal()
            }
            
            if let draft = currentDraft,
            let imageData = image.jpegData(compressionQuality: 0.8) {
                let _ = try await draftService.addPhoto(
                    to: draft.meal.id,
                    imageData: imageData,
                    course: course
                )
                // Refresh the current draft
                currentDraft = draftService.draftMeals.first { $0.meal.id == draft.meal.id }
            }
            
            // Check if there are more images to process
            let nextIndex = index + 1
            if nextIndex < multipleImages.count {
                currentFlow = .multiImageCourseSelection(images: multipleImages, currentIndex: nextIndex)
            } else {
                // All images processed, go to next action
                currentFlow = .nextAction
                multipleImages.removeAll()
                currentImageIndex = 0
            }
            
        } catch {
            print("Error adding photo: \(error)")
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
    
    private func publishMeal(meal: Meal) async {
       

        do {
            try await draftService.publishEntireMeal(
                meal: meal
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
    let onMultiplePhotos: ([UIImage]) -> Void
    @State private var showingCamera = false
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
                Button("Take Photo") {
                    showingCamera = true
                }
                .buttonStyle(PrimaryButtonStyle())
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
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(
                onImageCaptured: { imageData in
                    if let image = UIImage(data: imageData) {
                        showingCamera = false  // Add this line
                        onTakePhoto(image)
                    }
                },
                onMultipleImagesCaptured: { images in
                    showingCamera = false  // Add this line
                    onMultiplePhotos(images)
                }
            )
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
// MARK: - Multi Image Course Selection View
struct MultiImageCourseSelectionView: View {
    let images: [UIImage]
    let currentIndex: Int
    let onCourseSelected: (Course?) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack {
                Text("Image \(currentIndex + 1) of \(images.count)")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            // Photo Preview
            Image(uiImage: images[currentIndex])
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
            
            // Horizontal Photo Scroll with Plus Button
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Existing photos
                        ForEach(currentDraft.photos) { photo in
                            if let localImageData = loadLocalImageData(fileName: photo.url),
                               let uiImage = UIImage(data: localImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                                    .frame(width: 67.5, height: 120) // 16:9 ratio
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 67.5, height: 120)
                            }
                        }
                        
                        // Plus button card
                        Button(action: onTakeAnother) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 67.5, height: 120)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                )
                        }
                        .id("plusButton")
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    // Scroll to the end (plus button) when view appears
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("plusButton", anchor: .trailing)
                    }
                }
            }
            
            // Action Buttons (removed Take Another Photo)
            VStack(spacing: 16) {
                Button("Add More Courses Later") {
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
    let onPublish: (Meal) -> Void  // Changed to take complete data
    let onBack: () -> Void
    
    // Initialize state from currentDraft
    @State private var title: String
    @State private var description: String
    @State private var privacy: MealPrivacy
    @State private var selectedMealType: MealType
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantSearch = false
    @State private var rating: Int
    @State private var ingredients: String
    @State private var newTag: String = ""
    @State private var tags: [String]
    
    @Environment(\.dismiss) private var dismiss
    
    // Custom initializer to set initial state
    init(currentDraft: MealWithPhotos, onPublish: @escaping (Meal) -> Void, onBack: @escaping () -> Void) {
        self.currentDraft = currentDraft
        self.onPublish = onPublish
        self.onBack = onBack
        
        // Initialize state from currentDraft.meal
        _title = State(initialValue: currentDraft.meal.title ?? "")
        _description = State(initialValue: currentDraft.meal.description ?? "")
        _privacy = State(initialValue: currentDraft.meal.privacy)
        _selectedMealType = State(initialValue: currentDraft.meal.mealType)
        _selectedRestaurant = State(initialValue: currentDraft.meal.restaurant)
        _rating = State(initialValue: currentDraft.meal.rating ?? 0)
        _ingredients = State(initialValue: currentDraft.meal.ingredients ?? "")
        _tags = State(initialValue: currentDraft.meal.tags ?? [])
    }


    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Photos Preview
                photosPreviewSection
                
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
                    

                    }
                mealTypeSection

                if selectedMealType == .restaurant {
                    restaurantSection
                }
                
                mealDetailsSection

                tagsSection
                
                // Publish Button
                Button("Publish Meal") {
                    let updatedMeal = currentDraft.updating(
                        title: title,
                        description: description,
                        privacy: privacy,
                        mealType: selectedMealType,
                        restaurant: selectedRestaurant,
                        rating: rating,
                        ingredients: ingredients,
                        tags: tags
                    )
                    onPublish(updatedMeal.meal)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    onBack()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
    }

        private var photosPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Photos (\(currentDraft.photos.count))")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(currentDraft.photos) { photo in
                        if let localImageData = loadLocalImageData(fileName: photo.url),
                           let uiImage = UIImage(data: localImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 120) // 4:3 ratio for better visibility
                                .clipped()
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 90, height: 120)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    private func loadLocalImageData(fileName: String) -> Data? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        return try? Data(contentsOf: filePath)
    }
    private var mealDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
            
            VStack(spacing: 12) {                
                if selectedMealType == .restaurant {
                    HStack {
                        Text("Rating")
                        Spacer()
                        StarRatingView(rating: $rating)
                    }
                 }
                 
                 if selectedMealType == .homemade {
                     TextField("Ingredients (optional)", text: $ingredients, axis: .vertical)
                         .textFieldStyle(.roundedBorder)
                         .lineLimit(2...4)
                 }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTag()
                    }
                
                Button("Add", action: addTag)
                    .disabled(newTag.isEmpty)
            }
            
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            TagView(tag: tag) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Type")
                .font(.headline)
            
            Picker("Meal Type", selection: $selectedMealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

        private var restaurantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restaurant")
                .font(.headline)
            
            if let restaurant = selectedRestaurant {
                RestaurantCardView(restaurant: restaurant) {
                    selectedRestaurant = nil
                }
            } else {
                Button(action: {
                    showingRestaurantSearch = true
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search for restaurant")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
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
struct TagView: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.2))
        .foregroundColor(.orange)
        .clipShape(Capsule())
    }
}

struct StarRatingView: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    rating = star
                }) {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundColor(star <= rating ? .yellow : .gray)
                }
            }
        }
    }
}
