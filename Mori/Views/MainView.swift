import SwiftUI

// Note: MessageListItem functionality moved to MessageListItemType enum in ChatHistory.swift

struct MainView: View {
    @EnvironmentObject var router: AppRouter
    @State private var showingFilesView = false
    @State private var selectedChatHistory: ChatHistory?
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - MenuView
            MenuSidebarView(
                onShowFiles: {
                    showingFilesView = true
                },
                onSelectChatHistory: { chatHistory in
                    selectedChatHistory = chatHistory
                    // Notify ChatView to load the selected chat history
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LoadChatHistory"),
                        object: chatHistory
                    )
                    // On iPhone, hide sidebar after selection
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        columnVisibility = .detailOnly
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            // Detail - ChatView
            NavigationStack{
                ChatView()
                    .navigationTitle("Chat")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        // Add menu button for iPhone only
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    columnVisibility = .all
                                }) {
                                    Image(systemName: "sidebar.left")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        #if DEBUG
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Debug") {
                                // Trigger debug action in ChatView via notification
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ShowDebugActionSheet"),
                                    object: nil
                                )
                            }
                            .foregroundColor(.white)
                        }
                        #endif

                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                // Trigger new chat creation via notification
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("CreateNewChat"),
                                    object: nil
                                )
                            }) {
                                Image(systemName: "message")
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingFilesView) {
            FilesView()
        }
        .onAppear {
            // On iPhone, start with detail view showing if we have content
            // On iPad, show both sidebar and detail
            if UIDevice.current.userInterfaceIdiom == .phone {
                columnVisibility = .detailOnly
            }
        }
    }
}

// Wrapper for MenuView to adapt it for NavigationSplitView
struct MenuSidebarView: View {
    @State private var isPresented = true // Always presented in split view
    
    var onShowFiles: (() -> Void)?
    var onSelectChatHistory: ((ChatHistory) -> Void)?
    
    var body: some View {
        MenuView(
            isPresented: $isPresented,
            onClearChat: {
                // This will be handled by ChatView
                NotificationCenter.default.post(
                    name: NSNotification.Name("ClearChat"),
                    object: nil
                )
            },
            onShowFiles: onShowFiles,
            onSelectChatHistory: onSelectChatHistory
        )
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
                .frame(
                    maxWidth: UIScreen.main.bounds.width * 0.7,
                    alignment: .trailing
                )
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
                        if !message.isUser
                            && !message.content.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                        {
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
                .frame(
                    maxWidth: UIScreen.main.bounds.width * 0.7,
                    alignment: .leading
                )

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
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
        // No updates needed
    }
}

#Preview {
    MainView()
}
