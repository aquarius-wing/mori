import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    
    var body: some View {
        if hasCompletedOnboarding && !openaiApiKey.isEmpty {
            ChatView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
} 