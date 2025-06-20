import SwiftUI

// MARK: - Chat History Manager
class ChatHistoryManager: ObservableObject {
    @Published var chatHistories: [ChatHistory] = []
    @AppStorage("currentChatHistoryId") var currentChatHistoryId: String?
    
    init() {
        loadChatHistories()
    }
    
    func loadChatHistories() {
        chatHistories = ChatView2.loadAllChatHistories()
    }
    
    func deleteChatHistory(_ historyId: String) {
        if let history = chatHistories.first(where: { $0.id == historyId }) {
            ChatView2.deleteChatHistory(history)
            loadChatHistories()
            
            // If the deleted chat is current, clear current ID
            if currentChatHistoryId == historyId {
                currentChatHistoryId = nil
            }
        }
    }
    
    func renameChatHistory(_ historyId: String, to newTitle: String) {
        if let history = chatHistories.first(where: { $0.id == historyId }) {
            ChatView2.renameChatHistory(history, newTitle: newTitle)
            loadChatHistories()
        }
    }
}

struct MenuView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var chatHistoryManager = ChatHistoryManager()
    @Binding var isPresented: Bool
    @State private var showingRenameAlert = false
    @State private var selectedHistoryId: String?
    @State private var renameText = ""
    @State private var showingDebugMenu = false
    
    var onClearChat: (() -> Void)?
    var onShowFiles: (() -> Void)?
    var onSelectChatHistory: ((ChatHistory) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Messages")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        // Add new chat action
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Chat History List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(chatHistoryManager.chatHistories) { history in
                        ChatHistoryItemView(
                            history: history,
                            isSelected: chatHistoryManager.currentChatHistoryId == history.id,
                            onSelect: {
                                chatHistoryManager.currentChatHistoryId = history.id
                                onSelectChatHistory?(history)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            },
                            onRename: {
                                selectedHistoryId = history.id
                                renameText = history.title
                                showingRenameAlert = true
                            },
                            onDelete: {
                                chatHistoryManager.deleteChatHistory(history.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 0) {
                Divider()
                    .background(Color.secondary.opacity(0.2))
                
                VStack(spacing: 2) {
                    MenuItemView(
                        icon: "gearshape",
                        title: "Settings",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented = false
                            }
                            router.resetOnboarding()
                        }
                    )
                    
                    MenuItemView(
                        icon: "info.circle",
                        title: "About",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented = false
                            }
                        }
                    )
                    
                    MenuItemView(
                        icon: "questionmark.circle",
                        title: "Help",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented = false
                            }
                        }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                // Version Footer
                HStack {
                    Text("Version 1.0")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Spacer()
                    
                    Button(action: {
                        showingDebugMenu = true
                    }) {
                        Image(systemName: "ladybug")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showingDebugMenu) {
                        DebugMenuView()
                            .frame(width: 200, height: 150)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .frame(width: 280)
        .background(Color(UIColor.systemBackground))
        .alert("Rename Chat", isPresented: $showingRenameAlert) {
            TextField("Chat Title", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if let historyId = selectedHistoryId {
                    chatHistoryManager.renameChatHistory(historyId, to: renameText)
                }
            }
        }
    }
}

struct MenuItemView: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct ChatHistoryItemView: View {
    let history: ChatHistory
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Chat icon
                Image(systemName: "message")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .frame(width: 14, height: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(history.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(history.updateDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.8))
                }
                
                Spacer()
                
                // More options indicator (only show on hover or selected)
                if isHovered || isSelected {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.6))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected ? 
                        AnyShapeStyle(LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )) :
                        AnyShapeStyle(isHovered ? 
                            Color.secondary.opacity(0.08) : 
                            Color.clear)
                    )
            )
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 10))
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } preview: {
            HStack(spacing: 10) {
                Image(systemName: "message")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(history.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(history.updateDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

struct DebugMenuView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Menu")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            VStack(spacing: 4) {
                DebugMenuItem(title: "Clear All Data", icon: "trash") {
                    // Debug action - placeholder
                }
                
                DebugMenuItem(title: "Export Logs", icon: "square.and.arrow.up") {
                    // Debug action - placeholder
                }
                
                DebugMenuItem(title: "Reset Settings", icon: "arrow.clockwise") {
                    // Debug action - placeholder
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
    }
}

struct DebugMenuItem: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    MenuView(
        isPresented: .constant(true),
        onClearChat: nil,
        onShowFiles: nil,
        onSelectChatHistory: nil
    )
    .environmentObject(AppRouter())
} 
