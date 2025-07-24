import SwiftUI
import PhotosUI

// MARK: - Navigation Destination Types
enum NavigationDestination: Hashable {
    case courseSelection(imageData: Data) // Pass image data directly
    case multiImageCourseSelection(images: [UIImage], currentIndex: Int) // Pass images directly
    case nextAction(draftId: UUID) // Pass draftId directly
    case mealDetails(draftId: UUID) // Pass draftId directly
}

// MARK: - Legacy MealFlow enum for backwards compatibility
extension AddMealView {
    enum MealFlow: Equatable {
        case initial
        case courseSelection
        case multiImageCourseSelection(images: [UIImage], currentIndex: Int)
        case nextAction
        case mealDetails
        case showCamera
    }
}

// MARK: - Main Add Meal View
struct AddMealView: View {
    @State private var navigationPath = NavigationPath()
    @State private var currentDraftId: UUID?
    @State private var showingCamera = false
    
    @EnvironmentObject private var draftService: DraftMealService
    @Environment(\.dismiss) private var dismiss
    let onDismiss: (() -> Void)?

    // Computed property to always get the latest draft from service
    private var currentDraft: MealWithPhotos? {
        guard let draftId = currentDraftId else { return nil }
        return draftService.draftMeals.first { $0.meal.id == draftId }
    }

