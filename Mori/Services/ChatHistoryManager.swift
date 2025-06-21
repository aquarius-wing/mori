import Foundation

class ChatHistoryManager: ObservableObject {
    
    // MARK: - Private Properties
    
    private func getChatHistoryDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("chatHistorys")
    }
    
    private func ensureChatHistoryDirectoryExists() {
        let chatHistoryDir = getChatHistoryDirectory()
        if !FileManager.default.fileExists(atPath: chatHistoryDir.path) {
            try? FileManager.default.createDirectory(at: chatHistoryDir, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    // MARK: - Public Methods
    
    /// Save current chat and return the chat ID
    func saveCurrentChat(_ messages: [MessageListItemType], existingId: String? = nil) -> String {
        let chatHistory: ChatHistory
        
        if let id = existingId {
            // Update existing chat
            if let existing = loadChatHistory(id: id) {
                chatHistory = ChatHistory(
                    id: id,
                    title: existing.title,
                    messageList: messages,
                    createDate: existing.createDate
                )
            } else {
                chatHistory = ChatHistory(messageList: messages)
            }
        } else {
            // Create new chat
            chatHistory = ChatHistory(messageList: messages)
        }
        
        saveChatHistory(chatHistory)
        return chatHistory.id
    }
    
    /// Load chat messages by ID
    func loadChat(id: String) -> [MessageListItemType]? {
        guard let chatHistory = loadChatHistory(id: id) else {
            return nil
        }
        return chatHistory.messageList
    }
    
    /// Get all chat histories sorted by update date
    func getAllChatHistories() -> [ChatHistory] {
        ensureChatHistoryDirectoryExists()
        let chatHistoryDir = getChatHistoryDirectory()
        
        guard FileManager.default.fileExists(atPath: chatHistoryDir.path) else {
            return []
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: chatHistoryDir, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("chatHistory_") }
            
            var chatHistories: [ChatHistory] = []
            
            for fileURL in jsonFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let chatHistory = try decoder.decode(ChatHistory.self, from: data)
                    chatHistories.append(chatHistory)
                } catch {
                    print("❌ Failed to load chat history from \(fileURL.lastPathComponent): \(error)")
                }
            }
            
            // Sort by update date descending
            return chatHistories.sorted { $0.updateDate > $1.updateDate }
        } catch {
            print("❌ Failed to read chat history directory: \(error)")
            return []
        }
    }
    
    /// Delete chat by ID
    func deleteChat(id: String) {
        ensureChatHistoryDirectoryExists()
        let chatHistoryDir = getChatHistoryDirectory()
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(id).json")
        
        do {
            try FileManager.default.removeItem(at: filePath)
            print("🗑️ Deleted chat history: \(id)")
        } catch {
            print("❌ Failed to delete chat history: \(error)")
        }
    }
    
    /// Create new chat and return the ID
    func createNewChat() -> String {
        let newChatHistory = ChatHistory()
        return newChatHistory.id
    }
    
    /// Rename chat history
    func renameChat(id: String, newTitle: String) {
        guard var chatHistory = loadChatHistory(id: id) else {
            print("❌ Chat history not found for renaming: \(id)")
            return
        }
        
        chatHistory.title = newTitle
        chatHistory.updateDate = Date()
        saveChatHistory(chatHistory)
        print("✏️ Renamed chat history to: \(newTitle)")
    }
    
    // MARK: - Private Helper Methods
    
    private func loadChatHistory(id: String) -> ChatHistory? {
        ensureChatHistoryDirectoryExists()
        let chatHistoryDir = getChatHistoryDirectory()
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(id).json")
        
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ChatHistory.self, from: data)
        } catch {
            print("❌ Failed to load chat history: \(error)")
            return nil
        }
    }
    
    private func saveChatHistory(_ chatHistory: ChatHistory) {
        ensureChatHistoryDirectoryExists()
        let chatHistoryDir = getChatHistoryDirectory()
        let filePath = chatHistoryDir.appendingPathComponent("chatHistory_\(chatHistory.id).json")
        
        do {
            var updatedChatHistory = chatHistory
            updatedChatHistory.updateDate = Date()
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(updatedChatHistory)
            try data.write(to: filePath)
            
            print("💾 Saved chat history: \(updatedChatHistory.title)")
        } catch {
            print("❌ Failed to save chat history: \(error)")
        }
    }

} 