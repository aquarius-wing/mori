import SwiftUI

@main
struct MoriApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.currentMode.colorScheme)
                .onAppear {
                    // Ensure theme is applied on app launch
                    themeManager.updateAppearance()
                }
        }
    }
} 