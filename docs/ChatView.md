## Data Structure
- messageList: [ChatMessage | WorkflowStep]
- currentStatus: String

### ChatMessage
- id: UUID
- content: String
- isUser: Bool
- timestamp: Date
- isSystem: Bool

### WorkflowStep
- id: UUID
- type: WorkflowStepType
- title: String // name of tool
- details: [String: Any]
- timestamp: Date

### WorkflowStepType
- scheduled
- executing
- result
- error


## Flow

```mermaid
sequenceDiagram
    participant User
    participant ChatView
    participant OpenAIService
    participant LLM_API as LLM API
    participant CalendarMCP

    User->>OpenAIService: My meeting is delay one hour, delay events after that a hour too, search in this week.
    OpenAIService->>LLM_API: Send prepared messages [{role: system}, {role: user}]
    OpenAIService->>ChatView: status: 🧠 Processing request...
    LLM_API->>OpenAIService: Response: {role: assistant, content: ...}
    OpenAIService->>ChatView: status: 💬 Streaming response...
    LLM_API->>OpenAIService: Response: content chunk
    OpenAIService->>ChatView: response: chunk
    ChatView->>ChatView: sum up chunk
    LLM_API->>OpenAIService: Response: done
    OpenAIService->>ChatView: replace_response: cleanedResponse (without tool_call json)
    OpenAIService->>ChatView: tool_call: read-calendar with ID
    ChatView->>ChatView: append new workflow step with type: scheduled
    OpenAIService->>CalendarMCP: Call read-calendar with ID
    OpenAIService->>ChatView: tool_executing: ID
    ChatView->>ChatView: update workflow step: tool_executing: ID with type: executing
    CalendarMCP->>OpenAIService: response
    OpenAIService->>ChatView: tool_results: ID, response
    ChatView->>ChatView: update workflow step: tool_results: ID with type: result
    OpenAIService->>LLM_API: Send Prepare messages with tool results<br/>[{role: system}, <br/>{role: user}, <br/>{role: assistant, tool: read-calendar}, <br/>{role: user, tool response}]
```

## Data Mapping
### ChatMessage in ChatView
Display as MessageView
### ChatMessage in OpenAIService
make ChatMessage to {
  role: "system" | "user" | "assistant"
  content: String
}

### WorkflowStep in ChatView
Display as WorkflowStepView
### WorkflowStep in OpenAIService
make WorkflowStep to {
  role: "user"
  content: String // which is detail of step
}