import Foundation

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let isSystem: Bool
    
    init(content: String, isUser: Bool, timestamp: Date? = nil, isSystem: Bool = false) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp ?? Date()
        self.isSystem = isSystem
    }
} 