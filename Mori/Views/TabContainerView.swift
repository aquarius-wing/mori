import SwiftUI

struct TabContainerView: View {
    @EnvironmentObject var router: AppRouter
    
    // For customizing chat content
    var chatContent: () -> AnyView
    
    init(@ViewBuilder chatContent: @escaping () -> AnyView = { AnyView(ChatView()) }) {
        self.chatContent = chatContent
    }
    
    var body: some View {
        TabView(selection: $router.currentRoute) {
            // Chat Tab
            chatContent()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .tag(AppRoute.chat)
            
            // Chart Tab
            ChartView()
                .tabItem {
                    Label("Chart", systemImage: "chart.bar")
                }
                .tag(AppRoute.chart)
        }
    }
}

#Preview {
    TabContainerView()
        .environmentObject(AppRouter())
        .environmentObject(ThemeManager.shared)
} 