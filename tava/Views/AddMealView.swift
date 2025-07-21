import SwiftUI
import PhotosUI

struct AddMealView: View {
    @StateObject private var draftService = DraftMealService()
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedMeal: MealWithPhotos?
    @State private var showingCourseSelector = false
    @State private var photoForCourseSelection: Photo?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if draftService.isLoading {
                    ProgressView("Loading your drafts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { imageData in
                Task {
                    await handleNewPhoto(imageData)
                }
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { newPhoto in
            if let photo = newPhoto {
                Task {
                    await handlePhotosPickerSelection(photo)
                }
            }
        }
        .sheet(isPresented: $showingCourseSelector) {
            if let photo = photoForCourseSelection {
                CourseSelectorView(
                    photo: photo,
                    currentCourse: photo.course
                ) { course in
                    Task {
                        await updatePhotoCourse(photo: photo, course: course)
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(draftService.error != nil)) {
            Button("OK") {
                draftService.error = nil
            }
        } message: {
            if let error = draftService.error {
                Text(error)
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if draftService.draftMeals.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                newMealSection
                Divider()
                    .padding(.horizontal)
                draftMealsSection
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("Start Your Meal Journey")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Capture your food moments as they happen")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            newMealButtons
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var newMealSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Meal")
                    .font(.headline)
                Spacer()
            }
            
            newMealButtons
        }
        .padding()
    }
    
    private var newMealButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showingCamera = true }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .rounded()
            }
            
            Button(action: { showingPhotoPicker = true }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from Library")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.primary)
                .rounded()
            }
        }
    }
    
    private var draftMealsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Continue Previous Meals")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(draftService.draftMeals) { mealWithPhotos in
                        DraftMealCard(
                            meal: mealWithPhotos,
                            onTap: { selectedMeal = mealWithPhotos },
                            onDelete: {
                                Task {
                                    await deleteDraftMeal(mealWithPhotos.meal.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailView(
                meal: meal,
                onAddPhoto: { showingCamera = true },
                onPhotoCourseChange: { photo in
                    photoForCourseSelection = photo
                    showingCourseSelector = true
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func handleNewPhoto(_ imageData: Data) async {
        do {
            // Create new draft meal if none selected, or add to existing
            let targetMeal: MealWithPhotos
            if let selected = selectedMeal {
                targetMeal = selected
            } else {
                targetMeal = try await draftService.createDraftMeal()
                selectedMeal = targetMeal
            }
            
            let _ = try await draftService.addPhoto(
                to: targetMeal.meal.id,
                imageData: imageData,
                course: nil
            )
        } catch {
            draftService.error = error.localizedDescription
        }
    }
    
    private func handlePhotosPickerSelection(_ photoItem: PhotosPickerItem) async {
        do {
            guard let imageData = try await photoItem.loadTransferable(type: Data.self) else {
                return
            }
            await handleNewPhoto(imageData)
        } catch {
            draftService.error = error.localizedDescription
        }
    }
    
    private func updatePhotoCourse(photo: Photo, course: Course?) async {
        do {
            try await draftService.updatePhotoCourse(photoId: photo.id, course: course)
            photoForCourseSelection = nil
        } catch {
            draftService.error = error.localizedDescription
        }
    }
    
    private func deleteDraftMeal(_ mealId: UUID) async {
        do {
            try await draftService.deleteDraftMeal(mealId: mealId)
        } catch {
            draftService.error = error.localizedDescription
        }
    }
}

// MARK: - Supporting Views

struct DraftMealCard: View {
    let meal: MealWithPhotos
    let onTap: () -> Void
    let onDelete: () -> Void
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: meal.meal.updatedAt, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)
                
                if let primaryPhoto = meal.primaryPhoto {
                    AsyncImage(url: URL(string: primaryPhoto.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .clipped()
                    .rounded(12)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No photos yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.white.opacity(0.8))
                                .rounded()
                        }
                    }
                    Spacer()
                }
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(meal.photos.count) photo\(meal.photos.count == 1 ? "" : "s")")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("Updated \(timeAgo)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if !meal.coursesSummary.isEmpty && meal.coursesSummary != "No categories" {
                    Text(meal.coursesSummary)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}



struct PhotoCard: View {
    let photo: Photo
    let onCourseTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: photo.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .rounded(12)
            
            Button(action: onCourseTap) {
                HStack {
                    if let course = photo.course {
                        Text(course.emoji)
                        Text(course.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    } else {
                        Image(systemName: "tag")
                            .font(.caption)
                        Text("Add Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }
}

struct CourseSelectorView: View {
    let photo: Photo
    let currentCourse: Course?
    let onSelection: (Course?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Food Categories") {
                    ForEach(Course.allCases, id: \.self) { course in
                        Button(action: {
                            onSelection(course)
                            dismiss()
                        }) {
                            HStack {
                                Text(course.emoji)
                                Text(course.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if currentCourse == course {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        onSelection(nil)
                        dismiss()
                    }) {
                        HStack {
                            Text("🚫")
                            Text("Remove Category")
                                .foregroundColor(.red)
                            Spacer()
                            if currentCourse == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PublishMealView: View {
    let meal: MealWithPhotos
    let onPublish: (String?, String?, MealPrivacy) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedPrivacy: MealPrivacy = .public
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Meal Details") {
                    TextField("Meal title (optional)", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Privacy") {
                    Picker("Who can see this meal?", selection: $selectedPrivacy) {
                        ForEach(MealPrivacy.allCases, id: \.self) { privacy in
                            Text(privacy.displayName).tag(privacy)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(meal.photos.count) photo\(meal.photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !meal.coursesSummary.isEmpty && meal.coursesSummary != "No categories" {
                            Text("Courses: \(meal.coursesSummary)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 8) {
                                ForEach(meal.photos.prefix(5)) { photo in
                                    AsyncImage(url: URL(string: photo.url)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.3))
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .rounded(8)
                                }
                                
                                if meal.photos.count > 5 {
                                    Text("+\(meal.photos.count - 5)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, height: 60)
                                        .background(Color.secondary.opacity(0.1))
                                        .rounded(8)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Publish Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Publish") {
                        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        onPublish(
                            finalTitle.isEmpty ? nil : finalTitle,
                            finalDescription.isEmpty ? nil : finalDescription,
                            selectedPrivacy
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

extension MealPrivacy {
    var displayName: String {
        switch self {
        case .public:
            return "Public"
        case .friendsOnly:
            return "Friends Only"
        case .private:
            return "Private"
        }
    }
}

// MARK: - Extensions

extension View {
    func rounded(_ radius: CGFloat = 8) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius))
    }
}
