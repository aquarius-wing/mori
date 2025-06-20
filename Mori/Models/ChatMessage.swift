import Foundation

// MARK: - Workflow Step Models
enum WorkflowStepStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case executing = "executing" 
    case result = "result"
    case error = "error"
    
    // Additional UI status types (not part of core workflow)
    case finalStatus = "FINAL_STATUS"
    case llmThinking = "LLM_THINKING"
    
    var icon: String {
        switch self {
        case .scheduled: return "⏰"
        case .executing: return "⚡️"
        case .result: return "📊"
        case .error: return "❌"
        case .finalStatus: return "✅"
        case .llmThinking: return "☁️"
        }
    }
}

struct WorkflowStep: Identifiable, Codable {
    let id = UUID()
    let status: WorkflowStepStatus
    let toolName: String // name of tool
    let details: [String: String] // Keep as [String: String] for Codable compatibility
    let timestamp: Date
    
    // Convenience property for working with Any values
    var detailsAny: [String: Any] {
        get {
            return details.mapValues { $0 as Any }
        }
    }
    
    init(status: WorkflowStepStatus, toolName: String = "", title: String = "", details: [String: String] = [:]) {
        self.status = status
        self.toolName = toolName
        self.details = details
        self.timestamp = Date()
    }
    
    // Legacy initializer for backward compatibility
    init(type: WorkflowStepStatus, content: String, details: [String: String] = [:]) {
        self.status = type
        self.toolName = content
        self.details = details
        self.timestamp = Date()
    }
    
    // Legacy initializer for backward compatibility with title
    init(type: WorkflowStepStatus, title: String = "", content: String = "", details: [String: String] = [:]) {
        self.status = type
        self.toolName = title.isEmpty ? content : title
        self.details = details
        self.timestamp = Date()
    }
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let isSystem: Bool
    let workflowSteps: [WorkflowStep]
    
    init(content: String, isUser: Bool, timestamp: Date? = nil, isSystem: Bool = false, workflowSteps: [WorkflowStep] = []) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp ?? Date()
        self.isSystem = isSystem
        self.workflowSteps = workflowSteps
    }
}

// MARK: - Chat Item Union Type
enum ChatItem: Identifiable, Codable {
    case message(ChatMessage)
    case workflowStep(WorkflowStep)
    
    var id: UUID {
        switch self {
        case .message(let chatMessage):
            return chatMessage.id
        case .workflowStep(let workflowStep):
            return workflowStep.id
        }
    }
    
    var timestamp: Date {
        switch self {
        case .message(let chatMessage):
            return chatMessage.timestamp
        case .workflowStep(let workflowStep):
            return workflowStep.timestamp
        }
    }
    
    // Convenience initializers
    static func message(_ content: String, isUser: Bool, isSystem: Bool = false, workflowSteps: [WorkflowStep] = []) -> ChatItem {
        return .message(ChatMessage(content: content, isUser: isUser, isSystem: isSystem, workflowSteps: workflowSteps))
    }
    
    static func workflowStep(_ status: WorkflowStepStatus, toolName: String = "", details: [String: String] = [:]) -> ChatItem {
        return .workflowStep(WorkflowStep(status: status, toolName: toolName, details: details))
    }
} 