    init(startingImages: [UIImage] = [], onDismiss: (() -> Void)? = nil, stage: MealFlow? = nil) {
        self.onDismiss = onDismiss
        
        // Handle legacy stage parameter by converting to new navigation system
        if let stage = stage {
            switch stage {
            case .courseSelection:
                if startingImages.count > 0, 
                   let imageData = startingImages[0].jpegData(compressionQuality: 0.8) {
                    _navigationPath = State(initialValue: {
                        var path = NavigationPath()
                        path.append(NavigationDestination.courseSelection(imageData: imageData))
                        return path
                    }())
                }
            case .multiImageCourseSelection(let images, let currentIndex):
                _navigationPath = State(initialValue: {
                    var path = NavigationPath()
                    path.append(NavigationDestination.multiImageCourseSelection(images: images, currentIndex: currentIndex))
                    return path
                }())
            default:
                // For other stages, use default behavior
                break
            }
        } else if startingImages.count == 1 {
            if let imageData = startingImages[0].jpegData(compressionQuality: 0.8) {
                _navigationPath = State(initialValue: {
                    var path = NavigationPath()
                    path.append(NavigationDestination.courseSelection(imageData: imageData))
                    return path
                }())
            }
        } else if startingImages.count > 1 {
            _navigationPath = State(initialValue: {
                var path = NavigationPath()
                path.append(NavigationDestination.multiImageCourseSelection(images: startingImages, currentIndex: 0))
                return path
            }())
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            InitialView(
                draftService: draftService,
                onTakePhoto: { showingCamera = true },
                onSelectDraft: { draft in
                    // Set the current draft ID and navigate with it directly
                    currentDraftId = draft.meal.id
                    navigationPath.append(NavigationDestination.nextAction(draftId: draft.meal.id))
                }
            )
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .courseSelection(let imageData):
                    if let image = UIImage(data: imageData) {
                        CourseSelectionView(
                            capturedImage: image,
                            onCourseSelected: { course in
                                Task { 
                                    await handlePhotoWithCourse(course, imageData)
                                }
                            }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    
                case .multiImageCourseSelection(let images, let currentIndex):
                    if currentIndex < images.count {
                        MultiImageCourseSelectionView(
                            images: images,
                            currentIndex: currentIndex,
                            onCourseSelected: { course in
                                Task { 
                                    await handleMultiImageWithCourse(course, images: images, at: currentIndex)
                                }
                            }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    
                case .nextAction(let draftId):
                    // Use the draftId directly from the navigation destination
                    if let draft = draftService.draftMeals.first(where: { $0.meal.id == draftId }) {
                        NextActionView(
                            draftId: draftId,
                            onTakeAnother: { 
                                showingCamera = true 
                            },
                            onContinueLater: {
                                draftService.saveDraftMealsToLocal(draftService.draftMeals)
                                if let onDismiss = onDismiss {
                                    onDismiss()
                                } else {
                                    dismiss()
                                }
                            },
                            onFinalize: {
                                navigationPath.append(NavigationDestination.mealDetails(draftId: draftId))
                            }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                        .environmentObject(draftService)
                    } else {
                        Text("No draft available")
                            .foregroundColor(.secondary)
                    }
                    
                case .mealDetails(let draftId):
                    // Use the draftId directly from the navigation destination
                    if let draft = draftService.draftMeals.first(where: { $0.meal.id == draftId }) {
                        MealDetailsView(
                            draftId: draftId,
                            onPublish: { meal in 
                                Task { 
                                    await publishMeal(meal: meal) 
                                }
                            }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationTitle("Finalize Meal")
                        .environmentObject(draftService)
                    } else {
                        Text("No draft available")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(
                onImageCaptured: { imageData in
                    showingCamera = false
                    navigationPath.append(NavigationDestination.courseSelection(imageData: imageData))
                },
                onMultipleImagesCaptured: { images in
                    showingCamera = false
                    navigationPath.append(NavigationDestination.multiImageCourseSelection(images: images, currentIndex: 0))
                },
                onCancel: {
                    showingCamera = false
                }
            )
        }
    }

    // MARK: - Helper Functions
    private func handleMultiImageWithCourse(_ course: Course?, images: [UIImage], at index: Int) async {
        guard index < images.count else { return }
        
        do {
            let image = images[index]
            
            let newDraft = try await draftService.createDraftMeal()
            currentDraftId = newDraft.meal.id
            
            if let draftId = currentDraftId,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let _ = try await draftService.addPhoto(
                    to: draftId,
                    imageData: imageData,
                    course: course
                )
                
                // Navigation handled after async operation completes
                await MainActor.run {
                    let nextIndex = index + 1
                    if nextIndex < images.count {
                        // Replace current destination with next image
                        navigationPath.removeLast()
                        navigationPath.append(NavigationDestination.multiImageCourseSelection(images: images, currentIndex: nextIndex))
                    } else {
                        // Done with all images, go to next action with the draftId
                        navigationPath.removeLast()
                        navigationPath.append(NavigationDestination.nextAction(draftId: draftId))
                    }
                }
            }
        } catch {
            print("Error adding photo: \(error)")
        }
    }

    // Update handlePhotoWithCourse signature and usage
    private func handlePhotoWithCourse(_ course: Course?, _ imageData: Data) async {
        do {
            let newDraft = try await draftService.createDraftMeal()
            currentDraftId = newDraft.meal.id
            if let draftId = currentDraftId {
                let _ = try await draftService.addPhoto(
                    to: draftId,
                    imageData: imageData,
                    course: course
                )
                
                // Navigate after async operation completes
                await MainActor.run {
                    navigationPath.append(NavigationDestination.nextAction(draftId: draftId))
                }
            }
        } catch {
            print("Error adding photo: \(error)")
        }
    }
    
    private func publishMeal(meal: Meal) async {
        do {
            try await draftService.publishEntireMeal(meal: meal)
            print("meal published: \(meal)")
            await MainActor.run {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
        } catch {
            print("Error publishing meal: \(error)")
        }
    }
}

// MARK: - Initial View
struct InitialView: View {
    let draftService: DraftMealService
    let onTakePhoto: () -> Void
    let onSelectDraft: (MealWithPhotos) -> Void
    @State private var isEditingDrafts = false
    @State private var deletingMealIds: Set<UUID> = []
    @State private var cameraButtonPressed = false

    var body: some View {
        VStack(spacing: 30) {
            // Camera Section
            VStack(spacing: 20) {
                Text("📸")
                    .font(.system(size: 60))
                    .scaleEffect(cameraButtonPressed ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cameraButtonPressed)
                
                Text("Capture Your Meal")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Button(action: onTakePhoto) {
                    Text("Take Photo")
                }
                .buttonStyle(PrimaryButtonStyle())
                .scaleEffect(cameraButtonPressed ? 0.95 : 1.0)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        cameraButtonPressed = pressing
                    }
                }, perform: {})
            }
            
            // Collaborative Meals Section
            if !draftService.draftMeals.isEmpty {
                Divider()
                    .transition(.opacity)
                
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
                                    .scaleEffect(isEditingDrafts ? 0.95 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isEditingDrafts)
                                    
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
                                        .offset(x: 8, y: -8)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .scaleEffect(deletingMealIds.contains(draft.meal.id) ? 0.8 : 1.0)
                                .opacity(deletingMealIds.contains(draft.meal.id) ? 0.0 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: deletingMealIds.contains(draft.meal.id))
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func deleteMeal(_ draft: MealWithPhotos) {
        withAnimation(.easeInOut(duration: 0.3)) {
            deletingMealIds.insert(draft.meal.id)
        }
        
        Task {
            do {
                try await draftService.deleteDraftMeal(mealId: draft.meal.id)
                deletingMealIds.remove(draft.meal.id)
            } catch {
                deletingMealIds.remove(draft.meal.id)
            }
        }
    }
}

// MARK: - Course Selection View
struct CourseSelectionView: View {
    let capturedImage: UIImage
    let onCourseSelected: (Course?) -> Void
    
    @State private var selectedCourse: Course?
    @State private var animatingOut = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                .padding(.horizontal)
                .scaleEffect(animatingOut ? 0.95 : 1.0)
                .opacity(animatingOut ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: animatingOut)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("What course is this?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(Course.allCases.prefix(8), id: \.self) { course in
                        CourseButton(
                            course: course,
                            isSelected: selectedCourse == course,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCourse = course
                                    animatingOut = true
                                }
                                onCourseSelected(course)
                            }
                        )
                    }
                }
                
                Button("Skip for now") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        animatingOut = true
                    }
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
        .navigationTitle("Select Course")
    }
}

// MARK: - Multi Image Course Selection View
struct MultiImageCourseSelectionView: View {
    let images: [UIImage]
    let currentIndex: Int
    let onCourseSelected: (Course?) -> Void
    
    @State private var selectedCourse: Course?
    @State private var animatingOut = false
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Image \(currentIndex + 1) of \(images.count)")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            Image(uiImage: images[currentIndex])
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                .padding(.horizontal)
                .scaleEffect(animatingOut ? 0.95 : 1.0)
                .opacity(animatingOut ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: animatingOut)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("What course is this?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(Course.allCases.prefix(8), id: \.self) { course in
                        CourseButton(
                            course: course,
                            isSelected: selectedCourse == course,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCourse = course
                                    animatingOut = true
                                }
                                onCourseSelected(course)
                            }
                        )
                    }
                }
                
                Button("Skip for now") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        animatingOut = true
                    }
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
        .navigationTitle("Select Course")
    }
}

