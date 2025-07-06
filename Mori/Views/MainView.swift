import SwiftUI

// Note: MessageListItem functionality moved to MessageListItemType enum in ChatHistory.swift

struct MainView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    // Navigation state
    @State private var showingMenu = false
    let rightPadding = 88.0
    
    @State private var showingFilesView = false
    @State private var selectedChatHistory: ChatHistory?
    @State private var columnVisibility = NavigationSplitViewVisibility
        .automatic

    var body: some View {
        // Check if device is iPad or Mac
        if UIDevice.current.userInterfaceIdiom == .pad
            || ProcessInfo.processInfo.isMacCatalystApp
        {
            // iPad and macOS: Use NavigationSplitView
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
                    }
                )
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            } detail: {
                // Detail - ChatView
                ChatView()
            }
            .navigationSplitViewStyle(.balanced)
            .sheet(isPresented: $showingFilesView) {
                FilesView()
            }
        } else {
            // iPhone: Use NavigationStack with different layout
            GeometryReader { geometry in
                ZStack {
                    NavigationView {
                        ChatView(onShowMenu: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingMenu.toggle()
                            }
                        })
                    }
                    .navigationBarHidden(true)
                    .offset(
                        x: showingMenu ? geometry.size.width - rightPadding : 0
                    )

                    // Side Menu Overlay
                    if showingMenu {
                        ThemeColors.background(for: colorScheme)
                            .opacity(0.1)
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
                                        name: NSNotification.Name(
                                            "LoadChatHistory"
                                        ),
                                        object: chatHistory
                                    )
                                }
                            )
                            .frame(width: geometry.size.width - rightPadding)
                            .transition(.move(edge: .leading))
                            .overlay(
                                HStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(ThemeColors.border(for: colorScheme))
                                        .frame(width: 1)
                                        .ignoresSafeArea()
                                }
                            )

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
    }
}

// Wrapper for MenuView to adapt it for NavigationSplitView
struct MenuSidebarView: View {
    @State private var isPresented = true  // Always presented in split view

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
    @Environment(\.colorScheme) var colorScheme

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
                        .background(ThemeColors.cardBackground(for: colorScheme))
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
        .environmentObject(AppRouter())
        .environmentObject(ThemeManager.shared)
}
