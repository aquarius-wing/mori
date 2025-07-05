import SwiftUI

// MARK: - Menu Chat History Manager
// Using global shared ChatHistoryManager instance

struct MenuView: View {
    @EnvironmentObject var router: AppRouter
    @ObservedObject private var chatHistoryManager = sharedChatHistoryManager
    @AppStorage("currentChatHistoryId") private var currentChatHistoryId: String?
    @Binding var isPresented: Bool
    @State private var showingRenameAlert = false
    @State private var selectedHistoryId: String?
    @State private var renameText = ""
    @State private var showingDebugMenu = false
    @State private var showingActionAlert = false
    @State private var pendingAction: MenuAction?
    @State private var showingSettings = false
    
    enum MenuAction {
        case email
        case github
        
        var title: String {
            switch self {
            case .email:
                return "Send Email"
            case .github:
                return "Open GitHub"
            }
        }
        
        var message: String {
            switch self {
            case .email:
                return "This will open your email app to send an email to lwy8wing@gmail.com"
            case .github:
                return "This will open the GitHub page in your browser"
            }
        }
    }
    
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Chat History List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(chatHistoryManager.chatHistoryItems) { historyItem in
                        ChatHistoryItemView(
                            historyItem: historyItem,
                            isSelected: currentChatHistoryId == historyItem.id,
                            onSelect: {
                                currentChatHistoryId = historyItem.id
                                // Need to load full ChatHistory for onSelectChatHistory
                                if let fullHistory = chatHistoryManager.loadChatHistory(id: historyItem.id) {
                                    onSelectChatHistory?(fullHistory)
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            },
                            onRename: {
                                selectedHistoryId = historyItem.id
                                renameText = historyItem.title
                                showingRenameAlert = true
                            },
                            onDelete: {
                                chatHistoryManager.deleteChat(id: historyItem.id)
                                // If the deleted chat is current, clear current ID
                                if currentChatHistoryId == historyItem.id {
                                    currentChatHistoryId = nil
                                }
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
                        icon: "gear",
                        title: "Settings",
                        action: {
                            showingSettings = true
                        }
                    )
                    
                    MenuItemView(
                        icon: "envelope",
                        title: "Email",
                        action: {
                            pendingAction = .email
                            showingActionAlert = true
                        }
                    )
                    
                    MenuItemView(
                        icon: "link",
                        title: "GitHub",
                        action: {
                            pendingAction = .github
                            showingActionAlert = true
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .alert("Rename Chat", isPresented: $showingRenameAlert) {
            TextField("Chat Title", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if let historyId = selectedHistoryId {
                    chatHistoryManager.renameChat(id: historyId, newTitle: renameText)
                }
            }
        }
        .alert(
            pendingAction?.title ?? "",
            isPresented: $showingActionAlert
        ) {
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
            Button("Confirm") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                }
                
                switch pendingAction {
                case .email:
                    if let url = URL(string: "mailto:lwy8wing@gmail.com") {
                        UIApplication.shared.open(url)
                    }
                case .github:
                    if let url = URL(string: "https://github.com/aquarius-wing/mori") {
                        UIApplication.shared.open(url)
                    }
                case .none:
                    break
                }
                
                pendingAction = nil
            }
        } message: {
            Text(pendingAction?.message ?? "")
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
    let historyItem: ChatHistoryItem
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
                    Text(historyItem.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(historyItem.updateDate.formatted(date: .abbreviated, time: .shortened))
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
                    Text(historyItem.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(historyItem.updateDate.formatted(date: .abbreviated, time: .shortened))
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



#Preview {
    MenuView(
        isPresented: .constant(true),
        onClearChat: nil,
        onShowFiles: nil,
        onSelectChatHistory: nil
    )
    .environmentObject(AppRouter())
} 
