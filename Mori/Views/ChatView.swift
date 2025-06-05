import SwiftUI
import Combine



struct ChatView: View {
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("customApiBaseUrl") private var customApiBaseUrl = ""
    
    @State private var openAIService: OpenAIService?
    
    @State private var messages: [ChatMessage] = []
    @State private var currentStreamingMessage = ""
    @State private var currentWorkflowSteps: [WorkflowStep] = []
    @State private var currentStatus = "Ready"
    @State private var statusType: WorkflowStepType = .finalStatus
    @State private var isStreaming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    // Text input related state
    @State private var inputText = ""
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Message list with workflow display
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                            
                            // Display current streaming message and workflow
                            if isStreaming || isSending {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Status indicator
                                    StatusIndicator(status: currentStatus, type: statusType)
                                    
                                    // Workflow steps
                                    if !currentWorkflowSteps.isEmpty {
                                        WorkflowView(steps: currentWorkflowSteps)
                                    }
                                    
                                    // Streaming message
                                    if !currentStreamingMessage.isEmpty {
                                        MessageBubble(
                                            message: ChatMessage(content: currentStreamingMessage, isUser: false),
                                            isStreaming: true
                                        )
                                    }
                                }
                                .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: currentStreamingMessage) { _ in
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Text input area
                VStack(spacing: 12) {
                    // Text input field
                    HStack(spacing: 12) {
                        TextField("Ask something... (e.g., 'What files are in the root directory?')", text: $inputText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(1...6)
                            .disabled(isSending || isStreaming)
                        
                        // Send button
                        Button(action: sendMessage) {
                            Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isStreaming ? .gray : .blue)
                                .font(.title2)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isStreaming)
                    }
                    .padding(.horizontal)
                    
                    // Current status display
                    if isSending || isStreaming {
                        HStack {
                            Image(systemName: statusType == .error ? "exclamationmark.triangle" : "gear")
                                .foregroundColor(statusType == .error ? .red : .blue)
                            Text(currentStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Mori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        messages.removeAll()
                        currentWorkflowSteps.removeAll()
                        currentStreamingMessage = ""
                        currentStatus = "Ready"
                        statusType = .finalStatus
                    }
                    .disabled(isStreaming || isSending)
                }
            }
        }
        .onAppear {
            openAIService = OpenAIService(apiKey: openaiApiKey, customBaseURL: customApiBaseUrl.isEmpty ? nil : customApiBaseUrl)
            // Add debug information
            print("🔧 API Configuration:")
            print("  API Key: \(openaiApiKey.isEmpty ? "❌ Not set" : "✅ Set (length: \(openaiApiKey.count))")")
            print("  Base URL: \(customApiBaseUrl.isEmpty ? "✅ Using default" : "🔧 Custom: \(customApiBaseUrl)")")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    private func sendMessage() {
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty, let service = openAIService else { return }
        
        // Clear input field and reset state
        inputText = ""
        isSending = true
        currentWorkflowSteps.removeAll()
        currentStreamingMessage = ""
        updateStatus("Processing request...", type: .llmThinking)
        
        // Add user message
        let userMessage = ChatMessage(content: messageText, isUser: true)
        messages.append(userMessage)
        
        // Add user query workflow step
        currentWorkflowSteps.append(WorkflowStep(type: .userQuery, content: messageText))
        
        Task {
            do {
                await MainActor.run {
                    isSending = false
                    isStreaming = true
                }
                
                // Process real tool calling workflow
                await processRealToolWorkflow(for: messageText, using: service)
                
            } catch {
                await MainActor.run {
                    let errorStep = WorkflowStep(type: .error, content: "Send failed: \(error.localizedDescription)")
                    currentWorkflowSteps.append(errorStep)
                    updateStatus("Error: \(error.localizedDescription)", type: .error)
                    isSending = false
                    isStreaming = false
                }
            }
        }
    }
    
    private func processRealToolWorkflow(for messageText: String, using service: OpenAIService) async {
        var toolCallCount = 0
        var fullResponse = ""
        
        do {
            let stream = service.sendChatMessageWithTools(messageText, conversationHistory: messages)
            
            for try await result in stream {
                let (status, content) = result
                await MainActor.run {
                    switch status {
                    case "status":
                        updateStatus(content, type: .llmThinking)
                    case "tool_call":
                        toolCallCount += 1
                        let toolCallStep = WorkflowStep(
                            type: .toolCall,
                            content: "Initiating call to: \(content)",
                            details: ["tool_name": content, "arguments": "Pending..."]
                        )
                        currentWorkflowSteps.append(toolCallStep)
                        updateStatus("🔧 Calling tool: \(content)", type: .toolCall)
                    case "tool_arguments":
                        // Update the most recent tool call with arguments
                        if let lastIndex = currentWorkflowSteps.lastIndex(where: { $0.type == .toolCall }) {
                            let updatedStep = WorkflowStep(
                                type: .toolCall,
                                content: currentWorkflowSteps[lastIndex].content,
                                details: ["tool_name": currentWorkflowSteps[lastIndex].details["tool_name"] ?? "", "arguments": content]
                            )
                            currentWorkflowSteps[lastIndex] = updatedStep
                        }
                    case "tool_execution":
                        let executionStep = WorkflowStep(type: .toolExecution, content: content)
                        currentWorkflowSteps.append(executionStep)
                        updateStatus("⚡ \(content)", type: .toolExecution)
                    case "tool_results":
                        let resultStep = WorkflowStep(
                            type: .toolResult,
                            content: "Received result.",
                            details: ["result": content]
                        )
                        currentWorkflowSteps.append(resultStep)
                        updateStatus("🧠 Processing results...", type: .llmThinking)
                    case "response":
                        fullResponse += content
                        currentStreamingMessage = fullResponse
                    case "error":
                        let errorStep = WorkflowStep(type: .error, content: content)
                        currentWorkflowSteps.append(errorStep)
                        updateStatus("❌ Error: \(content)", type: .error)
                    default:
                        print("Unknown status: \(status)")
                    }
                }
            }
            
            await MainActor.run {
                // Complete streaming response
                let finalWorkflowSteps = currentWorkflowSteps
                let aiMessage = ChatMessage(
                    content: fullResponse, 
                    isUser: false, 
                    workflowSteps: finalWorkflowSteps
                )
                messages.append(aiMessage)
                
                // Add final status
                let finalStatusMessage = toolCallCount > 0 ? 
                    "Completed. Processed \(toolCallCount) tool call(s)." : "Completed."
                let finalStep = WorkflowStep(type: .finalStatus, content: finalStatusMessage)
                currentWorkflowSteps.append(finalStep)
                
                updateStatus("✅ \(finalStatusMessage)", type: .finalStatus)
                
                // Reset streaming state
                isStreaming = false
                currentStreamingMessage = ""
                currentWorkflowSteps.removeAll()
            }
        } catch {
            await MainActor.run {
                let errorStep = WorkflowStep(type: .error, content: "Error: \(error.localizedDescription)")
                currentWorkflowSteps.append(errorStep)
                updateStatus("❌ Error: \(error.localizedDescription)", type: .error)
                isStreaming = false
                currentStreamingMessage = ""
            }
        }
    }
    
    private func updateStatus(_ status: String, type: WorkflowStepType) {
        currentStatus = status
        statusType = type
    }
}



struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(16)
                    
                    HStack {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if isStreaming {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.secondary)
                                .scaleEffect(0.8)
                        }
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ChatView()
} 