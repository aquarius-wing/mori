import SwiftUI

// MARK: - Status Indicator View
struct StatusIndicator: View {
    let status: String
    let type: WorkflowStepType
    
    var body: some View {
        HStack {
            Text(type.icon)
            Text(status)
                .font(.caption)
                .foregroundColor(type == .error ? .red : .secondary)
            
            if type != .finalStatus && type != .error {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(type == .error ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Workflow View
struct WorkflowView: View {
    let steps: [WorkflowStep]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
                let step = steps[index]
                
                if step.type == .toolCall {
                    WorkflowToolCallView(step: step, followingSteps: getFollowingSteps(from: index))
                } else if step.type == .error {
                    WorkflowErrorView(step: step)
                }
            }
        }
    }
    
    private func getFollowingSteps(from index: Int) -> [WorkflowStep] {
        guard index + 1 < steps.count else { return [] }
        
        var followingSteps: [WorkflowStep] = []
        for i in (index + 1)..<steps.count {
            let step = steps[i]
            if step.type == .toolExecution || step.type == .toolResult {
                followingSteps.append(step)
            } else if step.type == .toolCall {
                break // Stop at next tool call
            }
        }
        return followingSteps
    }
}

// MARK: - Tool Call View
struct WorkflowToolCallView: View {
    let step: WorkflowStep
    let followingSteps: [WorkflowStep]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(step.type.icon)
                    Text("Tool Call: \(step.details["tool_name"] ?? "Unknown")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Arguments
                    Text("Arguments:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if let arguments = step.details["arguments"] {
                        if arguments == "Pending..." {
                            Text("Preparing arguments...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(arguments)
                                .font(.caption)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Following steps (execution and results)
                    ForEach(followingSteps, id: \.id) { followingStep in
                        HStack {
                            Text(followingStep.type.icon)
                            if followingStep.type == .toolExecution {
                                Text("Status: \(followingStep.content)")
                                    .font(.caption)
                            } else if followingStep.type == .toolResult {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Result:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    if let result = followingStep.details["result"] {
                                        Text(result)
                                            .font(.caption)
                                            .padding(8)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Error View
struct WorkflowErrorView: View {
    let step: WorkflowStep
    
    var body: some View {
        HStack {
            Text(step.type.icon)
            Text(step.content)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Message View
struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 12) {
            // Workflow steps (only for assistant messages)
            if !message.isUser && !message.workflowSteps.isEmpty {
                WorkflowView(steps: message.workflowSteps)
            }
            
            // Message bubble
            MessageBubble(message: message)
        }
    }
} 