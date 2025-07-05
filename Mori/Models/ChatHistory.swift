import Foundation

// MARK: - MessageListItemType enum for Codable support
enum MessageListItemType: Codable, Identifiable {
    case chatMessage(ChatMessage)
    case workflowStep(WorkflowStep)
    
    var id: UUID {
        switch self {
        case .chatMessage(let message):
            return message.id
        case .workflowStep(let step):
            return step.id
        }
    }
    
    var timestamp: Date {
        switch self {
        case .chatMessage(let message):
            return message.timestamp
        case .workflowStep(let step):
            return step.timestamp
        }
    }
    
    // MessageListItemType now directly represents the message items
    
    // Codable support
    enum CodingKeys: String, CodingKey {
        case type, chatMessage, workflowStep
    }
    
    enum TypeKey: String, Codable {
        case chatMessage, workflowStep
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeKey.self, forKey: .type)
        
        switch type {
        case .chatMessage:
            let message = try container.decode(ChatMessage.self, forKey: .chatMessage)
            self = .chatMessage(message)
        case .workflowStep:
            let step = try container.decode(WorkflowStep.self, forKey: .workflowStep)
            self = .workflowStep(step)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .chatMessage(let message):
            try container.encode(TypeKey.chatMessage, forKey: .type)
            try container.encode(message, forKey: .chatMessage)
        case .workflowStep(let step):
            try container.encode(TypeKey.workflowStep, forKey: .type)
            try container.encode(step, forKey: .workflowStep)
        }
    }
}

// MARK: - ChatHistoryItem Model (Lightweight for list display)
struct ChatHistoryItem: Codable, Identifiable {
    let id: String
    var title: String
    let createDate: Date
    var updateDate: Date
    
    // Initialize from ChatHistory
    init(from chatHistory: ChatHistory) {
        self.id = chatHistory.id
        self.title = chatHistory.title
        self.createDate = chatHistory.createDate
        self.updateDate = chatHistory.updateDate
    }
    
    // Direct initialization
    init(id: String, title: String, createDate: Date, updateDate: Date) {
        self.id = id
        self.title = title
        self.createDate = createDate
        self.updateDate = updateDate
    }
}

// MARK: - ChatHistory Model
struct ChatHistory: Codable, Identifiable {
    let id: String
    var title: String
    var messageList: [MessageListItemType]
    let createDate: Date
    var updateDate: Date
    
    init(title: String? = nil, messageList: [MessageListItemType] = []) {
        self.id = UUID().uuidString
        self.title = title ?? "New Chat at \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        self.messageList = messageList
        self.createDate = Date()
        self.updateDate = Date()
    }
    
    // Additional initializer to preserve existing ID and creation date
    init(id: String, title: String, messageList: [MessageListItemType], createDate: Date) {
        self.id = id
        self.title = title
        self.messageList = messageList
        self.createDate = createDate
        self.updateDate = Date()
    }
} 