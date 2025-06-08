import SwiftUI

// MARK: - Status Indicator View
struct StatusIndicator: View {
    let status: String
    let stepStatus: WorkflowStepStatus
    
    var body: some View {
        HStack {
            Text(stepStatus.icon)
            Text(status)
                .font(.caption)
                .foregroundColor(stepStatus == .error ? .red : .secondary)
            
            if stepStatus != .finalStatus && stepStatus != .error {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(stepStatus == .error ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
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
                
                if step.status == .scheduled || step.status == .executing || step.status == .result || step.status == .finalStatus {
                    WorkflowStepView(step: step)
                } else if step.status == .error {
                    WorkflowErrorView(step: step)
                }
            }
        }
    }
    

}

// MARK: - Standard Workflow Step View
struct WorkflowStepView: View {
    let step: WorkflowStep
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(step.status.icon)
                    Text("\(step.toolName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if !step.details.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
            }
            .disabled(step.details.isEmpty)
            
            if isExpanded && !step.details.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(step.details.keys.sorted()), id: \.self) { key in
                        if let value = step.details[key] {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(key.capitalized):")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(value)
                                    .font(.caption)
                                    .padding(8)
                                    .background(
                                        step.status == .result ? Color.blue.opacity(0.1) : 
                                        step.status == .error ? Color.red.opacity(0.1) : Color.gray.opacity(0.1)
                                    )
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(
            step.status == .result ? Color.blue.opacity(0.05) :
            step.status == .executing ? Color.orange.opacity(0.05) :
            step.status == .scheduled ? Color.gray.opacity(0.05) : Color.gray.opacity(0.05)
        )
        .cornerRadius(8)
    }
}



// MARK: - Error View
struct WorkflowErrorView: View {
    let step: WorkflowStep
    
    var body: some View {
        HStack {
            Text(step.status.icon)
            Text(step.toolName)
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