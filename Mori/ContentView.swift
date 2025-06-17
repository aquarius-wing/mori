import SwiftUI

// MARK: - App Routes
enum AppRoute: String, CaseIterable {
    case onboarding = "onboarding"
    case chat = "chat"
}

// MARK: - App Router
@MainActor
class AppRouter: ObservableObject {
    @Published var currentRoute: AppRoute = .onboarding
    
    // App Storage properties for persistence
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("currentProvider") private var currentProvider = ""
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openrouterApiKey") private var openrouterApiKey = ""
    
    init() {
        // Initialize route based on current state
        updateCurrentRoute()
    }
    
    // MARK: - Navigation Methods
    func navigateToOnboarding() {
        currentRoute = .onboarding
    }
    
    func navigateToChat() {
        currentRoute = .chat
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        updateCurrentRoute()
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        updateCurrentRoute()
    }
    
    // MARK: - Private Methods
    private func updateCurrentRoute() {
        if hasCompletedOnboarding && hasValidApiKey {
            currentRoute = .chat
        } else {
            currentRoute = .onboarding
        }
    }
    
    private var hasValidApiKey: Bool {
        guard let providerType = LLMProviderType(rawValue: currentProvider) else { return false }
        
        switch providerType {
        case .openai:
            return !openaiApiKey.isEmpty
        case .openRouter:
            return !openrouterApiKey.isEmpty
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var router = AppRouter()
    
    var body: some View {
        NavigationStack {
            Group {
                switch router.currentRoute {
                case .onboarding:
                    OnboardingView()
                        .environmentObject(router)
                case .chat:
                    MainView()
                        .environmentObject(router)
                }
            }
        }
        .environmentObject(router)
    }
}

#Preview {
    ContentView()
} 