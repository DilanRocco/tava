// import SwiftUI

// struct MealDetailView: View {
//     let meal: MealWithPhotos
//     let onAddPhoto: () -> Void
//     let onPhotoCourseChange: (Photo) -> Void
    
//     @Environment(\.dismiss) private var dismiss
//     @StateObject private var draftService = DraftMealService()
//     @State private var showingPublishOptions = false
//     @State private var showingPublishMeal = false
    
//     private var courseGroups: [Course: [Photo]] {
//             var groups: [Course: [Photo]] = [:]
            
//             for photo in meal.photos {
//                 if let course = photo.course {
//                     if groups[course] == nil {
//                         groups[course] = []
//                     }
//                     groups[course]!.append(photo)
//                 }
//             }
            
//             return groups
//         }
    
//     private var uncategorizedPhotos: [Photo] {
//         meal.photos.filter { $0.course == nil }
//     }
    
//     var body: some View {
//         NavigationView {
//             ScrollView {
//                 VStack(spacing: 20) {
//                     // Publish Options
//                     publishSection
                    
//                     Divider()
                    
//                     // Photos by Course
//                     if !courseGroups.isEmpty {
//                         courseSections
//                     }
                    
//                     // Uncategorized Photos
//                     if !uncategorizedPhotos.isEmpty {
//                         uncategorizedSection
//                     }
                    
//                     // Add Photo Button
//                     addPhotoSection
//                 }
//                 .padding()
//             }
//             .navigationTitle("Meal Photos")
//             .navigationBarTitleDisplayMode(.inline)
//             .toolbar {
//                 ToolbarItem(placement: .topBarTrailing) {
//                     Button("Done") {
//                         dismiss()
//                     }
//                 }
//             }
//         }
//         .sheet(isPresented: $showingPublishMeal) {
//             PublishMealView(meal: meal) { title, description, privacy in
//                 Task {
//                     await publishEntireMeal(title: title, description: description, privacy: privacy)
//                 }
//             }
//         }
//         .actionSheet(isPresented: $showingPublishOptions) {
//             ActionSheet(
//                 title: Text("Publish Options"),
//                 message: Text("How would you like to publish this meal?"),
//                 buttons: [
//                     .default(Text("Publish Entire Meal")) {
//                         showingPublishMeal = true
//                     },
//                     .default(Text("Publish Individual Courses")) {
//                         // Individual course publishing is handled in course sections
//                     },
//                     .cancel()
//                 ]
//             )
//         }
//     }
    
//     private var publishSection: some View {
//         VStack(spacing: 12) {
//             HStack {
//                 Text("Ready to Share?")
//                     .font(.headline)
//                 Spacer()
//             }
            
//             Button(action: { showingPublishOptions = true }) {
//                 HStack {
//                     Image(systemName: "paperplane.fill")
//                     Text("Publish Meal")
//                 }
//                 .frame(maxWidth: .infinity)
//                 .padding()
//                 .background(Color.green)
//                 .foregroundColor(.white)
//                 .rounded()
//             }
//             .disabled(meal.photos.isEmpty)
//         }
//     }
    
//     private var courseSections: some View {
//         ForEach(courseGroups.keys.sorted(by: { $0.displayName < $1.displayName }), id: \.self) { course in
//             VStack(alignment: .leading, spacing: 12) {
//                 HStack {
//                     HStack(spacing: 8) {
//                         Text(course.emoji)
//                         Text(course.displayName)
//                             .font(.headline)
//                     }
                    
//                     Spacer()
                    
//                     Button("Publish \(course.displayName)") {
//                         Task {
//                             await publishCourse(course)
//                         }
//                     }
//                     .font(.caption)
//                     .padding(.horizontal, 12)
//                     .padding(.vertical, 6)
//                     .background(Color.accentColor.opacity(0.1))
//                     .foregroundColor(.accentColor)
//                     .rounded()
//                 }
                
//                 LazyVGrid(columns: [
//                     GridItem(.flexible()),
//                     GridItem(.flexible()),
//                     GridItem(.flexible())
//                 ], spacing: 12) {
//                     ForEach(courseGroups[course] ?? []) { photo in
//                         PhotoCard(
//                             photo: photo,
//                             onCourseTap: { onPhotoCourseChange(photo) }
//                         )
//                     }
//                 }
//             }
//         }
//     }
    
//     private var uncategorizedSection: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             HStack {
//                 Text("🍴 Uncategorized")
//                     .font(.headline)
//                 Spacer()
//             }
            
//             LazyVGrid(columns: [
//                 GridItem(.flexible()),
//                 GridItem(.flexible()),
//                 GridItem(.flexible())
//             ], spacing: 12) {
//                 ForEach(uncategorizedPhotos) { photo in
//                     PhotoCard(
//                         photo: photo,
//                         onCourseTap: { onPhotoCourseChange(photo) }
//                     )
//                 }
//             }
//         }
//     }
    
//     private var addPhotoSection: some View {
//         Button(action: onAddPhoto) {
//             VStack {
//                 Image(systemName: "plus")
//                     .font(.title2)
//                     .foregroundColor(.secondary)
//                 Text("Add Photo")
//                     .font(.caption)
//                     .foregroundColor(.secondary)
//             }
//             .frame(maxWidth: .infinity, minHeight: 60)
//             .background(Color.secondary.opacity(0.1))
//             .rounded(12)
//         }
//     }
    
//     // MARK: - Publishing Actions
    
//     private func publishCourse(_ course: Course) async {
//         do {
//             try await draftService.publishCourse(mealId: meal.meal.id, course: course)
//             dismiss()
//         } catch {
//             // Handle error
//             print("Failed to publish course: \(error)")
//         }
//     }
    
//     private func publishEntireMeal(title: String?, description: String?, privacy: MealPrivacy) async {
//         do {
//             try await draftService.publishEntireMeal(
//                 mealId: meal.meal.id,
//                 title: title,
//                 description: description,
//                 privacy: privacy
//             )
//             dismiss()
//         } catch {
//             // Handle error
//             print("Failed to publish meal: \(error)")
//         }
//     }
// }
