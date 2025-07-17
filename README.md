# Tava - Food Sharing App 🍽️

A modern SwiftUI iOS app that lets friends share what they're eating - both at restaurants and at home.

## Features

### 📱 Three Main Tabs
1. **Discover (Map & Feed)** - View meals on a map and browse friend activity
2. **Add Meal** - Share your dining experiences with photos and details
3. **Profile** - View your food journey and manage your account

### 🏗️ Architecture
- **SwiftUI** with modern iOS design patterns
- **Supabase** backend with row-level security
- **Google Places API** integration for restaurant data
- **MVVM** architecture with ObservableObject services
- **Forced dark mode** for elegant UI

### 🔐 Security & Privacy
- Email/Social authentication via Supabase Auth
- Row-level security (RLS) for data protection
- Privacy controls (public, friends-only, private meals)
- Secure image storage with Supabase Storage

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 16.0+
- Supabase account
- Google Places API key (optional, for restaurant features)

### 1. Database Setup
1. Create a new Supabase project
2. Run the SQL from `supabase_schema.sql` in your Supabase SQL editor
3. Set up storage bucket named `meal-photos` with public access

### 2. Configure API Keys
Update the following files with your credentials:

**`tava/Services/SupabaseClient.swift`**
```swift
let supabaseURL = URL(string: "YOUR_SUPABASE_PROJECT_URL")!
let supabaseKey = "YOUR_SUPABASE_ANON_KEY"
```

**`tava/Services/GooglePlacesService.swift`** (Optional)
```swift
private let apiKey = "YOUR_GOOGLE_PLACES_API_KEY"
```

> 📋 **Google Places Setup**: See `GOOGLE_PLACES_SETUP.md` for detailed instructions on setting up Google Places API, including API key restrictions and cost optimization.

### 3. Install Dependencies
This project uses Swift Package Manager. Dependencies will be automatically resolved when you open the project in Xcode.

**Dependencies:**
- `supabase/supabase-swift` - Supabase Swift client

### 4. Build and Run
1. Open `tava.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run (⌘+R)

## Project Structure

```
tava/
├── Models/                 # Data models
│   ├── User.swift
│   ├── Meal.swift
│   ├── Restaurant.swift
│   ├── Photo.swift
│   ├── CollaborativeMeal.swift
│   └── Bookmark.swift
├── Services/               # Business logic layer
│   ├── SupabaseClient.swift
│   ├── MealService.swift
│   ├── GooglePlacesService.swift
│   └── LocationService.swift
├── Views/                  # SwiftUI views
│   ├── MainTabView.swift
│   ├── MapFeedView.swift
│   ├── AddMealView.swift
│   ├── ProfileView.swift
│   ├── MealDetailView.swift
│   ├── Components/
│   └── Placeholder/
└── ContentView.swift       # Root view with auth flow
```

## Sample Flow: Adding a Homemade Meal

Here's how the app handles uploading a homemade meal:

### 1. User Navigation
- User taps "Add Meal" tab (center tab with plus icon)
- `AddMealView` is presented

### 2. Photo Selection
- User taps camera/photo library buttons
- `PhotosPicker` allows selection of up to 5 images
- Photos are converted to `UIImage` objects and stored locally

### 3. Meal Details
- User selects "Homemade" meal type
- Fills in optional fields:
  - Title (e.g., "Homemade Pasta Carbonara")
  - Description (e.g., "Made with fresh eggs and pancetta")
  - Ingredients (e.g., "Pasta, eggs, pancetta, parmesan, black pepper")
  - Tags (e.g., "italian", "comfort-food", "dinner")
- Sets privacy level (public/friends-only/private)
- Optionally adds rating (1-5 stars) and cost

### 4. Submission Process
When user taps "Add Meal":

```swift
// 1. Create meal object
let newMeal = Meal(
    id: UUID(),
    userId: currentUserId,
    restaurantId: nil, // No restaurant for homemade
    mealType: .homemade,
    title: title,
    description: description,
    ingredients: ingredients,
    tags: tags,
    privacy: privacy,
    location: userLocation, // Current location for homemade meals
    rating: rating,
    cost: cost,
    eatenAt: Date(),
    createdAt: Date(),
    updatedAt: Date()
)

// 2. Upload to Supabase database
try await supabase.client
    .from("meals")
    .insert([newMeal])
    .execute()

// 3. Upload photos to Supabase Storage
for (index, image) in photos.enumerated() {
    let photoPath = "meals/\(userId)/meal_\(mealId)_\(timestamp)_\(index).jpg"
    let photoUrl = try await supabase.uploadPhoto(image: image, path: photoPath)
    
    // 4. Save photo metadata
    let photo = Photo(
        id: UUID(),
        mealId: newMeal.id,
        userId: currentUserId,
        storagePath: photoPath,
        url: photoUrl,
        isPrimary: index == 0,
        createdAt: Date()
    )
    
    try await supabase.client
        .from("photos")
        .insert([photo])
        .execute()
}
```

### 5. Result
- Success message is shown
- Form is cleared for next meal
- Meal appears in user's profile and friend feeds (based on privacy settings)

## Database Schema Highlights

### Core Tables
- `users` - User profiles extending Supabase auth
- `meals` - Both restaurant and homemade meals
- `restaurants` - Google Places-sourced restaurant data
- `photos` - Meal images with Supabase Storage integration
- `user_follows` - Social following relationships
- `meal_reactions` - Likes and reactions on meals

### Security
- Row-level security (RLS) on all tables
- Users can only access public meals or meals from followed users
- Users can only modify their own content
- Privacy levels respected at database level

## API Integration

### Supabase Features Used
- ✅ Authentication (Email/Password)
- ✅ Database with RLS
- ✅ Storage for images
- ✅ Real-time subscriptions (planned)
- ✅ Edge Functions (planned for recommendations)

### Google Places Integration
- Restaurant search by location/query and nearby search
- Automatic address and metadata population
- Rating and price level information
- Business hours, photos, and contact info
- Place details with comprehensive business data

## Future Enhancements

- [ ] Push notifications for friend activity
- [ ] Real-time meal updates
- [ ] Social features (comments, following)
- [ ] Meal recommendations using Supabase Edge Functions
- [ ] Apple/Google Sign-In
- [ ] Collaborative meal planning
- [ ] Export meal history
- [ ] Restaurant reviews and check-ins

## Contributing

This is a sample project demonstrating modern iOS app architecture with Supabase. Feel free to use it as a starting point for your own food-sharing application.

## License

MIT License - see LICENSE file for details # tava
