import SwiftUI

struct MenuView: View {
    @EnvironmentObject var router: AppRouter
    @Binding var isPresented: Bool
    var onClearChat: (() -> Void)?
    var onShowFiles: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mori")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("AI Assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            
            // Menu Items
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    MenuItemView(
                        icon: "message",
                        title: "New Chat",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            // Post notification to clear chat in ChatView
                            NotificationCenter.default.post(name: NSNotification.Name("ClearChat"), object: nil)
                        }
                    )
                    
                    MenuItemView(
                        icon: "gearshape",
                        title: "Settings",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            router.resetOnboarding()
                        }
                    )
                    
                    MenuItemView(
                        icon: "folder",
                        title: "Recording Files",
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                            onShowFiles?()
                        }
                    )
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    MenuItemView(
                        icon: "info.circle",
                        title: "About",
                        action: {
                            // About action - placeholder for future implementation
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }
                    )
                    
                    MenuItemView(
                        icon: "questionmark.circle",
                        title: "Help",
                        action: {
                            // Help action - placeholder for future implementation
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }
                    )
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Footer
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                HStack {
                    Text("Version 1.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            }
        }
        .frame(width: 280)
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 10)
    }
}

struct MenuItemView: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        )
        .onTapGesture {
            action()
        }
    }
}

#Preview {
    MenuView(
        isPresented: .constant(true),
        onClearChat: nil,
        onShowFiles: nil
    )
    .environmentObject(AppRouter())
} 