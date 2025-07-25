import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    let onboardingData = [
        OnboardingPage(
            title: "Welcome to",
            highlightedTitle: "Foodoo",
            description: "Discover your favorite restaurants and cuisines, and get them delivered right to your doorstep",
            imageName: "shopping.bag",
            backgroundColor: Color(red: 0.98, green: 0.85, blue: 0.36)
        ),
        OnboardingPage(
            title: "Explore Local",
            highlightedTitle: "Eateries",
            description: "Browse through a variety of restaurants nearby from popular chains to hidden gems, and find the perfect meal for any craving",
            imageName: "map",
            backgroundColor: Color(red: 0.98, green: 0.85, blue: 0.36)
        ),
        OnboardingPage(
            title: "Dive into",
            highlightedTitle: "Deliciousness",
            description: "Explore mouthwatering menus, view detailed descriptions and images, and customize your order exactly how you like",
            imageName: "menucard",
            backgroundColor: Color(red: 0.98, green: 0.85, blue: 0.36)
        ),
        OnboardingPage(
            title: "Order with",
            highlightedTitle: "Ease",
            description: "Browse through a variety of restaurants nearby from popular chains to hidden gems, and find the perfect meal for any craving",
            imageName: "creditcard",
            backgroundColor: Color(red: 0.98, green: 0.85, blue: 0.36)
        ),
        OnboardingPage(
            title: "Food",
            highlightedTitle: "is on the Way",
            description: "Sit back and relax as our delivery partners bring your freshly prepared meal to you. Track your order in real time and get ready to enjoy!",
            imageName: "truck.box",
            backgroundColor: Color(red: 0.98, green: 0.85, blue: 0.36)
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                onboardingData[currentPage].backgroundColor
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Main Content
                    VStack(spacing: 30) {
                        // Illustration
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white.opacity(0.9))
                                .frame(width: 280, height: 320)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: onboardingData[currentPage].imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                        }
                        .scaleEffect(currentPage == 4 ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                        
                        // Title and Description
                        VStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text(onboardingData[currentPage].title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Text(onboardingData[currentPage].highlightedTitle)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.13))
                            }
                            
                            Text(onboardingData[currentPage].description)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.black.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .lineLimit(nil)
                        }
                    }
                    
                    Spacer()
                    
                    // Page Indicator and Navigation
                    VStack(spacing: 30) {
                        // Page Dots
                        HStack(spacing: 8) {
                            ForEach(0..<onboardingData.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentPage ? Color(red: 0.85, green: 0.65, blue: 0.13) : Color.black.opacity(0.2))
                                    .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                            }
                        }
                        
                        // Navigation Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                if currentPage < onboardingData.count - 1 {
                                    currentPage += 1
                                } else {
                                    onFinish()
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.85, green: 0.65, blue: 0.13))
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                
                                if currentPage == onboardingData.count - 1 {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .scaleEffect(currentPage == onboardingData.count - 1 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 20)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        if value.translation.width < -50 && currentPage < onboardingData.count - 1 {
                            currentPage += 1
                        } else if value.translation.width > 50 && currentPage > 0 {
                            currentPage -= 1
                        }
                    }
                }
        )
    }
}

struct OnboardingPage {
    let title: String
    let highlightedTitle: String
    let description: String
    let imageName: String
    let backgroundColor: Color
}

