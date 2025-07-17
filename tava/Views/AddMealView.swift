import SwiftUI
import PhotosUI

struct AddMealView: View {
    @EnvironmentObject var mealService: MealService
    @EnvironmentObject var googlePlacesService: GooglePlacesService
    @EnvironmentObject var locationService: LocationService
    
    @State private var selectedMealType: MealType = .homemade
    @State private var title = ""
    @State private var description = ""
    @State private var ingredients = ""
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var privacy: MealPrivacy = .public
    @State private var rating: Int = 0
    @State private var cost = ""
    @State private var selectedRestaurant: Restaurant?
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingRestaurantSearch = false
    
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Photo Section
                    photoSection
                    
                    // Meal Type Selection
                    mealTypeSection
                    
                    // Restaurant Selection (if restaurant meal)
                    if selectedMealType == .restaurant {
                        restaurantSection
                    }
                    
                    // Meal Details
                    mealDetailsSection
                    
                    // Tags Section
                    tagsSection
                    
                    // Privacy & Settings
                    privacySection
                    
                    // Submit Button
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        clearForm()
                    }
                    .disabled(isFormEmpty)
                }
            }
        }
        .sheet(isPresented: $showingRestaurantSearch) {
            RestaurantSearchView(selectedRestaurant: $selectedRestaurant)
        }
        .alert("Meal Added!", isPresented: $showingSuccess) {
            Button("OK") {
                clearForm()
            }
        } message: {
            Text("Your meal has been successfully shared!")
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
                .foregroundColor(.primary)
            
            if selectedImages.isEmpty {
                VStack {
                    Image(systemName: "camera.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Add photos of your meal")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 16) {
                        Button("Camera") {
                            showingCamera = true
                        }
                        .buttonStyle(.bordered)
                        
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            Text("Photo Library")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Button(action: {
                                    selectedImages.remove(at: index)
                                    selectedPhotos.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(4)
                            }
                        }
                        
                        if selectedImages.count < 5 {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                    Text("Add More")
                                        .font(.caption)
                                }
                                .foregroundColor(.gray)
                                .frame(width: 120, height: 120)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .onChange(of: selectedPhotos) { newItems in
            Task {
                selectedImages = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImages.append(image)
                    }
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
                    HStack {
                        Image(systemName: type == .homemade ? "house.fill" : "building.2.fill")
                        Text(type.rawValue.capitalized)
                    }
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
    
    private var mealDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                TextField("Meal title (optional)", text: $title)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                if selectedMealType == .homemade {
                    TextField("Ingredients (optional)", text: $ingredients, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
                
                HStack {
                    Text("Rating")
                    Spacer()
                    StarRatingView(rating: $rating)
                }
                
                TextField("Cost (optional)", text: $cost)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
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
                    .disabled(newTag.trim().isEmpty)
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
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy")
                .font(.headline)
            
            Picker("Privacy", selection: $privacy) {
                ForEach(MealPrivacy.allCases, id: \.self) { privacy in
                    Text(privacy.displayName)
                        .tag(privacy)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var submitButton: some View {
        Button(action: submitMeal) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                Text(isSubmitting ? "Adding Meal..." : "Add Meal")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSubmit ? Color.orange : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSubmit || isSubmitting)
    }
    
    private var canSubmit: Bool {
        !selectedImages.isEmpty && !isSubmitting
    }
    
    private var isFormEmpty: Bool {
        selectedImages.isEmpty && title.isEmpty && description.isEmpty && 
        ingredients.isEmpty && tags.isEmpty && selectedRestaurant == nil
    }
    
    private func addTag() {
        let trimmedTag = newTag.trim()
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func submitMeal() {
        guard canSubmit else { return }
        
        isSubmitting = true
        
        Task {
            do {
                let location = selectedMealType == .restaurant ? 
                    selectedRestaurant?.location : 
                    (locationService.location.map { LocationPoint(from: $0) })
                
                let costDecimal = Decimal(string: cost)
                
                _ = try await mealService.createMeal(
                    mealType: selectedMealType,
                    title: title.isEmpty ? nil : title,
                    description: description.isEmpty ? nil : description,
                    ingredients: ingredients.isEmpty ? nil : ingredients,
                    tags: tags,
                    privacy: privacy,
                    location: location,
                    rating: rating > 0 ? rating : nil,
                    cost: costDecimal,
                    restaurantId: selectedRestaurant?.id,
                    photos: selectedImages
                )
                
                await MainActor.run {
                    showingSuccess = true
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    // Handle error
                }
            }
        }
    }
    
    private func clearForm() {
        selectedMealType = .homemade
        title = ""
        description = ""
        ingredients = ""
        tags = []
        newTag = ""
        privacy = .public
        rating = 0
        cost = ""
        selectedRestaurant = nil
        selectedPhotos = []
        selectedImages = []
    }
}

// MARK: - Helper Views

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

extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension MealPrivacy {
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .friendsOnly: return "Friends Only"
        case .private: return "Private"
        }
    }
} 