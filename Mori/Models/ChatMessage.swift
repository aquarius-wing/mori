import Foundation

// MARK: - Workflow Step Models
enum WorkflowStepType: String, CaseIterable, Codable {
    case userQuery = "USER_QUERY"
    case llmThinking = "LLM_THINKING"
    case llmResponse = "LLM_RESPONSE"
    case toolCall = "TOOL_CALL"
    case toolExecution = "TOOL_EXECUTION"
    case toolResult = "TOOL_RESULT"
    case finalStatus = "FINAL_STATUS"
    case error = "ERROR"
    
    var icon: String {
        switch self {
        case .userQuery: return "👤"
        case .llmThinking: return "☁️"
        case .llmResponse: return "💬"
        case .toolCall: return "🔧"
        case .toolExecution: return "⚡️"
        case .toolResult: return "📊"
        case .finalStatus: return "✅"
        case .error: return "❌"
        }
    }
}

struct WorkflowStep: Identifiable, Codable {
    let id = UUID()
    let type: WorkflowStepType
    let content: String
    let details: [String: String]
    let timestamp: Date
    
    init(type: WorkflowStepType, content: String, details: [String: String] = [:]) {
        self.type = type
        self.content = content
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