// MARK: - Course Button Component
struct CourseButton: View {
    let course: Course
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(course.emoji)
                    .font(.title)
                Text(course.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(isSelected ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Next Action View
struct NextActionView: View {
    let draftId: UUID
    let onTakeAnother: () -> Void
    let onContinueLater: () -> Void
    let onFinalize: () -> Void
    
    @State private var isEditMode = false
    @State private var showingFullScreenImage: IdentifiableImage?
    @State private var successAnimation = false
    @State private var photoToDelete: Photo?
    @EnvironmentObject private var draftService: DraftMealService
    
    struct IdentifiableImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    private var currentDraft: MealWithPhotos? {
        draftService.draftMeals.first { $0.meal.id == draftId }
    }
    
    private var photoCount: Int {
        currentDraft?.photos.count ?? 0
    }
    
    private var photos: [Photo] {
        currentDraft?.photos ?? []
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("✅")
                    .font(.system(size: 60))
                    .scaleEffect(successAnimation ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: successAnimation)
                
                Text("Photo Added!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("You now have \(photoCount) photo\(photoCount == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
            }
            .onAppear {
                withAnimation {
                    successAnimation = true
                }
            }
            .onDisappear {
                successAnimation = false
            }
            
            VStack(spacing: 12) {
                if photoCount > 0 {
                    HStack {
                        Spacer()
                        Button(isEditMode ? "Done" : "Edit") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditMode.toggle()
                            }
                        }
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    }
                    .padding(.horizontal)
                }
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(photos) { photo in
                                photoThumbnail(for: photo)
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale(scale: 0.8).combined(with: .opacity)
                                    ))
                                    .id(photo.id)
                            }
                            
                            Button(action: onTakeAnother) {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.05))
                                    )
                                    .frame(width: 67.5, height: 120)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 24))
                                            .foregroundColor(.secondary)
                                    )
                            }
                            .id("addButton")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 136)
                    .clipped()
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("addButton", anchor: .trailing)
                        }
                    }
                }
            }
            
            VStack(spacing: 16) {
                Button("Add More Courses Later") {
                    onContinueLater()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Finalize & Publish") {
                    onFinalize()
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(photos.isEmpty)
                .opacity(photos.isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Next Steps")
        .sheet(item: $showingFullScreenImage) {
            FullScreenImageView(image: $0.image)
        }
    }
    
    private func photoThumbnail(for photo: Photo) -> some View {
        ZStack {
            if let localImageData = loadLocalImageData(fileName: photo.url),
               let uiImage = UIImage(data: localImageData) {
                if !isEditMode {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 67.5, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            showingFullScreenImage = IdentifiableImage(image: uiImage)
                        }
                        .contextMenu {
                            Button {
                                showingFullScreenImage = IdentifiableImage(image: uiImage)
                            } label: {
                                Label("View", systemImage: "eye")
                            }
                            Button(role: .destructive) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    photoToDelete = photo
                                    removePhoto(photo)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                } else {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 67.5, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(photoToDelete?.id == photo.id ? 0.3 : 1.0)
                        .scaleEffect(photoToDelete?.id == photo.id ? 0.8 : 1.0)
                        .onTapGesture { }
                }
                if isEditMode {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            photoToDelete = photo
                            removePhoto(photo)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                            .background(Color.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    .position(x: 67.5 - 8, y: 8)
                    .transition(.scale.combined(with: .opacity))
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 67.5, height: 120)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: photoToDelete?.id == photo.id)
    }

    private func removePhoto(_ photo: Photo) {
        guard let draft = currentDraft,
              let mealIndex = draftService.draftMeals.firstIndex(where: { $0.meal.id == draft.meal.id }) else { return }
        
        let currentMeal = draftService.draftMeals[mealIndex]
        let updatedPhotos = currentMeal.photos.filter { $0.id != photo.id }
        let updatedMeal = MealWithPhotos(meal: currentMeal.meal, photos: updatedPhotos)
        draftService.draftMeals[mealIndex] = updatedMeal
        
        draftService.saveDraftMealsToLocal(draftService.draftMeals)
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(photo.url)
        try? FileManager.default.removeItem(at: filePath)
        
        photoToDelete = nil
        if photos.count == 1 {
            isEditMode = false
        }
    }
    
    private func loadLocalImageData(fileName: String) -> Data? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        return try? Data(contentsOf: filePath)
    }
}

// MARK: - Meal Details View
struct MealDetailsView: View {
    let draftId: UUID
    let onPublish: (Meal) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var privacy: MealPrivacy = .public
    @State private var selectedMealType: MealType = .homemade
    @State private var selectedRestaurant: Restaurant?
    @State private var showingRestaurantSearch = false
    @State private var rating: Int?
    @State private var ingredients: String = ""
    @State private var newTag: String = ""
    @State private var tags: [String] = []
    @State private var isPublishing = false
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @EnvironmentObject private var draftService: DraftMealService
    
    enum Field {
        case title, description, ingredients, tag
    }
    
    private var currentDraft: MealWithPhotos? {
        draftService.draftMeals.first { $0.meal.id == draftId }
    }
    
    var body: some View {
        Group {
            if let draft = currentDraft {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Photos (\(draft.photos.count))")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(draft.photos) { photo in
                                        if let localImageData = loadLocalImageData(fileName: photo.url),
                                           let uiImage = UIImage(data: localImageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 90, height: 120)
                                                .clipped()
                                                .cornerRadius(8)
                                                .transition(.scale.combined(with: .opacity))
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
                        .transition(.move(edge: .top).combined(with: .opacity))
                        
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("What did you eat?", text: $title)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .title)
                                    .onSubmit {
                                        updateDraft()
                                        focusedField = .description
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("Tell us about it...", text: $description, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                                    .focused($focusedField, equals: .description)
                                    .onSubmit {
                                        updateDraft()
                                    }
                            }
                        }
                        
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
                            .onChange(of: selectedMealType) { _ in
                                updateDraft()
                            }
                        }

                        if selectedMealType == .restaurant {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Restaurant")
                                    .font(.headline)
                                
                                if let restaurant = selectedRestaurant {
                                    RestaurantCardView(restaurant: restaurant) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedRestaurant = nil
                                            updateDraft()
                                        }
                                    }
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale(scale: 0.8).combined(with: .opacity)
                                    ))
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
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale(scale: 0.8).combined(with: .opacity)
                                    ))
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Details")
                                .font(.headline)
                            
                            VStack(spacing: 12) {                
                                if selectedMealType == .restaurant {
                                    HStack {
                                        Text("Rating")
                                        Spacer()
                                        StarRatingView(rating: $rating) { newRating in
                                            updateDraft()
                                        }
                                    }
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                 }
                                 
                                 if selectedMealType == .homemade {
                                     TextField("Ingredients (optional)", text: $ingredients, axis: .vertical)
                                         .textFieldStyle(.roundedBorder)
                                         .lineLimit(2...4)
                                         .focused($focusedField, equals: .ingredients)
                                         .onSubmit {
                                             updateDraft()
                                         }
                                         .transition(.move(edge: .leading).combined(with: .opacity))
                                 }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)
                            
                            HStack {
                                TextField("Add tag", text: $newTag)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .tag)
                                    .onSubmit {
                                        addTag()
                                    }
                                
                                Button("Add", action: {
                                    addTag()
                                })
                                .disabled(newTag.isEmpty)
                            }
                            
                            if !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(tags, id: \.self) { tag in
                                            TagView(tag: tag) {
                                                withAnimation(.easeOut(duration: 0.2)) {
                                                    tags.removeAll { $0 == tag }
                                                    updateDraft()
                                                }
                                            }
                                            .transition(.asymmetric(
                                                insertion: .scale.combined(with: .opacity),
                                                removal: .scale(scale: 0.8).combined(with: .opacity)
                                            ))
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                        }
                        
                        Button(action: {
                            isPublishing = true
                            if let updatedDraft = currentDraft {
                                onPublish(updatedDraft.meal)
                            }
                        }) {
                            if isPublishing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Publish Meal")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isPublishing)
                        .opacity(isPublishing ? 0.7 : 1.0)
                    }
                    .padding()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
                .onAppear {
                    // Initialize state from draft
                    title = draft.meal.title ?? ""
                    description = draft.meal.description ?? ""
                    privacy = draft.meal.privacy
                    selectedMealType = draft.meal.mealType
                    selectedRestaurant = draft.meal.restaurant
                    rating = draft.meal.rating
                    ingredients = draft.meal.ingredients ?? ""
                    tags = draft.meal.tags ?? []
                }
                .onChange(of: selectedRestaurant) { _ in
                    updateDraft()
                }
                .sheet(isPresented: $showingRestaurantSearch) {
                    RestaurantSearchView(selectedRestaurant: $selectedRestaurant) 
                }
            } else {
                Text("Draft not found")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func loadLocalImageData(fileName: String) -> Data? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        return try? Data(contentsOf: filePath)
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            withAnimation(.easeInOut(duration: 0.2)) {
                tags.append(trimmedTag)
            }
            newTag = ""
            updateDraft()
        }
    }
    
    private func updateDraft() {
        guard let draft = currentDraft,
              let idx = draftService.draftMeals.firstIndex(where: { $0.meal.id == draft.meal.id }) else { return }
        
        let updatedDraft = draft.updating(
            title: title.isEmpty ? nil : title,
            description: description.isEmpty ? nil : description,
            privacy: privacy,
            mealType: selectedMealType,
            restaurant: selectedRestaurant,
            rating: rating,
            ingredients: ingredients.isEmpty ? nil : ingredients,
            tags: tags.isEmpty ? nil : tags
        )
        
        draftService.draftMeals[idx] = updatedDraft
        draftService.saveDraftMealsToLocal(draftService.draftMeals)
    }
}

// MARK: - Supporting Views
struct DraftMealThumbnail: View {
    let draft: MealWithPhotos
    let onTap: () -> Void
    
    @State private var isPressed = false
    
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
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func loadLocalImageData(fileName: String) -> Data? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsDirectory.appendingPathComponent("draft_photos").appendingPathComponent(fileName)
        return try? Data(contentsOf: filePath)
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    withAnimation(.spring()) {
                                        scale = min(max(scale, 1), 4)
                                        lastScale = scale
                                    }
                                }
                                .simultaneously(with: DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { value in
                                        lastOffset = offset
                                    }
                                )
                        )
                        .animation(.interactiveSpring(), value: scale)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
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
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TagView: View {
    let tag: String
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
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
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct StarRatingView: View {
    @Binding var rating: Int?
    var onRatingChange: ((Int?) -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            if let rate = rating {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rating = star
                            onRatingChange?(star)
                        }
                    }) {
                        Image(systemName: star <= rate ? "star.fill" : "star")
                            .foregroundColor(star <= rate ? .yellow : .gray)
                            .scaleEffect(star == rate ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)
                    }
                }
            } else {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rating = star
                            onRatingChange?(star)
                        }
                    }) {
                        Image(systemName: "star")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}