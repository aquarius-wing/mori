import Foundation

// MARK: - Workflow Step Models
enum WorkflowStepType: String, CaseIterable, Codable {
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
    let type: WorkflowStepType
    let title: String // name of tool
    let details: [String: String] // Keep as [String: String] for Codable compatibility
    let timestamp: Date
    
    // Convenience property for working with Any values
    var detailsAny: [String: Any] {
        get {
            return details.mapValues { $0 as Any }
        }
    }
    
    init(type: WorkflowStepType, title: String = "", content: String = "", details: [String: String] = [:]) {
        self.type = type
        self.title = title.isEmpty ? content : title
        self.details = details
        self.timestamp = Date()
    }
    
    // Legacy initializer for backward compatibility
    init(type: WorkflowStepType, content: String, details: [String: String] = [:]) {
        self.type = type
        self.title = content
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