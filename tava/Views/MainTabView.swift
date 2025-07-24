import SwiftUI

import SwiftUI

struct MainTabView: View {
    @StateObject var draftMealService: DraftMealService = DraftMealService()
    @State private var selectedTab = 0
    @State private var showCameraFlow = false
    @State private var cameraFlowState: CameraFlowState = .camera
    @State private var capturedImages: [UIImage] = []
    
    enum CameraFlowState {
        case camera
        case addMeal
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content based on selected tab
            TabView(selection: $selectedTab) {
                FeedView()
                    .tag(0)
                DiscoveryView()
                    .tag(1)
                MapFeedView()
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom Tab Bar
            CustomTabBar(
                selectedTab: $selectedTab,
                showAddMeal: .constant(false),
                showCamera: $showCameraFlow
            )
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .fullScreenCover(isPresented: $showCameraFlow) {
            CameraFlowView(
                flowState: $cameraFlowState,
                capturedImages: $capturedImages,
                draftMealService: draftMealService,
                onComplete: {
                    showCameraFlow = false
                    cameraFlowState = .camera
                    capturedImages = []
                }
            )
        }
    }
}

struct CameraFlowView: View {
    @Binding var flowState: MainTabView.CameraFlowState
    @Binding var capturedImages: [UIImage]
    @ObservedObject var draftMealService: DraftMealService
    let onComplete: () -> Void
    var addedMultipleImages = false
    var body: some View {
        // Check if there are drafts when the view appears
        if draftMealService.draftMeals.count > 0 && flowState == .camera {
            AddMealView(
                startingImages: capturedImages,
                onDismiss: onComplete,
                stage: .initial
            )
        } else if flowState == .camera {
            CameraView(
                onImageCaptured: { imageData in
                    if let image = UIImage(data: imageData) {
                        capturedImages = [image]
                        flowState = .addMeal
                        // self.addedMultipleImages = false
                    }
                },
                onMultipleImagesCaptured: { images in
                    // self.addedMultipleImages = true
                    capturedImages = images
                    flowState = .addMeal
                },
                onCancel: {
                    onComplete()
                }
            )
        } else {
            AddMealView(
                startingImages: capturedImages,
                onDismiss: onComplete,
                stage: addedMultipleImages ? .multiImageCourseSelection(images: capturedImages, currentIndex: 0) : .courseSelection
            )
        }
    }
}


struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showAddMeal: Bool
    @Binding var showCamera: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Home Tab
            TabBarButton(
                icon: "house",
                selectedIcon: "house.fill",
                title: "Discover",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            .frame(maxWidth: .infinity)
            
            // Search Tab
            TabBarButton(
                icon: "bolt.circle",
                selectedIcon: "bolt.circle.fill",
                title: "Explore",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            .frame(maxWidth: .infinity)

            TabBarButton(
                icon: "magnifyingglass",
                selectedIcon: "magnifyingglass",
                title: "Search",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            .frame(maxWidth: .infinity)
            
            // Plus Tab (Floating)
            Button(action: {
                if true {
                    showCamera = true
                } else {
                    showAddMeal = true
                }
                
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -20) // Extends above the tab bar
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24) // Extends into safe area
        .background(
            Color.white
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .black : .gray)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .black : .gray)
            }
        }
    }
}


struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

