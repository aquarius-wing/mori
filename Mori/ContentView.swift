import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("currentProvider") private var currentProvider = LLMProviderType.openRouter.rawValue
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openrouterApiKey") private var openrouterApiKey = ""
    
    var body: some View {
        if hasCompletedOnboarding && hasValidApiKey {
            ChatView()
        } else {
            OnboardingView()
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

#Preview {
    ContentView()
} 