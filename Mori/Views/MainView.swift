import SwiftUI

// Protocol to allow mixed ChatMessage and WorkflowStep in array
protocol MessageListItem: Identifiable, Codable {
    var id: UUID { get }
    var timestamp: Date { get }
}

extension ChatMessage: MessageListItem {}
extension WorkflowStep: MessageListItem {}

struct MainView: View {
    @EnvironmentObject var router: AppRouter
    
    // Navigation state
    @State private var showingMenu = false
    @State private var showingFilesView = false
    
    // Chat reference
    @State private var chatViewRef: ChatView2?
    
    var body: some View {
        ZStack {
            NavigationView {
                //onShowMenu: {
//                withAnimation(.easeInOut(duration: 0.3)) {
//                    showingMenu.toggle()
//                }
//            }
                ChatView()
            }
            .navigationBarHidden(true)
            .offset(x: showingMenu ? 280 : 0)
            
            // Side Menu Overlay
            if showingMenu {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingMenu = false
                        }
                    }
                
                HStack {
                    MenuView(
                        isPresented: $showingMenu,
                        onClearChat: {
                            // This will be handled by ChatView
                        },
                        onShowFiles: {
                            showingFilesView = true
                        },
                        onSelectChatHistory: { chatHistory in
                            // ChatView will handle loading the selected chat history
                            NotificationCenter.default.post(
                                name: NSNotification.Name("LoadChatHistory"),
                                object: chatHistory
                            )
                        }
                    )
                    .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingFilesView) {
            FilesView()
        }
        .animation(.easeInOut(duration: 0.3), value: showingMenu)
    }

}

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming = false
    var onPlayTTS: ((String) -> Void)?
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(16)
                    
                    HStack {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if isStreaming {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.secondary)
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                        
                        // Play TTS button for assistant messages
                        if !message.isUser && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                onPlayTTS?(message.content)
                            }) {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    MainView()
} 
